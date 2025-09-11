// lib/iap_compat_stub.dart
// No-op stand-ins for the in_app_purchase API so code compiles when the plugin
// is removed from pubspec.yaml. Nothing here touches billing on device/build.

import 'dart:async';

class ProductDetails {
  final String id;
  final String title;
  final String description;
  final String price;        // formatted, e.g. "$4.99"
  final double rawPrice;     // numeric
  final String currencyCode;

  const ProductDetails({
    required this.id,
    this.title = '',
    this.description = '',
    this.price = '',
    this.rawPrice = 0.0,
    this.currencyCode = '',
  });
}

class ProductDetailsResponse {
  final bool error; // always false in stub
  final List<String> notFoundIDs;
  final List<ProductDetails> productDetails;
  const ProductDetailsResponse({
    this.error = false,
    this.notFoundIDs = const [],
    this.productDetails = const [],
  });
}

enum PurchaseStatus { pending, purchased, error, canceled, restored }

class IAPError {
  final String message;
  const IAPError(this.message);
}

class PurchaseDetails {
  final String productID;
  final PurchaseStatus status;
  final Object? verificationData;
  final IAPError? error;
  final bool pendingCompletePurchase;

  const PurchaseDetails({
    required this.productID,
    required this.status,
    this.verificationData,
    this.error,
    this.pendingCompletePurchase = false,
  });
}

class PurchaseParam {
  final ProductDetails productDetails;
  final String? applicationUserName; // allow named param your code uses
  const PurchaseParam({
    required this.productDetails,
    this.applicationUserName,
  });
}

class InAppPurchaseStoreKitPlatformAddition {
  Future<void> presentCodeRedemptionSheet() async {}
}

class InAppPurchase {
  InAppPurchase._();
  static final InAppPurchase instance = InAppPurchase._();

  // No purchases emitted in stub.
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  Future<bool> isAvailable() async => false;

  // Query returns empty set (no products) in stub.
  Future<ProductDetailsResponse> queryProductDetails(
      Set<String> identifiers) async {
    return const ProductDetailsResponse(
      error: false,
      notFoundIDs: [],
      productDetails: [],
    );
    // note: you can also return notFoundIDs = identifiers.toList() if preferred
  }

  // Generic platform addition getter; return a no-op for StoreKit
  T getPlatformAddition<T>() {
    if (T == InAppPurchaseStoreKitPlatformAddition) {
      return InAppPurchaseStoreKitPlatformAddition() as T;
    }
    throw UnsupportedError('Platform addition $T not available in stub');
  }

  Future<void> buyNonConsumable({required PurchaseParam purchaseParam}) async {}
  Future<void> buyConsumable({required PurchaseParam purchaseParam}) async {}
  Future<void> restorePurchases() async {}
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
