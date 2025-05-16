// Import Gen2 APIs for non-webhook routes and Firestore triggers 
const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const express = require("express");
const cors = require("cors");
require("dotenv").config(); // Loads local .env if present (for dev)

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Retrieve the Stripe secret key from environment variables
const STRIPE_SECRET_KEY =
  process.env.STRIPE_SECRET_KEY ||
  functions.config().stripe.secret_key ||
  "";

if (!STRIPE_SECRET_KEY) {
  console.error("❌ Missing Stripe Secret Key!");
}

const stripe = require("stripe")(STRIPE_SECRET_KEY);

// Retrieve the Stripe webhook secret from environment variables
const WEBHOOK_SECRET =
  process.env.STRIPE_WEBHOOK_SECRET ||
  functions.config().stripe.webhook_secret ||
  "";

if (!WEBHOOK_SECRET) {
  console.error("❌ Missing Stripe Webhook Secret!");
}

// ------------------------------------------
// 1) Create an Express app for NON-webhook routes (Gen2)
// ------------------------------------------
const app = express();
app.use(cors({ origin: true }));

// Only parse JSON for /api routes
app.use("/api", express.json());

// Health-check route
app.get("/", (req, res) => {
  res.send("Stripe server is running!");
});

/**
 * POST /createPaymentIntent
 * Creates a PaymentIntent on Stripe and returns its client secret.
 */
