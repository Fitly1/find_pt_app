/* ──────────────────────────────────────────────────────────────
   IMPORTS & INITIALISATION – ORIGINAL + SMALL ADDITIONS
───────────────────────────────────────────────────────────────*/
"use strict";

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const auth = require("firebase-functions/v1/auth");
const express = require("express");
const cors = require("cors");
require("dotenv").config(); // local .env support

const admin = require("firebase-admin");
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: "findptapp",
});

/* ─── Helper: recompute and store average rating (NEW) ────────*/
async function recomputeTrainerRating(uid) {
  const reviewsSnap = await admin
    .firestore()
    .collection(`trainer_profiles/${uid}/reviews`)
    .get();

  let total = 0;
  reviewsSnap.forEach((d) => {
    total += d.get("rating") || 0;
  });

  const avg = reviewsSnap.empty ? 0 : total / reviewsSnap.size;

  await admin
    .firestore()
    .doc(`trainer_profiles/${uid}`)
    .set({ rating: Number(avg.toFixed(2)) }, { merge: true });

  console.log(`⭐ Trainer ${uid} average rating → ${avg.toFixed(2)}`);
}

/* ─── Stripe config (unchanged) ──────────────────────────────*/
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || "";
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || "";

if (!STRIPE_SECRET_KEY) console.error("❌ Missing Stripe Secret Key!");
if (!WEBHOOK_SECRET) console.error("❌ Missing Stripe Webhook Secret!");

const stripe = require("stripe")(STRIPE_SECRET_KEY);

/* ─── Promo-code map (NEW) ─────────────────────────────────── */
const PROMO_CODE_MAP = {
  FITLY3FREE: "fitly3free", // user types  FITLY3FREE  →  coupon id fitly3free
  // add more codes here e.g. SUMMER25: "coupon_abcd1234"
};

/* ─── Apple-IAP config ───────────────────────────────────── */
const APPLE_SHARED_SECRET = process.env.APPLE_SHARED_SECRET || "";
const APP_STORE_ENV = (process.env.APP_STORE_ENV || "production").toLowerCase();
if (!APPLE_SHARED_SECRET)
  console.warn(
    "⚠️  No APPLE_SHARED_SECRET set – Apple receipt validation disabled"
  );

/* Cloud Functions on Node 18 already have fetch.  If for any
   reason it is missing we fall back to node-fetch.             */
let fetchFn = global.fetch;
if (!fetchFn)
  fetchFn = (...args) =>
    import("node-fetch").then(({ default: fetch }) => fetch(...args));

/* Helper: decode JWT payload (Apple notifications) */
function decodeJwtPayload(jwt) {
  const b64 = jwt.split(".")[1];
  return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
}

/* ─── Helpers used by iOS reconciliation (NEW) ───────────────*/
async function verifyReceipt(receiptData) {
  const url =
    APP_STORE_ENV === "sandbox"
      ? "https://sandbox.itunes.apple.com/verifyReceipt"
      : "https://buy.itunes.apple.com/verifyReceipt";

  const res = await fetchFn(url, {
    method: "POST",
    body: JSON.stringify({
      "receipt-data": receiptData,
      password: APPLE_SHARED_SECRET,
      "exclude-old-transactions": true,
    }),
  });
  const json = await res.json();
  if (json.status !== 0) throw new Error(`Apple status ${json.status}`);
  return json;
}

function getLatestExpiry(verifyResponse) {
  const latest = verifyResponse.latest_receipt_info?.slice(-1)[0];
  return latest ? Number(latest.expires_date_ms) : 0;
}

/* ──────────────────────────────────────────────────────────────
   1) EXPRESS APP FOR NORMAL (NON-WEBHOOK) ROUTES – ORIGINAL
───────────────────────────────────────────────────────────────*/
const app = express();
app.use(cors({ origin: true }));

// Only parse JSON for /api routes (keeps webhook raw)
app.use("/api", express.json());

app.get("/", (req, res) => {
  res.send("Stripe server is running!");
});

