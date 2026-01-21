const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const BATCH_SIZE = 300;

function normalizeString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return typeof value === "string" ? value.trim() : String(value).trim();
}

async function backfill() {
  let lastDoc = null;
  let processed = 0;

  while (true) {
    let query = db.collection("users").orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      const data = doc.data() || {};
      const nickname = normalizeString(data.nickname);
      const profileImageUrl = normalizeString(data.profileImageUrl);
      const createdAt =
        data.createdAt instanceof admin.firestore.Timestamp
          ? data.createdAt
          : admin.firestore.FieldValue.serverTimestamp();

      batch.set(
        db.collection("public_profiles").doc(doc.id),
        {
          uid: doc.id,
          nickname: nickname,
          profileImageUrl: profileImageUrl.length > 0 ? profileImageUrl : null,
          createdAt: createdAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    await batch.commit();
    processed += snapshot.size;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed ${processed} users...`);
  }

  console.log("Backfill completed.");
}

backfill().catch((error) => {
  console.error("Backfill failed:", error);
  process.exit(1);
});
