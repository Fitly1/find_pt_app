/* ──────────────────────────────────────────────────────────────
   IMPORTS & INITIALISATION – ORIGINAL + SMALL ADDITIONS
───────────────────────────────────────────────────────────────*/
"use strict";

const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
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

/* ✅ IMPORTANT: define CONCIERGE_UID BEFORE any function uses it */
const CONCIERGE_UID = "JzPLt6B6PFhnXxjaZI4t4lFnoKQ2"; // ensure this exists only once

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

/* ──────────────────────────────────────────────────────────────
   ✅ NEW: Billing “source of truth” writer (SAFE: does NOT change app behavior)
   - Writes to trainer_billing/{uid}
   - Keeps all existing trainer_profiles fields untouched (so nothing breaks)
───────────────────────────────────────────────────────────────*/
function computeEntitlementFromStatus(status) {
  const activeLike = status === "active" || status === "trialing";
  return {
    isActive: !!activeLike,
    subscriptionStatus: status || "none",
    activeUntil: null, // optional; we set it when we have a period end/expiry
  };
}

async function upsertTrainerBilling(trainerId, patch) {
  if (!trainerId) return;

  const ref = admin.firestore().doc(`trainer_billing/${trainerId}`);

  const entitlementPatch = patch?.entitlement || {};
  const stripePatch = patch?.stripe || {};
  const applePatch = patch?.apple || {};

  await ref.set(
    {
      entitlement: {
        // defaults so schema stays consistent
        isActive: false,
        subscriptionStatus: "none",
        source: "none", // "stripe" | "apple" | "admin" | "free" | "none"
        activeUntil: null,
        ...entitlementPatch,
      },
      stripe: { ...stripePatch },
      apple: { ...applePatch },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/* ─── Stripe config (unchanged) ──────────────────────────────*/
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || "";
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || "";

if (!STRIPE_SECRET_KEY) console.error("❌ Missing Stripe Secret Key!");
if (!WEBHOOK_SECRET) console.error("❌ Missing Stripe Webhook Secret!");

const stripe = require("stripe")(STRIPE_SECRET_KEY);

/* ─── Feature-flags ───────────────────── */
const TRAINER_PAYMENTS_ENABLED = false; // flip to true when you re-enable

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
   ✅ OPTION B (MANDATORY): ensureTrainerProfile
   - Creates trainer_profiles/{uid} when users/{uid}.role == "trainer"
   - Only fills missing fields (does NOT overwrite real profile data)
   - No Stripe, no payments, no breaking changes
───────────────────────────────────────────────────────────────*/
exports.ensureTrainerProfile = onDocumentWritten("users/{uid}", async (event) => {
  const uid = event.params.uid;

  // ignore deletes
  if (!event.data?.after?.exists) return;

  const after = event.data.after.data() || {};
  const role = String(after.role || "").toLowerCase();
  if (role !== "trainer") return;

  const db = admin.firestore();
  const trainerRef = db.doc(`trainer_profiles/${uid}`);
  const trainerSnap = await trainerRef.get();

  const name = String(after.name || after.displayName || after.fullName || "").trim();
  const email = String(after.email || "").trim();

  const defaults = {
    userId: uid,
    role: "trainer",
    // keep both flags because your app history is mixed
    isHidden: false,
    profileHidden: false,
    createdFromUserSync: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // create if missing
  if (!trainerSnap.exists) {
    await trainerRef.set(
      {
        ...defaults,
        ...(name ? { name } : {}),
        ...(email ? { email } : {}),
      },
      { merge: true }
    );
    console.log(`✅ ensureTrainerProfile: created trainer_profiles/${uid}`);
    return;
  }

  // patch only missing fields
  const t = trainerSnap.data() || {};
  const patch = {};

  if (t.userId === undefined) patch.userId = uid;
  if (t.role === undefined) patch.role = "trainer";
  if (t.isHidden === undefined) patch.isHidden = false;
  if (t.profileHidden === undefined) patch.profileHidden = false;

  if (!String(t.name || "").trim() && name) patch.name = name;
  if (!t.email && email) patch.email = email;

  if (Object.keys(patch).length) {
    await trainerRef.set(patch, { merge: true });
    console.log(`✅ ensureTrainerProfile: patched trainer_profiles/${uid}`, patch);
  }
});

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

  /* ── Feature-flag guard ─────────────── */
  if (!TRAINER_PAYMENTS_ENABLED) {
    console.log("⚠️  Trainer payments currently disabled – skipping.");
    return { disabled: true };
  }

  const trainerId = auth.uid;
  const priceId = "price_1QxLgJIwC3BBH5MDFZO28ndV"; // LIVE price

  const trainerUser = await admin.auth().getUser(trainerId);
  const email = trainerUser.email;
  if (!email) throw new Error("Trainer's email is not available");

  const userDoc = await admin.firestore().collection("users").doc(trainerId).get();
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
  const matchedCouponId = promoCodeInput
    ? PROMO_CODE_MAP[promoCodeInput]
    : null;

  if (promoCodeInput && !matchedCouponId) {
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
exports.createBillingPortalSession = onCall(async (req) => {
  if (!req.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const customerId = req.data?.customerId;
  if (!customerId) {
    throw new HttpsError("invalid-argument", "Customer ID is required.");
  }

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
   5) STRIPE WEBHOOK HTTP FUNCTION  (idempotent + fall-backs)
   ✅ UPDATED: also writes to trainer_billing/{uid} (does NOT remove old fields)
───────────────────────────────────────────────────────────────*/
const bodyParser = require("body-parser");
const webhookApp = express();

webhookApp.use(
  bodyParser.raw({
    type: "application/json",
    verify: (req, res, buf) => {
      req.rawBody = buf; // save raw body for Stripe signature check
    },
  })
);

webhookApp.post("/", async (req, res) => {
  let event;
  const sig = req.headers["stripe-signature"];

  /* ---------- 1. verify signature ---------- */
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
  } catch (err) {
    console.error("❌  Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  /* ---------- 2. idempotency: skip if done ---------- */
  const eventRef = admin
    .firestore()
    .collection("stripe_webhook_events")
    .doc(event.id);

  const alreadyDone = await eventRef.get();
  if (alreadyDone.exists) {
    return res.status(200).send("Already processed");
  }

  const data = event.data.object;

  /* ---------- 3. handle event types ---------- */
  try {
    switch (event.type) {
      /* 3-a  checkout.session.completed  (first time only) */
      case "checkout.session.completed": {
        if (data.mode === "subscription") {
          const trainerId = data.metadata?.trainerId;
          const customerId = data.customer;

          if (trainerId && customerId) {
            await admin
              .firestore()
              .doc(`trainer_profiles/${trainerId}`)
              .set(
                {
                  isActive: true, // refined soon by sub events
                  stripeId: customerId,
                  subscriptionStatus: "active",
                },
                { merge: true }
              );

            await upsertTrainerBilling(trainerId, {
              entitlement: {
                ...computeEntitlementFromStatus("active"),
                source: "stripe",
              },
              stripe: {
                customerId,
                lastEvent: "checkout.session.completed",
              },
            });

            console.log(`✅  Trainer ${trainerId} is now ACTIVE (checkout)`);
          } else {
            console.warn(
              "⚠️  checkout.session.completed without trainerId or customerId"
            );
          }
        }
        break;
      }

      /* 3-b  subscription created/updated */
      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const status = data.status; // active, trialing, …
        const customerId = data.customer;
        let trainerId = data.metadata?.trainerId;

        if (!trainerId && customerId) {
          const snap = await admin
            .firestore()
            .collection("trainer_profiles")
            .where("stripeId", "==", customerId)
            .limit(1)
            .get();
          if (!snap.empty) trainerId = snap.docs[0].id;
        }

        if (trainerId) {
          const isActiveLike = status === "active" || status === "trialing";
          await admin
            .firestore()
            .doc(`trainer_profiles/${trainerId}`)
            .set(
              {
                isActive: isActiveLike,
                subscriptionStatus: status,
                stripeId: customerId,
              },
              { merge: true }
            );

          const currentPeriodEndTs =
            data.current_period_end != null
              ? admin.firestore.Timestamp.fromMillis(
                  Number(data.current_period_end) * 1000
                )
              : null;

          await upsertTrainerBilling(trainerId, {
            entitlement: {
              ...computeEntitlementFromStatus(status),
              source: "stripe",
              activeUntil: currentPeriodEndTs,
            },
            stripe: {
              customerId,
              subscriptionId: data.id,
              currentPeriodEnd: currentPeriodEndTs,
              lastEvent: event.type,
            },
          });

          console.log(`🔄  Trainer ${trainerId} status → ${status}`);
        } else {
          console.warn(`⚠️  No trainer profile found for subscription ${data.id}`);
        }
        break;
      }

      /* 3-c  subscription deleted / cancelled */
      case "customer.subscription.deleted": {
        const customerId = data.customer;
        let trainerId = data.metadata?.trainerId;

        if (!trainerId && customerId) {
          const snap = await admin
            .firestore()
            .collection("trainer_profiles")
            .where("stripeId", "==", customerId)
            .limit(1)
            .get();
          if (!snap.empty) trainerId = snap.docs[0].id;
        }

        if (trainerId) {
          await admin
            .firestore()
            .doc(`trainer_profiles/${trainerId}`)
            .set(
              { isActive: false, subscriptionStatus: "canceled" },
              { merge: true }
            );

          await upsertTrainerBilling(trainerId, {
            entitlement: {
              isActive: false,
              subscriptionStatus: "canceled",
              source: "stripe",
            },
            stripe: { customerId, subscriptionId: data.id, lastEvent: event.type },
          });

          console.log(`❌  Trainer ${trainerId} canceled`);
        } else {
          console.warn(
            `⚠️  Subscription deleted but no trainer found (customer ${customerId})`
          );
        }
        break;
      }

      /* 3-d  payment failure */
      case "invoice.payment_failed": {
        const subId = data.subscription;
        const invoiceCustomer = data.customer;
        if (!subId) break;

        const sub = await stripe.subscriptions.retrieve(subId);
        let trainerId = sub.metadata?.trainerId;

        if (!trainerId && sub.customer) {
          const snap = await admin
            .firestore()
            .collection("trainer_profiles")
            .where("stripeId", "==", sub.customer)
            .limit(1)
            .get();
          if (!snap.empty) trainerId = snap.docs[0].id;
        }

        if (trainerId) {
          await admin
            .firestore()
            .doc(`trainer_profiles/${trainerId}`)
            .set(
              { isActive: false, subscriptionStatus: sub.status || "past_due" },
              { merge: true }
            );

          await upsertTrainerBilling(trainerId, {
            entitlement: {
              isActive: false,
              subscriptionStatus: sub.status || "past_due",
              source: "stripe",
            },
            stripe: {
              customerId: sub.customer,
              subscriptionId: sub.id,
              lastEvent: event.type,
            },
          });

          console.log(`⚠️  Trainer ${trainerId} payment failed → ${sub.status}`);
        } else {
          console.warn(
            `⚠️  Payment failed but no trainer found (sub ${subId}, cust ${invoiceCustomer})`
          );
        }
        break;
      }

      default:
        break;
    }

    await eventRef.set({
      type: event.type,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({ received: true });
  } catch (err) {
    console.error("Webhook handler error:", err);
    return res.status(500).send("Webhook handler error");
  }
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
exports.createTrainerCustomer = onDocumentCreated("users/{uid}", async (event) => {
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
});

/* ──────────────────────────────────────────────────────────────
   🍏  A P P L E   I N -A P P   P U R C H A S E S
───────────────────────────────────────────────────────────────*/

/* 8) Callable: verifyIosReceipt
   ✅ UPDATED: also writes to trainer_billing/{uid} (does NOT remove old fields)
*/
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

  const latestInfo = verifyRes.latest_receipt_info?.slice(-1)[0] || null;
  const originalTxId = latestInfo?.original_transaction_id || null;

  await admin.firestore().doc(`trainer_profiles/${auth.uid}`).set(
    {
      isActive: isActive,
      iosExpiry: expiresMs,
      iosOriginalTxId: originalTxId,
      latestIosReceiptData: receiptData,
    },
    { merge: true }
  );

  await upsertTrainerBilling(auth.uid, {
    entitlement: {
      isActive,
      subscriptionStatus: isActive ? "active" : "expired",
      source: "apple",
      activeUntil: expiresMs
        ? admin.firestore.Timestamp.fromMillis(Number(expiresMs))
        : null,
    },
    apple: {
      originalTransactionId: originalTxId,
      expiry: expiresMs
        ? admin.firestore.Timestamp.fromMillis(Number(expiresMs))
        : null,
      productId: "fitly.membership.1",
      lastEvent: "verifyIosReceipt",
    },
  });

  console.log(`🍏 verifyIosReceipt: uid=${auth.uid} active=${isActive}`);
  return { active: isActive, expiresMs };
});

/* 9) Apple Server Notifications v2 (HTTP endpoint)
   ✅ UPDATED: also writes to trainer_billing/{uid} (does NOT remove old fields)
*/
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

      await upsertTrainerBilling(ref.id, {
        entitlement: { isActive, subscriptionStatus: status, source: "apple" },
        apple: { originalTransactionId: originalTxId, lastEvent: notificationType },
      });

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
   FIRESTORE TRIGGER → SEND PUSH NOTIFICATION (existing)
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

    // 3) Send to every token (legacy API for broad compatibility)
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
   CHAT  →  PUSH NOTIFICATION   (UPDATED)
   - Skips sender’s current device (senderDeviceToken)
   - Mirrors Concierge conversations to /concierge_inbox
───────────────────────────────────────────────────────────────*/
exports.notifyOnNewMessage = onDocumentCreated(
  "conversations/{cid}/messages/{mid}",
  async (event) => {
    const cid = event.params.cid;
    const mid = event.params.mid;
    const msg = event.data.data();
    if (!msg) return null;

    const toUid = msg.recipientId;
    const fromUid = msg.senderId;
    if (!toUid || !fromUid || toUid === fromUid) return null;

    const senderDeviceToken = msg.senderDeviceToken || null;

    // 1) fetch recipient tokens
    const tokensSnap = await admin
      .firestore()
      .collection("users")
      .doc(toUid)
      .collection("tokens")
      .get();

    let tokens = tokensSnap.empty
      ? []
      : tokensSnap.docs.map((d) => d.id).filter(Boolean);

    // Exclude the sender's current device token if present
    if (senderDeviceToken) {
      tokens = tokens.filter((t) => t !== senderDeviceToken);
    }

    if (tokens.length) {
      // 2) compose notification
      const title =
        msg.senderName && msg.senderName.trim().length
          ? msg.senderName
          : "New message";

      const text = typeof msg.message === "string" ? msg.message : "";
      const body =
        text.length > 120 ? text.slice(0, 120) + "…" : text || "New message";

      const payload = {
        notification: { title, body },
        data: {
          route: "/messages",
          conversationId: cid,
          senderUid: fromUid,
          recipientUid: toUid,
        },
      };

      // 3) send (legacy API for compatibility)
      const resp = await admin.messaging().sendToDevice(tokens, payload);

      // 4) clean invalid tokens
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
              .doc(toUid)
              .collection("tokens")
              .doc(tokens[idx])
          );
        }
      });
      await batch.commit();

      console.log(
        `✉️ notifyOnNewMessage: ${cid}/${mid} → ${tokens.length} token(s)`
      );
    } else {
      console.log(`notifyOnNewMessage: no tokens for ${toUid}`);
    }

    // 5) Mirror concierge-related messages for ops review
    if (fromUid === CONCIERGE_UID || toUid === CONCIERGE_UID) {
      try {
        const mirrorRef = admin
          .firestore()
          .collection("concierge_inbox")
          .doc(cid)
          .collection("messages")
          .doc(mid);

        await mirrorRef.set(
          {
            ...msg,
            participants: [fromUid, toUid],
            mirroredAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(msg.reply === undefined ? { reply: "" } : {}),
          },
          { merge: true }
        );

        console.log(`🗂️ Mirrored to concierge_inbox/${cid}/messages/${mid}`);
      } catch (err) {
        console.error("concierge mirror error:", err);
      }
    }

    return null;
  }
);

exports.conciergeConsoleReplyOnUpdate = onDocumentWritten(
  "concierge_inbox/{cid}/messages/{mid}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (!after || event.data?.after?.exists === false) return null; // deleted

    // Only act when 'reply' changes from empty → non-empty
    const prevReply = (before.reply ?? "").toString().trim();
    const newReply = (after.reply ?? "").toString().trim();
    if (!newReply || newReply === prevReply) return null;

    // Idempotency: if we already delivered, do nothing
    if (after.deliveredMessageId || after.replySentAt) return null;

    const db = admin.firestore();
    const cid = event.params.cid;
    const conv = db.collection("conversations").doc(cid);

    // Figure out the other participant
    let otherUid = null;
    try {
      const convSnap = await conv.get();
      if (convSnap.exists) {
        const parts = (convSnap.data().participants || []).map(String);
        if (parts.includes(CONCIERGE_UID)) {
          otherUid = parts.find((p) => p !== CONCIERGE_UID) || null;
        }
      }
    } catch (_) {}

    // Fallback to mirrored message’s sender/recipient
    if (!otherUid) {
      const s = String(after.senderId || "");
      const r = String(after.recipientId || "");
      if (s === CONCIERGE_UID && r) otherUid = r;
      else if (r === CONCIERGE_UID && s) otherUid = s;
    }

    if (!otherUid) {
      await event.data.after.ref.set(
        { error: "Could not infer recipient for reply" },
        { merge: true }
      );
      return null;
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    // Keep conversation in sync
    await conv.set(
      {
        participants: admin.firestore.FieldValue.arrayUnion(
          CONCIERGE_UID,
          otherUid
        ),
        lastMessage: newReply,
        timestamp: now,
        unreadBy: [otherUid],
      },
      { merge: true }
    );

    // Send the chat message
    const msgRef = await conv.collection("messages").add({
      senderId: CONCIERGE_UID,
      recipientId: otherUid,
      message: newReply,
      senderName: "Fitly Concierge",
      timestamp: now,
    });

    // Mark this mirrored doc as processed
    await event.data.after.ref.set(
      {
        replySentAt: now,
        deliveredMessageId: msgRef.id,
      },
      { merge: true }
    );

    console.log(`Concierge reply sent for ${cid} → ${msgRef.id}`);
    return null;
  }
);