/* ---------- createPaymentIntent (original) ------------------*/
app.post("/createPaymentIntent", async (req, res) => {
  try {
    const { amount, currency, trainerUid, email } = req.body;
    if (!amount || !currency || !trainerUid || !email) {
      return res.status(400).json({ error: "Missing required fields." });
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(trainerUid)
      .get();
    if (!userDoc.exists || userDoc.data().role !== "trainer") {
      return res
        .status(403)
        .json({ error: "Only trainers can create payment intents." });
    }

    const idempotencyKey = `pi_${trainerUid}_${amount}_${Date.now()}`;
    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount,
        currency,
        receipt_email: email,
        metadata: { trainerId: trainerUid },
      },
      { idempotencyKey }
    );

    console.log(
      `Created PaymentIntent ${paymentIntent.id} for trainer ${trainerUid}`
    );
    return res.status(200).json({ clientSecret: paymentIntent.client_secret });
  } catch (error) {
    console.error("❌ Error creating PaymentIntent:", error);
    return res.status(500).json({ error: error.message });
  }
});

/* ---------- issueRefund (original) --------------------------*/
app.post("/issueRefund", async (req, res) => {
  try {
    const { chargeId, amount } = req.body;
    if (!chargeId)
      return res.status(400).json({ error: "Missing required chargeId." });

    const refundData = { charge: chargeId };
    if (amount) refundData.amount = amount;

    const idempotencyKey = `refund_${chargeId}_${Date.now()}`;
    const refund = await stripe.refunds.create(refundData, { idempotencyKey });
    console.log(`Refund issued for charge ${chargeId}`);
    return res.status(200).json({ refund });
  } catch (error) {
    console.error("Error issuing refund:", error);
    return res.status(500).json({ error: error.message });
  }
});

exports.api = onRequest(app);

/* ──────────────────────────────────────────────────────────────
   2) FIRESTORE TRIGGER: createPaymentRequest  (original)
───────────────────────────────────────────────────────────────*/
exports.createPaymentRequest = onDocumentCreated(
  "stripe_payment_requests/{docId}",
  async (event) => {
    try {
      const data = event.data.data();
      console.log("New payment request data:", data);

      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(data.trainerUid)
        .get();
      if (!userDoc.exists || userDoc.data().role !== "trainer") {
        console.error("Customer account triggered payment request; skipping.");
        return;
      }

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "payment",
        line_items: [
          {
            price_data: {
              currency: data.currency || "aud",
              product_data: { name: "Trainer Payment" },
              unit_amount: data.amount || 3000,
            },
            quantity: 1,
          },
        ],
        success_url:
          "https://fitly1.github.io/billing-redirect/redirect.html?type=success",
        cancel_url:
          "https://fitly1.github.io/billing-redirect/redirect.html?type=cancel",
        customer_email: data.email || "",
      });

      await admin
        .firestore()
        .doc(`stripe_payment_requests/${event.params.docId}`)
        .update({
          url: session.url,
          sessionId: session.id,
        });
      console.log(
        `Checkout session created for payment request ${event.params.docId}`
      );
    } catch (err) {
      console.error("Error creating Checkout Session", err);
      await admin
        .firestore()
        .doc(`stripe_payment_requests/${event.params.docId}`)
        .update({ error: err.message });
    }
  }
);