app.post("/createPaymentIntent", async (req, res) => {
  try {
    const { amount, currency, trainerUid, email } = req.body;
    if (!amount || !currency || !trainerUid || !email) {
      return res.status(400).json({ error: "Missing required fields." });
    }

    // Role check before proceeding
    const userDoc = await admin.firestore().collection('users').doc(trainerUid).get();
    if (!userDoc.exists || userDoc.data().role !== 'trainer') {
      return res.status(403).json({ error: "Only trainers can create payment intents." });
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

    console.log(`Created PaymentIntent ${paymentIntent.id} for trainer ${trainerUid}`);
    return res.status(200).json({ clientSecret: paymentIntent.client_secret });
  } catch (error) {
    console.error("❌ Error creating PaymentIntent:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * POST /issueRefund
 * Issues a refund for a given charge ID.
 */
app.post("/issueRefund", async (req, res) => {
  try {
    const { chargeId, amount } = req.body;
    if (!chargeId) {
      return res.status(400).json({ error: "Missing required chargeId." });
    }
    const refundData = { charge: chargeId };
    if (amount) {
      refundData.amount = amount;
    }
    const idempotencyKey = `refund_${chargeId}_${Date.now()}`;
    const refund = await stripe.refunds.create(refundData, { idempotencyKey });
    console.log(`Refund issued for charge ${chargeId}`);
    return res.status(200).json({ refund });
  } catch (error) {
    console.error("Error issuing refund:", error);
    return res.status(500).json({ error: error.message });
  }
});

// Export the Express app as an HTTP function using Gen2.
exports.api = onRequest(app);

// ------------------------------------------
// 2) Firestore Trigger: Create Payment Request (One-Time Payment)
// ------------------------------------------
exports.createPaymentRequest = onDocumentCreated(
  "stripe_payment_requests/{docId}",
  async (event) => {
    try {
      const data = event.data;
      console.log("New payment request data:", data);
      
      // Check user role before creating payment request. 
      const userDoc = await admin.firestore().collection('users').doc(data.trainerUid).get();
      if (!userDoc.exists || userDoc.data().role !== 'trainer') {
        console.error("Customer account triggered payment request; skipping.");
        return; // Skip processing for non-trainers
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
        success_url: "https://fitly1.github.io/billing-redirect/redirect.html?type=success",
        cancel_url: "https://fitly1.github.io/billing-redirect/redirect.html?type=cancel",
        customer_email: data.email || "",
      });
      await admin.firestore().doc(`stripe_payment_requests/${event.params.docId}`).update({
        url: session.url,
        sessionId: session.id,
      });
      console.log(`Checkout session created for payment request ${event.params.docId}`);
    } catch (err) {
      console.error("Error creating Checkout Session", err);
      await admin.firestore().doc(`stripe_payment_requests/${event.params.docId}`).update({
        error: err.message,
      });
    }
  }
);

// ------------------------------------------
// 3) Callable Function: Create Subscription Checkout Session (Gen2)
// ------------------------------------------
exports.createSubscriptionCheckoutSession = onCall(async (req) => {
  const { data, auth } = req;
  if (!auth) {
    throw new Error("User must be authenticated");
  }
  
  const trainerId = auth.uid;
  const priceId = "price_1QxLgJIwC3BBH5MDFZO28ndV"; // Provided LIVE Price ID

  // Retrieve trainer's email from Firebase Auth.
  const trainerUser = await admin.auth().getUser(trainerId);
  const email = trainerUser.email;
  if (!email) {
    throw new Error("Trainer's email is not available");
  }

  // Check user's role
  const userDoc = await admin.firestore().collection('users').doc(trainerId).get();
  if (userDoc.exists && userDoc.data().role !== 'trainer') {
    throw new Error("Only trainers can create subscription checkout sessions.");
  }

  // Retrieve or create the customer's Stripe ID from Firestore.
  const trainerRef = admin.firestore().doc(`trainer_profiles/${trainerId}`);
  const trainerDoc = await trainerRef.get();
  let customerId = trainerDoc.exists ? trainerDoc.data().stripeId : null;

  if (!customerId) {
    try {
      const idempotencyKey = `cust_${trainerId}_${Date.now()}`;
      const newCustomer = await stripe.customers.create({ email }, { idempotencyKey });
      customerId = newCustomer.id;
      await trainerRef.update({
        stripeId: customerId,
        isActive: false,
      });
      console.log(`Created new Stripe customer ${customerId} for trainer ${trainerId}`);
    } catch (error) {
      console.error("Error creating new Stripe customer:", error);
      throw new Error("Failed to create Stripe customer");
    }
  } else {
    console.log(`Found existing Stripe customer ${customerId} for trainer ${trainerId}`);
  }

  // Update the Stripe customer with the correct email.
  try {
    await stripe.customers.update(customerId, { email });
    console.log(`Updated Stripe customer ${customerId} with email ${email}`);
  } catch (error) {
    console.error("Error updating customer email:", error);
    throw new Error("Failed to update customer email");
  }

  // Clear any existing balance to ensure full price is charged.
  try {
    await stripe.customers.update(customerId, { balance: 0 });
    console.log(`Cleared existing balance for customer ${customerId}`);
  } catch (error) {
    console.error("Error clearing customer balance:", error);
  }

  try {
    const idempotencyKey = `subsess_${trainerId}_${Date.now()}`;
    const successUrl = encodeURI("https://fitly1.github.io/billing-redirect/redirect.html?type=success");
    const cancelUrl = encodeURI("https://fitly1.github.io/billing-redirect/redirect.html?type=cancel");

    console.log("Success URL:", successUrl);
    console.log("Cancel URL:", cancelUrl);

    // Create a Subscription Checkout Session with metadata in both places.
    const session = await stripe.checkout.sessions.create(
      {
        mode: "subscription",
        payment_method_types: ["card"],
        customer: customerId,
        line_items: [{ price: priceId, quantity: 1 }],
        success_url: successUrl,
        cancel_url: cancelUrl,
        metadata: { trainerId },
        subscription_data: {
          metadata: { trainerId },
        },
      },
      { idempotencyKey }
    );
    console.log(`Subscription session created for trainer ${trainerId}`);
    return { sessionUrl: session.url };
  } catch (error) {
    console.error("Error creating Subscription Checkout Session:", error);
    throw new Error(error.message);
  }
});

// ------------------------------------------
// 4) Callable Function: Create Billing Portal Session (Dynamic)
// ------------------------------------------
exports.createBillingPortalSession = onCall(async (data, context) => {
  console.log("=== createBillingPortalSession invoked ===");
  console.log("context.auth:", JSON.stringify(context.auth));
  
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }
  const customerId = data.customerId;
  if (!customerId) {
    throw new functions.https.HttpsError('invalid-argument', 'Customer ID is required.');
  }
  try {
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: 'fitly://dashboard', // Update this URL to your desired return location
    });
    console.log(`Billing portal session created for customer ${customerId}`);
    return { url: session.url };
  } catch (error) {
    console.error("Error creating billing portal session:", error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ------------------------------------------
// 5) Webhook Function: Gen2 function with raw body parsing
// ------------------------------------------
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

console.log("Using Webhook Secret:", WEBHOOK_SECRET);

webhookApp.post("/", async (req, res) => {
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      req.headers["stripe-signature"],
      WEBHOOK_SECRET
    );
    console.log("Webhook event received:", JSON.stringify(event.data.object));
  } catch (err) {
    console.error("Webhook signature verification failed.", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  console.log("Received event type:", event.type);

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object;
      if (session.mode === "subscription") {
        const trainerId = session.metadata && session.metadata.trainerId;
        const customerId = session.customer;

        // Only proceed if the user is a trainer
        if (trainerId) {
          const userDoc = await admin.firestore().collection('users').doc(trainerId).get();
          if (userDoc.exists && userDoc.data().role === 'trainer') {
            await admin.firestore().doc(`trainer_profiles/${trainerId}`).set(
              {
                isActive: true,
                stripeId: customerId,
              },
              { merge: true }
            );
            console.log(`Subscription activated for trainer ${trainerId}`);
          } else {
            console.error("User is not a trainer; skipping profile creation.");
          }
        }
      }
      break;
    }
    // ... (Other switch cases remain unchanged)
  }

  res.send({ received: true });
});

// Export the Gen2 webhook function with raw body parsing.
exports.handleStripeWebhook = onRequest({ region: "us-central1" }, webhookApp);

// ------------------------------------------
// 6) Scheduled Function: Reconcile Subscriptions (Edge Case Reconciliation)
// ------------------------------------------
exports.reconcileSubscriptions = onSchedule("every 24 hours", async (event) => {
  try {
    // Query trainer profiles with a non-empty stripeId
    const trainerSnapshot = await admin.firestore().collection("trainer_profiles")
      .where("stripeId", ">", "")
      .get();

    trainerSnapshot.forEach(async (doc) => {
      const trainerData = doc.data();
      const stripeId = trainerData.stripeId;
      if (!stripeId) return;

      try {
        // List subscriptions for the customer in Stripe (limit to 1 for simplicity)
        const subscriptions = await stripe.subscriptions.list({ customer: stripeId, limit: 1 });
        if (subscriptions.data.length > 0) {
          const subscription = subscriptions.data[0];
          const status = subscription.status;
          console.log(`Reconciliation: Trainer ${doc.id} subscription status is ${status}`);
          // Update Firestore based on Stripe status
          await doc.ref.set(
            {
              isActive: status === "active",
              subscriptionStatus: status,
            },
            { merge: true }
          );
        } else {
          // No subscription found; mark as inactive.
          await doc.ref.set(
            {
              isActive: false,
              subscriptionStatus: "none",
            },
            { merge: true }
          );
        }
      } catch (stripeError) {
        console.error(`Error reconciling subscription for trainer ${doc.id}:`, stripeError);
      }
    });
    console.log("Subscription reconciliation completed.");
  } catch (error) {
    console.error("Error during subscription reconciliation:", error);
  }
});