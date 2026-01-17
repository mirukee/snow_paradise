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