/* ──────────────────────────────────────────────────────────────
   3) CALLABLE: createSubscriptionCheckoutSession (UPDATED)
───────────────────────────────────────────────────────────────*/
exports.createSubscriptionCheckoutSession = onCall(async (req) => {
  const { data, auth } = req;
  if (!auth) throw new Error("User must be authenticated");

  const trainerId = auth.uid;
  const priceId = "price_1QxLgJIwC3BBH5MDFZO28ndV"; // LIVE price

  const trainerUser = await admin.auth().getUser(trainerId);
  const email = trainerUser.email;
  if (!email) throw new Error("Trainer's email is not available");

  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(trainerId)
    .get();
  if (userDoc.exists && userDoc.data().role !== "trainer")
    throw new Error("Only trainers can create subscription checkout sessions.");

  const trainerRef = admin.firestore().doc(`trainer_profiles/${trainerId}`);
  const trainerDoc = await trainerRef.get();

  let customerId = trainerDoc.exists ? trainerDoc.data().stripeId : null;

  if (!customerId) {
    const idempotencyKey = `cust_${trainerId}_${Date.now()}`;
    const newCustomer = await stripe.customers.create(
      { email },
      { idempotencyKey }
    );
    customerId = newCustomer.id;
    await trainerRef.update({ stripeId: customerId, isActive: false });
    console.log(
      `Created new Stripe customer ${customerId} for trainer ${trainerId}`
    );
  }

  await stripe.customers.update(customerId, { email });
  await stripe.customers.update(customerId, { balance: 0 });

  /* ── promo-code handling (NEW BLOCK) ─────────────────────── */
  const promoCodeInput = data?.promoCode?.trim()?.toUpperCase() || null;
  const matchedCouponId = promoCodeInput ? PROMO_CODE_MAP[promoCodeInput] : null;

  if (promoCodeInput && !matchedCouponId) {
    // Unrecognised code → clean error for client
    throw new HttpsError("invalid-argument", "Invalid promotional code.");
  }

  const discounts = matchedCouponId ? [{ coupon: matchedCouponId }] : [];
  /* ─────────────────────────────────────────────────────────── */

  const idempotencyKey = `subsess_${trainerId}_${Date.now()}`;
  const successUrl = encodeURI(
    "https://fitly1.github.io/billing-redirect/redirect.html?type=success"
  );
  const cancelUrl = encodeURI(
    "https://fitly1.github.io/billing-redirect/redirect.html?type=cancel"
  );

  const session = await stripe.checkout.sessions.create(
    {
      mode: "subscription",
      payment_method_types: ["card"],
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      discounts,
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: { trainerId },
      subscription_data: { metadata: { trainerId } },
    },
    { idempotencyKey }
  );

  console.log(
    `Subscription session created for trainer ${trainerId}${
      promoCodeInput ? ` (promo: ${promoCodeInput})` : ""
    }`
  );
  return { sessionUrl: session.url };
});

/* ──────────────────────────────────────────────────────────────
   4) CALLABLE: createBillingPortalSession (original)
───────────────────────────────────────────────────────────────*/
exports.createBillingPortalSession = onCall(async (data, context) => {
  if (!context.auth)
    throw new HttpsError("unauthenticated", "User must be authenticated.");

  const customerId = data.customerId;
  if (!customerId)
    throw new HttpsError("invalid-argument", "Customer ID is required.");

  try {
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: "fitly://dashboard",
    });
    return { url: session.url };
  } catch (error) {
    console.error("Error creating billing portal session:", error);
    throw new HttpsError("internal", error.message);
  }
});

/* ──────────────────────────────────────────────────────────────
   5) STRIPE WEBHOOK HTTP FUNCTION (original)
───────────────────────────────────────────────────────────────*/
const bodyParser = require("body-parser");
const webhookApp = express();

