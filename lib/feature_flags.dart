// lib/feature_flags.dart
//
// Central place for runtime-toggled features.
// Flip any of these to `true` when you’re ready to re-enable them.

/// When `true`, trainers are shown the Stripe / Apple IAP paywall.
/// When `false`, the paywall UI auto-skips and no subscription
/// creation is attempted on the client side.
const bool isTrainerPaymentsEnabled = false;

// ──────────────────────────────────────────────────────
// Add future flags below, e.g.:
//
// const bool isCustomerSignupRequiredEarly = true;
// const bool isBetaChatEnabled             = false;
// ──────────────────────────────────────────────────────
