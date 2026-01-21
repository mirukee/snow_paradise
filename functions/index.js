const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const MAX_BODY_LENGTH = 80;

function toCleanString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return typeof value === "string" ? value : String(value);
}

function toTrimmedTokens(tokens) {
  if (!Array.isArray(tokens)) {
    return [];
  }
  return tokens
    .map((token) => (typeof token === "string" ? token.trim() : ""))
    .filter((token) => token.length > 0);
}

function buildNotificationBody(text) {
  const trimmed = text.trim();
  if (trimmed.length <= MAX_BODY_LENGTH) {
    return trimmed;
  }
  return `${trimmed.slice(0, MAX_BODY_LENGTH)}…`;
}

async function findProductRefById(productId) {
  if (!productId) {
    return null;
  }
  const snapshot = await db
    .collection("products")
    .where("id", "==", productId)
    .limit(1)
    .get();
  if (snapshot.empty) {
    return null;
  }
  return snapshot.docs[0].ref;
}

function toNonNegativeInt(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return 0;
  }
  return value < 0 ? 0 : Math.floor(value);
}

exports.sendChatNotification = functions.firestore
  .document("chat_rooms/{roomId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message) {
      functions.logger.warn("No message payload in snapshot.");
      return null;
    }

    const senderId = toCleanString(message.senderId);
    const text = toCleanString(message.text);
    if (!senderId || !text) {
      functions.logger.warn("Missing senderId or text.", {
        senderIdPresent: Boolean(senderId),
        textPresent: Boolean(text),
      });
      return null;
    }

    const roomId = context.params.roomId;
    const roomSnapshot = await db.collection("chat_rooms").doc(roomId).get();
    if (!roomSnapshot.exists) {
      functions.logger.warn("Chat room not found.", { roomId });
      return null;
    }

    const room = roomSnapshot.data() || {};
    const sellerId = toCleanString(room.sellerId);
    const buyerId = toCleanString(room.buyerId);

    let receiverId = "";
    if (senderId === sellerId) {
      receiverId = buyerId;
    } else if (senderId === buyerId) {
      receiverId = sellerId;
    } else {
      return null;
    }

    if (!receiverId) {
      functions.logger.warn("Receiver not resolved.", {
        roomId,
        senderId,
        sellerId,
        buyerId,
      });
      return null;
    }

    // 차단된 사용자에게는 푸시를 보내지 않습니다.
    const blockedSnapshot = await db
      .collection("users")
      .doc(receiverId)
      .collection("blocked_users")
      .doc(senderId)
      .get();
    if (blockedSnapshot.exists) {
      functions.logger.info("Receiver blocked sender. Skip notification.", {
        roomId,
        receiverId,
        senderId,
      });
      return null;
    }

    const receiverSnapshot = await db.collection("users").doc(receiverId).get();
    const receiverData = receiverSnapshot.data() || {};
    const tokens = toTrimmedTokens(receiverData.fcmTokens);
    if (tokens.length === 0) {
      functions.logger.warn("No FCM tokens for receiver.", {
        roomId,
        receiverId,
      });
      return null;
    }

    const senderName =
      senderId === sellerId
        ? toCleanString(room.sellerName) || "판매자"
        : toCleanString(room.buyerName) || "구매자";
    const productTitle = toCleanString(room.productTitle) || "상품";
    const notification = {
      title: `${senderName}님의 메시지`,
      body: buildNotificationBody(text),
    };

    const normalizedRoomId = toCleanString(roomId);
    const data = {
      type: "chat",
      chatId: normalizedRoomId,
      roomId: normalizedRoomId,
      senderId: senderId,
      productId: toCleanString(room.productId),
      productTitle: productTitle,
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification,
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "snow_paradise_default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = [];
    const errorStats = {};
    response.responses.forEach((result, index) => {
      if (result.success) {
        return;
      }
      const errorCode = result.error?.code ?? "unknown";
      errorStats[errorCode] = (errorStats[errorCode] ?? 0) + 1;
      if (
        errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await db.collection("users").doc(receiverId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
      functions.logger.info("Removed invalid FCM tokens.", {
        receiverId,
        removedCount: invalidTokens.length,
      });
    }

    functions.logger.info("FCM send result.", {
      roomId,
      receiverId,
      tokens: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      errorStats,
    });

    return null;
  });

/**
 * 찜 알림 전송 Cloud Function
 * users/{userId}/likes/{productId} 문서 생성 시 트리거
 */
exports.sendLikeNotification = functions.firestore
  .document("users/{userId}/likes/{productId}")
  .onCreate(async (snapshot, context) => {
    const likerId = context.params.userId; // 찜을 누른 사용자
    const productId = context.params.productId; // 찜한 상품 ID

    if (!likerId || !productId) {
      functions.logger.warn("Missing likerId or productId.", {
        likerId,
        productId,
      });
      return null;
    }

    // 상품 정보 조회
    const productSnapshot = await db
      .collection("products")
      .where("id", "==", productId)
      .limit(1)
      .get();

    if (productSnapshot.empty) {
      functions.logger.warn("Product not found.", { productId });
      return null;
    }

    const productData = productSnapshot.docs[0].data();
    const sellerId = toCleanString(productData.sellerId);
    const productTitle = toCleanString(productData.title) || "상품";

    // 본인 상품 찜 시 알림 제외
    if (sellerId === likerId) {
      functions.logger.info("User liked own product. Skip notification.", {
        likerId,
        productId,
      });
      return null;
    }

    if (!sellerId) {
      functions.logger.warn("Seller not found for product.", { productId });
      return null;
    }

    // 차단된 사용자에게는 푸시를 보내지 않습니다.
    const blockedSnapshot = await db
      .collection("users")
      .doc(sellerId)
      .collection("blocked_users")
      .doc(likerId)
      .get();

    if (blockedSnapshot.exists) {
      functions.logger.info("Seller blocked liker. Skip notification.", {
        sellerId,
        likerId,
      });
      return null;
    }

    // 판매자 FCM 토큰 조회
    const sellerSnapshot = await db.collection("users").doc(sellerId).get();
    const sellerData = sellerSnapshot.data() || {};
    const tokens = toTrimmedTokens(sellerData.fcmTokens);

    if (tokens.length === 0) {
      functions.logger.warn("No FCM tokens for seller.", {
        sellerId,
        productId,
      });
      return null;
    }

    // 찜한 사용자 정보 조회 (닉네임)
    const likerSnapshot = await db.collection("users").doc(likerId).get();
    const likerData = likerSnapshot.data() || {};
    const likerName = toCleanString(likerData.nickname) || "누군가";

    const notification = {
      title: "❤️ 누군가 내 상품을 찜했어요!",
      body: buildNotificationBody(`${likerName}님이 '${productTitle}'에 관심을 보이고 있어요`),
    };

    const data = {
      type: "like",
      productId: productId,
      productTitle: productTitle,
      likerId: likerId,
      likeAction: "true",
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification,
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "snow_paradise_default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    const invalidTokens = [];
    const errorStats = {};
    response.responses.forEach((result, index) => {
      if (result.success) {
        return;
      }
      const errorCode = result.error?.code ?? "unknown";
      errorStats[errorCode] = (errorStats[errorCode] ?? 0) + 1;
      if (
        errorCode === "messaging/registration-token-not-registered" ||
        errorCode === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await db.collection("users").doc(sellerId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
      functions.logger.info("Removed invalid FCM tokens.", {
        sellerId,
        removedCount: invalidTokens.length,
      });
    }

    functions.logger.info("Like notification FCM send result.", {
      productId,
      sellerId,
      likerId,
      tokens: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      errorStats,
    });

    return null;
  });

exports.updateLikeCountOnCreate = functions.firestore
  .document("users/{userId}/likes/{productId}")
  .onCreate(async (snapshot, context) => {
    const productId = toCleanString(context.params.productId);
    const productRef = await findProductRefById(productId);
    if (!productRef) {
      functions.logger.warn("Product not found for like increment.", {
        productId,
      });
      return null;
    }

    await db.runTransaction(async (transaction) => {
      const productSnap = await transaction.get(productRef);
      if (!productSnap.exists) {
        return;
      }
      const current = toNonNegativeInt(productSnap.get("likeCount"));
      transaction.update(productRef, { likeCount: current + 1 });
    });

    return null;
  });

exports.updateLikeCountOnDelete = functions.firestore
  .document("users/{userId}/likes/{productId}")
  .onDelete(async (snapshot, context) => {
    const productId = toCleanString(context.params.productId);
    const productRef = await findProductRefById(productId);
    if (!productRef) {
      functions.logger.warn("Product not found for like decrement.", {
        productId,
      });
      return null;
    }

    await db.runTransaction(async (transaction) => {
      const productSnap = await transaction.get(productRef);
      if (!productSnap.exists) {
        return;
      }
      const current = toNonNegativeInt(productSnap.get("likeCount"));
      const next = current - 1;
      transaction.update(productRef, { likeCount: next < 0 ? 0 : next });
    });

    return null;
  });

exports.updateChatCountOnFirstMessage = functions.firestore
  .document("chat_rooms/{roomId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const roomId = toCleanString(context.params.roomId);
    if (!roomId) {
      return null;
    }

    const roomRef = db.collection("chat_rooms").doc(roomId);

    await db.runTransaction(async (transaction) => {
      const roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) {
        return;
      }

      const roomData = roomSnap.data() || {};
      if (roomData.isFirstMessageSent === true) {
        return;
      }

      const productId = toCleanString(roomData.productId);
      if (!productId) {
        transaction.update(roomRef, { isFirstMessageSent: true });
        return;
      }

      const productQuery = db
        .collection("products")
        .where("id", "==", productId)
        .limit(1);
      const productSnapshot = await transaction.get(productQuery);
      if (productSnapshot.empty) {
        transaction.update(roomRef, { isFirstMessageSent: true });
        return;
      }

      const productDoc = productSnapshot.docs[0];
      const current = toNonNegativeInt(productDoc.get("chatCount"));
      transaction.update(productDoc.ref, { chatCount: current + 1 });
      transaction.update(roomRef, { isFirstMessageSent: true });
    });

    return null;
  });
