const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "findptapp",
});

const db = admin.firestore();

(async () => {
  const snap = await db.collection("users").where("role", "==", "trainer").get();
  console.log("trainer users:", snap.size);

  let batch = db.batch();
  let n = 0;
  let committed = 0;

  for (const doc of snap.docs) {
    batch.set(doc.ref, { _touch: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    n++;

    if (n === 400) {
      await batch.commit();
      committed += n;
      console.log("committed:", committed);
      batch = db.batch();
      n = 0;
    }
  }

  if (n > 0) {
    await batch.commit();
    committed += n;
  }

  console.log("done. total touched:", committed);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});