webhookApp.use(
  bodyParser.raw({
    type: "application/json",
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);

webhookApp.post("/", async (req, res) => {
  let event;
  const sig = req.headers["stripe-signature"];

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
  } catch (err) {
    console.error("❌ Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  const data = event.data.object;

  switch (event.type) {
    /* INITIAL SUBSCRIPTION */
    case "checkout.session.completed": {
      if (data.mode === "subscription") {
        const trainerId = data.metadata?.trainerId;
        const customerId = data.customer;
        await admin
          .firestore()
          .doc(`trainer_profiles/${trainerId}`)
          .set(
            { isActive: true, stripeId: customerId, subscriptionStatus: "active" },
            { merge: true }
          );
        console.log(`✅ Trainer ${trainerId} is now ACTIVE`);
      }
      break;
    }

    /* ANY SUBSCRIPTION STATUS CHANGE */
    case "customer.subscription.updated":
    case "customer.subscription.deleted": {
      const trainerId = data.metadata?.trainerId;
      if (trainerId) {
        await admin
          .firestore()
          .doc(`trainer_profiles/${trainerId}`)
          .set(
            { isActive: data.status === "active", subscriptionStatus: data.status },
            { merge: true }
          );
        console.log(`🔄 Trainer ${trainerId} status → ${data.status}`);
      }
      break;
    }

    /* FAILED PAYMENT */
    case "invoice.payment_failed": {
      const subId = data.subscription;
      const sub = await stripe.subscriptions.retrieve(subId);
      const trainerId = sub.metadata?.trainerId;
      if (trainerId) {
        await admin
          .firestore()
          .doc(`trainer_profiles/${trainerId}`)
          .set(
            { isActive: false, subscriptionStatus: sub.status },
            { merge: true }
          );
        console.log(`⚠️  Trainer ${trainerId} payment failed → ${sub.status}`);
      }
      break;
    }
  }

  res.json({ received: true });
});

exports.handleStripeWebhook = onRequest(webhookApp);

/* ──────────────────────────────────────────────────────────────
   6) DAILY STRIPE RECONCILIATION (original)
───────────────────────────────────────────────────────────────*/
exports.reconcileSubscriptions = onSchedule("every 24 hours", async () => {
  try {
    const trainerSnapshot = await admin
      .firestore()
      .collection("trainer_profiles")
      .where("stripeId", ">", "")
      .get();

    trainerSnapshot.forEach(async (doc) => {
      const trainerData = doc.data();
      const stripeId = trainerData.stripeId;
      if (!stripeId) return;

      try {
        const subscriptions = await stripe.subscriptions.list({
          customer: stripeId,
          limit: 1,
        });
        if (subscriptions.data.length > 0) {
          const subscription = subscriptions.data[0];
          const status = subscription.status;
          console.log(
            `Reconciliation: Trainer ${doc.id} subscription status is ${status}`
          );
          await doc.ref.set(
            { isActive: status === "active", subscriptionStatus: status },
            { merge: true }
          );
        } else {
          await doc.ref.set(
            { isActive: false, subscriptionStatus: "none" },
            { merge: true }
          );
        }
      } catch (stripeError) {
        console.error(
          `Error reconciling subscription for trainer ${doc.id}:`,
          stripeError
        );
      }
    });
    console.log("Subscription reconciliation completed.");
  } catch (error) {
    console.error("Error during subscription reconciliation:", error);
  }
});

/* ──────────────────────────────────────────────────────────────
   7) createTrainerCustomer (original Firestore trigger)
───────────────────────────────────────────────────────────────*/
exports.createTrainerCustomer = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const userData = event.data.data();
    const uid = event.params.uid;

    if (userData.role !== "trainer") {
      console.log(`Skipping non-trainer ${uid}`);
      return;
    }

    if (userData.stripeCustomerId) {
      console.log(
        `Trainer ${uid} already has Stripe customer ${userData.stripeCustomerId}`
      );
      return;
    }

    const customer = await stripe.customers.create({
      email: userData.email,
      metadata: { firebaseUID: uid },
    });

    await Promise.all([
      event.ref.update({ stripeCustomerId: customer.id }), // users/{uid}
      admin
        .firestore()
        .doc(`trainer_profiles/${uid}`) // trainer_profiles/{uid}
        .set({ stripeId: customer.id, isActive: false }, { merge: true }),
    ]);

    console.log(`✨ Created Stripe customer ${customer.id} for trainer ${uid}`);
  }
);

/* ──────────────────────────────────────────────────────────────
   🍏  A P P L E   I N -A P P   P U R C H A S E S
───────────────────────────────────────────────────────────────*/

/* 8) Callable: verifyIosReceipt */
exports.verifyIosReceipt = onCall(async (req) => {
  const { data, auth } = req;
  if (!auth) throw new HttpsError("unauthenticated", "Login first");
  if (!APPLE_SHARED_SECRET)
    throw new HttpsError(
      "failed-precondition",
      "Server not configured for Apple IAP"
    );

  const receiptData = data?.receiptData;
  if (!receiptData)
    throw new HttpsError("invalid-argument", "Missing receiptData");

  const verifyRes = await verifyReceipt(receiptData);
  const expiresMs = getLatestExpiry(verifyRes);
  const isActive = expiresMs > Date.now();

  await admin.firestore().doc(`trainer_profiles/${auth.uid}`).set(
    {
      isActive: isActive,
      iosExpiry: expiresMs,
      iosOriginalTxId: verifyRes.latest_receipt_info?.slice(-1)[0]
        ?.original_transaction_id || null,
      latestIosReceiptData: receiptData,
    },
    { merge: true }
  );

  console.log(`🍏 verifyIosReceipt: uid=${auth.uid} active=${isActive}`);
  return { active: isActive, expiresMs };
});

/* 9) Apple Server Notifications v2 (HTTP endpoint) */
const appleApp = express();
appleApp.use(express.json({ limit: "5mb" }));

appleApp.post("/", async (req, res) => {
  try {
    const { notificationType, data } = req.body;
    const renewalInfo = decodeJwtPayload(data.signedRenewalInfo);
    const transactionInfo = decodeJwtPayload(data.signedTransactionInfo);

    const originalTxId =
      renewalInfo.originalTransactionId ||
      transactionInfo.originalTransactionId;
    const autoRenew = renewalInfo.autoRenewStatus === "1";

    const statusMap = {
      DID_RENEW: "active",
      INITIAL_BUY: "active",
      DID_FAIL_TO_RENEW: "past_due",
      CANCEL: "canceled",
    };
    const status =
      statusMap[notificationType] || (autoRenew ? "active" : "canceled");
    const isActive = status === "active";

    const snap = await admin
      .firestore()
      .collection("trainer_profiles")
      .where("iosOriginalTxId", "==", originalTxId)
      .limit(1)
      .get();

    if (snap.empty) {
      console.warn(`🍏 Apple webhook: originalTxId ${originalTxId} not mapped`);
    } else {
      const ref = snap.docs[0].ref;
      await ref.set({ isActive, subscriptionStatus: status }, { merge: true });
      console.log(`🍏 Trainer ${ref.id} → ${status}`);
    }
    res.json({ received: true });
  } catch (err) {
    console.error("🍏 Apple webhook error:", err);
    res.status(500).send("Webhook error");
  }
});

exports.handleAppleServerNotification = onRequest(appleApp);

/* 10) DAILY iOS RECONCILIATION – REPLACED WITH REQUESTED LOGIC */
exports.reconcileIosSubscriptions = onSchedule("every 24 hours", async () => {
  if (!APPLE_SHARED_SECRET) {
    console.warn("🍏 Skipping iOS reconciliation — no shared secret");
    return;
  }

  const firestore = admin.firestore();
  const trainersRef = firestore.collection("trainer_profiles");
  const snapshot = await trainersRef
    .where("latestIosReceiptData", ">", "")
    .get();

  console.log(`🔍 Checking ${snapshot.size} trainers for iOS reconciliation`);

  for (const doc of snapshot.docs) {
    const trainer = doc.data();
    const receiptData = trainer.latestIosReceiptData;

    try {
      const response = await verifyReceipt(receiptData);
      const latestExpiryMillis = getLatestExpiry(response);
      const isActive = latestExpiryMillis > Date.now();

      await doc.ref.update({
        isActive,
        iosExpiry: latestExpiryMillis,
        subscriptionStatus: isActive ? "active" : "expired",
      });

      console.log(`✅ ${doc.id} updated. Active: ${isActive}`);
    } catch (err) {
      console.error(`❌ Error for ${doc.id}:`, err);
    }
  }

  console.log("🍏 iOS reconciliation completed.");
});

/* 11) Firestore Trigger – Validate trainer_profiles on write */
exports.validateTrainerProfile = onDocumentWritten(
  "trainer_profiles/{trainerId}",
  async (event) => {
    const data = event.data?.after?.data();
    if (!data) return;

    const MAX_DESC = 1000;
    const MAX_IMAGES = 6;

    if (data.description && data.description.length > MAX_DESC) {
      console.warn("❌ Description too long");
      throw new HttpsError(
        "invalid-argument",
        `Description exceeds ${MAX_DESC} characters.`
      );
    }

    if (
      Array.isArray(data.workImageUrls) &&
      data.workImageUrls.length > MAX_IMAGES
    ) {
      console.warn("❌ Too many work images");
      throw new HttpsError(
        "invalid-argument",
        `Only ${MAX_IMAGES} work images allowed.`
      );
    }

    return;
  }
);

/* ──────────────────────────────────────────────────────────────
   NEW TRIGGER: auto-update trainer_profiles.rating
───────────────────────────────────────────────────────────────*/
exports.updateTrainerAvgRating = onDocumentWritten(
  "trainer_profiles/{uid}/reviews/{rid}",
  async (event) => {
    const { uid } = event.params;
    await recomputeTrainerRating(uid);
  }
);

/* ──────────────────────────────────────────────────────────────
   FIRESTORE TRIGGER → SEND PUSH NOTIFICATION (NEW BLOCK)
───────────────────────────────────────────────────────────────*/
exports.pushOnNewNotification = onDocumentCreated(
  "users/{userId}/notifications/{notifId}",
  async (event) => {
    const data = event.data.data(); // what the client wrote
    const userId = event.params.userId;

    // 1) Fetch this user’s device tokens
    const tokensSnap = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("tokens")
      .get();

    if (tokensSnap.empty) {
      console.log(`No device tokens for user ${userId}`);
      return null;
    }

    // 2) Build the FCM payload
    const payload = {
      notification: {
        title: data.title ?? "Fitly",
        body: data.body ?? "",
      },
      data: {
        route: data.route ?? "", // used by _handleNavigationFromMessage
      },
    };

    // 3) Send to every token
    const tokens = tokensSnap.docs.map((d) => d.id);
    const resp = await admin.messaging().sendToDevice(tokens, payload);

    // 4) Clean up any outdated / invalid tokens
    const batch = admin.firestore().batch();
    resp.results.forEach((r, idx) => {
      const err = r.error;
      if (
        err &&
        (err.code === "messaging/invalid-registration-token" ||
          err.code === "messaging/registration-token-not-registered")
      ) {
        batch.delete(
          admin
            .firestore()
            .collection("users")
            .doc(userId)
            .collection("tokens")
            .doc(tokens[idx])
        );
      }
    });
    await batch.commit();

    console.log(`🕊️  Sent push to ${tokens.length} tokens for user ${userId}`);
    return null;
  }
);

/* ──────────────────────────────────────────────────────────────
   CHAT  →  PUSH NOTIFICATION   (v1 API version)
───────────────────────────────────────────────────────────────*/
exports.notifyOnNewMessage = onDocumentCreated(
  "conversations/{cid}/messages/{mid}",
  async (event) => {
    const msg = event.data.data();
    if (!msg) return null;

    const toUid = msg.recipientId;
    const fromUid = msg.senderId;
    if (!toUid || !fromUid || toUid === fromUid) return null;

    /* 1) fetch recipient tokens */
    const tokensSnap = await admin
      .firestore()
      .collection("users")
      .doc(toUid)
      .collection("tokens")
      .get();
    if (tokensSnap.empty) {
      console.log(`notifyOnNewMessage: no tokens for user ${toUid}`);
      return null;
    }
    const tokens = tokensSnap.docs.map((d) => d.id);

    /* 2) compose notification */
    const title =
      msg.senderName ||
      (await admin
        .auth()
        .getUser(fromUid)
        .then((u) => u.displayName || "New message")
        .catch(() => "New message"));

    const body =
      typeof msg.message === "string" && msg.message.length > 40
        ? msg.message.substring(0, 37) + "…"
        : msg.message || "";

    const notif = { title, body };
    const data  = {
      route: "/chat",                         // adjust if needed
      conversationId: event.params.cid,
    };

    /* 3) send through FCM v1 (sendEach) */
    const resp = await admin.messaging().sendEach(
      tokens.map((t) => ({
        token: t,
        notification: notif,
        data: data,
      }))
    );
    console.log(
      `💬 sent to ${tokens.length} device(s) – convo ${event.params.cid}`
    );

    /* 4) remove invalid tokens */
    const batch = admin.firestore().batch();
    resp.responses.forEach((r, idx) => {
      if (!r.success) {
        const code = r.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered"
        ) {
          batch.delete(
            admin
              .firestore()
              .collection("users")
              .doc(toUid)
              .collection("tokens")
              .doc(tokens[idx])
          );
        }
      }
    });
    await batch.commit();
    return null;
  }
);