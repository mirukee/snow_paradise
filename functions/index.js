const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const db = admin.firestore();
const MAX_BODY_LENGTH = 80;
const SEARCH_KEYWORD_RATE_WINDOW_MS = 60 * 1000;
const SEARCH_KEYWORD_RATE_MAX = 20;
const REPORT_RATE_WINDOW_MS = 10 * 60 * 1000;
const REPORT_RATE_MAX = 5;

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

function resolveRateLimit(snapshot, nowMs, windowMs) {
  if (!snapshot.exists) {
    return { windowStart: nowMs, count: 0 };
  }
  const data = snapshot.data() || {};
  const storedStart =
    data.windowStart && typeof data.windowStart.toMillis === "function"
      ? data.windowStart.toMillis()
      : 0;
  const storedCount = toNonNegativeInt(data.count);
  if (storedStart > 0 && nowMs - storedStart < windowMs) {
    return { windowStart: storedStart, count: storedCount };
  }
  return { windowStart: nowMs, count: 0 };
}

function rateLimitUpdate(windowStart, nextCount) {
  return {
    windowStart: admin.firestore.Timestamp.fromMillis(windowStart),
    count: nextCount,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function applyUnreadDelta(userId, delta) {
  const trimmedUserId = toCleanString(userId);
  if (!trimmedUserId || !delta) {
    return;
  }
  const userRef = db.collection("users").doc(trimmedUserId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(userRef);
    if (!snapshot.exists) {
      return;
    }
    const current = toNonNegativeInt(snapshot.get("unreadTotal"));
    const next = current + delta;
    transaction.update(userRef, {
      unreadTotal: next < 0 ? 0 : next,
      lastUnreadUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

function toPasswordString(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function hashPassword(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

exports.recordSearchKeyword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }

  const keywordRaw = toCleanString(data && data.keyword);
  const keyword = keywordRaw.trim().toLowerCase();
  if (!keyword || keyword.length < 2 || keyword.length > 40) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "유효하지 않은 검색어입니다."
    );
  }

  const docRef = db.collection("search_keywords").doc(keyword);
  const rateRef = db.collection("search_keyword_limits").doc(context.auth.uid);
  const nowMs = Date.now();
  await db.runTransaction(async (transaction) => {
    const rateSnapshot = await transaction.get(rateRef);
    const state = resolveRateLimit(
      rateSnapshot,
      nowMs,
      SEARCH_KEYWORD_RATE_WINDOW_MS
    );
    if (state.count >= SEARCH_KEYWORD_RATE_MAX) {
      return;
    }
    transaction.set(
      rateRef,
      rateLimitUpdate(state.windowStart, state.count + 1),
      { merge: true }
    );

    const snapshot = await transaction.get(docRef);
    if (snapshot.exists) {
      transaction.update(docRef, {
        count: admin.firestore.FieldValue.increment(1),
        lastSearchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.set(docRef, {
        keyword: keyword,
        count: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSearchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  return { success: true };
});

exports.createReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다."
    );
  }

  const reporterUid = toCleanString(context.auth.uid);
  const targetUid = toCleanString(data && data.targetUid).trim();
  const targetContentId = toCleanString(data && data.targetContentId).trim();
  const reason = toCleanString(data && data.reason).trim();
  if (!reporterUid || !targetUid || !targetContentId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "신고 정보를 찾을 수 없습니다."
    );
  }
  if (!reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "신고 사유를 입력해 주세요."
    );
  }
  if (reason.length > 500) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "신고 사유가 너무 깁니다."
    );
  }

  const limitRef = db.collection("report_limits").doc(reporterUid);
  const reportRef = db.collection("reports").doc();
  const nowMs = Date.now();

  await db.runTransaction(async (transaction) => {
    const limitSnapshot = await transaction.get(limitRef);
    const state = resolveRateLimit(
      limitSnapshot,
      nowMs,
      REPORT_RATE_WINDOW_MS
    );
    if (state.count >= REPORT_RATE_MAX) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "신고 요청이 너무 많습니다. 잠시 후 다시 시도해주세요."
      );
    }

    transaction.set(
      limitRef,
      rateLimitUpdate(state.windowStart, state.count + 1),
      { merge: true }
    );
    transaction.set(reportRef, {
      reporterUid,
      targetUid,
      targetContentId,
      reason,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true, reportId: reportRef.id };
});

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

exports.updateUnreadTotalOnRoomWrite = functions.firestore
  .document("chat_rooms/{roomId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    const sellerId = toCleanString(after?.sellerId ?? before?.sellerId);
    const buyerId = toCleanString(after?.buyerId ?? before?.buyerId);
    if (!sellerId && !buyerId) {
      return null;
    }

    const beforeSeller = toNonNegativeInt(before?.unreadCountSeller);
    const beforeBuyer = toNonNegativeInt(before?.unreadCountBuyer);
    const afterSeller = toNonNegativeInt(after?.unreadCountSeller);
    const afterBuyer = toNonNegativeInt(after?.unreadCountBuyer);

    const sellerDelta = afterSeller - beforeSeller;
    const buyerDelta = afterBuyer - beforeBuyer;

    const tasks = [];
    if (sellerId && sellerDelta) {
      tasks.push(applyUnreadDelta(sellerId, sellerDelta));
    }
    if (buyerId && buyerId !== sellerId && buyerDelta) {
      tasks.push(applyUnreadDelta(buyerId, buyerDelta));
    }

    await Promise.all(tasks);
    return null;
  });

exports.verifyAdminPassword = functions.https.onCall(async (data, context) => {
  const password = toPasswordString(data?.password);
  if (!password) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "비밀번호가 필요합니다."
    );
  }

  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "관리자 계정으로 먼저 로그인해주세요."
    );
  }

  const settingsRef = db.collection("admin").doc("settings");
  const settingsSnapshot = await settingsRef.get();
  if (!settingsSnapshot.exists) {
    throw new functions.https.HttpsError(
      "not-found",
      "관리자 설정을 찾을 수 없습니다."
    );
  }

  const settings = settingsSnapshot.data() || {};
  const storedHash = toCleanString(settings.passwordHash);
  const legacyPassword = toCleanString(settings.password);
  const inputHash = hashPassword(password);

  let isValid = false;
  if (storedHash) {
    isValid = storedHash === inputHash;
  } else if (legacyPassword) {
    isValid = legacyPassword === password;
  }

  if (!isValid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "비밀번호가 일치하지 않습니다."
    );
  }

  if (!storedHash) {
    const updates = {
      passwordHash: inputHash,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (legacyPassword) {
      updates.password = admin.firestore.FieldValue.delete();
    }
    await settingsRef.set(updates, { merge: true });
  }

  await admin
    .auth()
    .setCustomUserClaims(context.auth.uid, { admin: true });

  return {
    success: true,
  };
});
