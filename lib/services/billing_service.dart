import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:vitals_10/utils/currency_formatter.dart';

/// Product IDs for subscriptions - must match Google Play Console
class SubscriptionProducts {
  static const String monthlySubscription = 'bp_alerts_monthly';
  static const String annualSubscription = 'bp_alerts_annual';

  static const Set<String> allProductIds = {
    monthlySubscription,
    annualSubscription,
  };

  static const Map<String, double> prices = {
    monthlySubscription: AppPricing.monthlySubscription,
    annualSubscription: AppPricing.annualSubscription,
  };

  static const Map<String, int> durationDays = {
    monthlySubscription: 30,
    annualSubscription: 365,
  };
}

class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  String? _queryProductError;
  String? get queryProductError => _queryProductError;

  // Promo Code
  String? _appliedPromoCode;
  String? get appliedPromoCode => _appliedPromoCode;
  Map<String, dynamic>? _promoCodeOffer;
  Map<String, dynamic>? get promoCodeOffer => _promoCodeOffer;

  // Callbacks
  Function(String message)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;
  Function(bool pending)? onPurchasePending;

  /// Initialize the billing service
  Future<void> initialize() async {
    _isAvailable = await _inAppPurchase.isAvailable();

    if (!_isAvailable) {
      _queryProductError = 'Store not available';
      debugPrint('BillingService: Store not available');
      return;
    }

    // Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseDone,
      onError: _onPurchaseError,
    );

    // Load products
    await loadProducts();
  }

  /// Load available products from the store
  Future<void> loadProducts() async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(SubscriptionProducts.allProductIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('BillingService: Products not found: ${response.notFoundIDs}');
      _queryProductError =
          'Some products not found. Please ensure they are set up in Google Play Console.';
    }

    if (response.error != null) {
      _queryProductError = response.error!.message;
      debugPrint('BillingService: Query error: ${response.error!.message}');
    }

    _products = response.productDetails;
    debugPrint('BillingService: Loaded ${_products.length} products');
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store not available');
      return false;
    }

    final ProductDetails? productDetails = _products.firstWhere(
      (product) => product.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    if (productDetails == null) {
      onPurchaseError?.call('Product not found');
      return false;
    }

    // For Android, use the base plan offer (no free trial) explicitly
    PurchaseParam purchaseParam;

    if (productDetails is GooglePlayProductDetails) {
      final subscriptionOffers = productDetails.productDetails.subscriptionOfferDetails;

      // Find the base plan offer (offerId is null for base plan)
      String? baseOfferToken;
      if (subscriptionOffers != null) {
        for (final offer in subscriptionOffers) {
          // Base plan offer has null offerId
          if (offer.offerId == null) {
            baseOfferToken = offer.offerIdToken;
            debugPrint('BillingService: Found base plan offer token');
            break;
          }
        }
      }

      if (baseOfferToken != null) {
        debugPrint('BillingService: Purchasing with BASE plan offer (no trial)');
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          offerToken: baseOfferToken,
        );
      } else {
        debugPrint('BillingService: No base offer found, using default');
        purchaseParam = PurchaseParam(productDetails: productDetails);
      }
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    try {
      // For subscriptions, use buyNonConsumable
      final bool success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      debugPrint('BillingService: Purchase error: $e');
      onPurchaseError?.call('Purchase failed: $e');
      return false;
    }
  }

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          onPurchasePending?.call(true);
          debugPrint('BillingService: Purchase pending');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchasePending = false;
          onPurchasePending?.call(false);

          // Verify and deliver the product
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _deliverProduct(purchaseDetails);
            onPurchaseSuccess?.call('Subscription activated successfully!');
          } else {
            onPurchaseError?.call('Purchase verification failed');
          }

          // Complete the purchase
          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.error:
          _purchasePending = false;
          onPurchasePending?.call(false);
          onPurchaseError?.call(
              purchaseDetails.error?.message ?? 'Purchase failed');
          debugPrint(
              'BillingService: Purchase error: ${purchaseDetails.error?.message}');

          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.canceled:
          _purchasePending = false;
          onPurchasePending?.call(false);
          debugPrint('BillingService: Purchase canceled');

          if (purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;
      }
    }
  }

  /// Verify purchase (basic client-side verification)
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // For production, implement server-side verification
    // This is a basic client-side check
    return purchaseDetails.verificationData.serverVerificationData.isNotEmpty;
  }

  /// Deliver the product (update Firebase)
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('BillingService: No user logged in');
      return;
    }

    final String productId = purchaseDetails.productID;
    final int durationDays =
        SubscriptionProducts.durationDays[productId] ?? 30;
    final double amount = SubscriptionProducts.prices[productId] ?? 4.99;

    final DateTime now = DateTime.now();
    final DateTime subscriptionEndDate = now.add(Duration(days: durationDays));

    final String subscriptionType =
        productId == SubscriptionProducts.monthlySubscription
            ? 'monthly'
            : 'annually';

    try {
      await FirebaseFirestore.instance
          .collection('usersAlerts')
          .doc(user.uid)
          .set({
        'subscription': true,
        'paymentId': purchaseDetails.purchaseID,
        'paymentMethod': 'Google Play Billing',
        'amount': amount,
        'currency': 'USD',
        'subscriptionDate': FieldValue.serverTimestamp(),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'subscriptionDuration': subscriptionType,
        'subscriptionType': subscriptionType,
        'productId': productId,
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        'status': 'active',
        'userId': user.uid,
      }, SetOptions(merge: true));

      debugPrint('BillingService: Subscription saved to Firebase');
    } catch (e) {
      debugPrint('BillingService: Error saving subscription: $e');
    }
  }

  /// Restore purchases - tries multiple approaches to detect active subscriptions
  Future<bool> restorePurchases() async {
    try {
      if (Platform.isAndroid) {
        debugPrint('BillingService: === RESTORE PURCHASES START ===');

        // Approach 1: Direct BillingClient query for subscriptions
        bool found = await _querySubscriptionsDirectly();
        if (found) return true;

        // Approach 2: Use platform addition queryPastPurchases
        found = await _queryPastPurchasesFallback();
        if (found) return true;

        // Approach 3: Trigger restorePurchases via purchase stream
        debugPrint('BillingService: Trying restorePurchases via stream...');
        await _inAppPurchase.restorePurchases();
        await Future.delayed(const Duration(seconds: 3));
        return false;
      } else {
        await _inAppPurchase.restorePurchases();
        return true;
      }
    } catch (e) {
      debugPrint('BillingService: Restore error: $e');
      onPurchaseError?.call('Failed to restore purchases: $e');
      return false;
    }
  }

  Future<bool> _querySubscriptionsDirectly() async {
    try {
      debugPrint('BillingService: [Method 1] Direct BillingClient query...');
      final BillingClientManager manager = BillingClientManager();

      final PurchasesResultWrapper subsResult =
          await manager.runWithClient(
        (BillingClient client) => client.queryPurchases(ProductType.subs),
      );

      debugPrint('BillingService: Response: ${subsResult.billingResult.responseCode}');
      debugPrint('BillingService: Debug: ${subsResult.billingResult.debugMessage}');
      debugPrint('BillingService: Subscriptions found: ${subsResult.purchasesList.length}');

      for (final PurchaseWrapper purchase in subsResult.purchasesList) {
        debugPrint('BillingService: Sub - products: ${purchase.products}, '
            'state: ${purchase.purchaseState}, '
            'autoRenew: ${purchase.isAutoRenewing}, '
            'acknowledged: ${purchase.isAcknowledged}');

        final bool hasMatch = purchase.products.any(
          (id) => SubscriptionProducts.allProductIds.contains(id),
        );

        if (hasMatch && purchase.purchaseState == PurchaseStateWrapper.purchased) {
          final details = GooglePlayPurchaseDetails.fromPurchase(purchase);
          for (final detail in details) {
            if (SubscriptionProducts.allProductIds.contains(detail.productID)) {
              await _deliverProduct(detail);
              onPurchaseSuccess?.call('Subscription restored successfully!');
              if (detail.pendingCompletePurchase) {
                await _inAppPurchase.completePurchase(detail);
              }
              manager.dispose();
              return true;
            }
          }
        }
      }

      manager.dispose();
    } catch (e) {
      debugPrint('BillingService: [Method 1] Error: $e');
    }
    return false;
  }

  Future<bool> _queryPastPurchasesFallback() async {
    try {
      debugPrint('BillingService: [Method 2] queryPastPurchases...');
      final InAppPurchaseAndroidPlatformAddition androidAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

      final QueryPurchaseDetailsResponse response =
          await androidAddition.queryPastPurchases();

      if (response.error != null) {
        debugPrint('BillingService: [Method 2] Error: ${response.error!.message}');
      }

      debugPrint('BillingService: [Method 2] Found ${response.pastPurchases.length} purchases');

      for (final PurchaseDetails purchase in response.pastPurchases) {
        debugPrint('BillingService: Purchase - ${purchase.productID}, status: ${purchase.status}');

        if (SubscriptionProducts.allProductIds.contains(purchase.productID)) {
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            final bool valid = await _verifyPurchase(purchase);
            if (valid) {
              await _deliverProduct(purchase);
              onPurchaseSuccess?.call('Subscription restored successfully!');
              if (purchase.pendingCompletePurchase) {
                await _inAppPurchase.completePurchase(purchase);
              }
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('BillingService: [Method 2] Error: $e');
    }
    return false;
  }

  /// Get product details by ID
  ProductDetails? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Get formatted price for a product (base plan price, not offer price)
  String getFormattedPrice(String productId) {
    final product = getProductById(productId);
    if (product != null) {
      if (product is GooglePlayProductDetails) {
        final offers = product.productDetails.subscriptionOfferDetails;
        if (offers != null) {
          for (final offer in offers) {
            if (offer.offerId == null) {
              final phases = offer.pricingPhases;
              if (phases.isNotEmpty) {
                return phases.last.formattedPrice;
              }
            }
          }
        }
      }
      return product.price;
    }
    if (productId == SubscriptionProducts.monthlySubscription) {
      return AppPricing.monthlyPrice;
    } else if (productId == SubscriptionProducts.annualSubscription) {
      return AppPricing.annualPrice;
    }
    return 'N/A';
  }

  void _onPurchaseDone() {
    _subscription?.cancel();
  }

  void _onPurchaseError(dynamic error) {
    debugPrint('BillingService: Stream error: $error');
  }

  /// Apply promo code and validate it
  /// Returns a map with 'success', 'message' or 'error', and offer details
  Future<Map<String, dynamic>> applyPromoCode(String promoCode) async {
    if (!Platform.isAndroid) {
      return {
        'success': false,
        'error': 'Promo codes are only supported on Android',
      };
    }

    if (promoCode.isEmpty) {
      return {
        'success': false,
        'error': 'Please enter a promo code',
      };
    }

    try {
      final customPromoResult = await _validateCustomPromoCode(promoCode);
      return customPromoResult;
    } catch (e) {
      debugPrint('BillingService: Error applying promo code: $e');
      return {
        'success': false,
        'error': 'Failed to validate promo code',
      };
    }
  }

  /// Validate custom promo codes stored in Firebase
  Future<Map<String, dynamic>> _validateCustomPromoCode(String promoCode) async {
    try {
      debugPrint('BillingService: Checking Firebase for promo code: ${promoCode.toUpperCase()}');
      final promoDoc = await FirebaseFirestore.instance
          .collection('promoCodes')
          .doc(promoCode.toUpperCase())
          .get();

      debugPrint('BillingService: Promo doc exists: ${promoDoc.exists}');
      if (!promoDoc.exists) {
        return {'success': false, 'error': 'Invalid promo code'};
      }
      debugPrint('BillingService: Promo doc data: ${promoDoc.data()}');

      final promoData = promoDoc.data()!;

      // Get the offer ID from Firebase promo code (links to Google Play offer)
      final String? googleOfferId = promoData['offerId'] as String?;
      debugPrint('BillingService: Google Offer ID from Firebase: $googleOfferId');

      // Check if promo code is active (support both 'active' and 'isActive' field names)
      final isActive = promoData['active'] == true || promoData['isActive'] == true;
      if (!isActive) {
        debugPrint('BillingService: Promo code is not active');
        return {'success': false, 'error': 'Promo code is no longer active'};
      }

      // Check if promo code has expired
      if (promoData['expiryDate'] != null) {
        final expiryDate = (promoData['expiryDate'] as Timestamp).toDate();
        debugPrint('BillingService: Expiry date: $expiryDate, Now: ${DateTime.now()}');
        if (DateTime.now().isAfter(expiryDate)) {
          debugPrint('BillingService: Promo code has EXPIRED!');
          return {'success': false, 'error': 'Promo code has expired'};
        }
      }

      // Check usage limit
      final usageLimit = promoData['usageLimit'] as int?;
      final usageCount = promoData['usageCount'] as int? ?? 0;
      if (usageLimit != null && usageCount >= usageLimit) {
        return {'success': false, 'error': 'Promo code usage limit reached'};
      }

      // Check if user has already used this code
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final usedBy = promoData['usedBy'] as List<dynamic>? ?? [];
        if (usedBy.contains(user.uid)) {
          return {'success': false, 'error': 'You have already used this promo code'};
        }
      }

      // Promo code is valid - now find the Google Play offer
      _appliedPromoCode = promoCode.toUpperCase();

      String description = 'Promo code applied. Discount will reflect before payment';
      String? offerIdToken;
      String? productId;

      // If there's a Google Play offer ID linked, find it
      if (googleOfferId != null && googleOfferId.isNotEmpty) {
        debugPrint('BillingService: Looking for Google Play offer: $googleOfferId');

        // Query products to find the offer
        final ProductDetailsResponse response =
            await _inAppPurchase.queryProductDetails(SubscriptionProducts.allProductIds);

        for (final product in response.productDetails) {
          if (product is GooglePlayProductDetails) {
            final subscriptionOffers = product.productDetails.subscriptionOfferDetails;

            if (subscriptionOffers != null) {
              for (final offer in subscriptionOffers) {
                if (offer.offerId == googleOfferId) {
                  // Found the matching Google Play offer
                  offerIdToken = offer.offerIdToken;
                  productId = product.id;
                  description = _buildOfferDescription(offer.pricingPhases);
                  debugPrint('BillingService: Found Google Play offer! Token: $offerIdToken');
                  break;
                }
              }
            }
          }
          if (offerIdToken != null) break;
        }

        if (offerIdToken == null) {
          debugPrint('BillingService: Google Play offer not found: $googleOfferId');
        }
      }

      final int discountPercent = promoData['discountPercent'] as int? ?? 0;

      _promoCodeOffer = {
        'type': 'custom',
        'promoCode': promoCode.toUpperCase(),
        'agentId': promoData['agentId'] as String?,
        'googleOfferId': googleOfferId,
        'offerIdToken': offerIdToken,
        'productId': productId,
        'discountPercent': discountPercent,
      };

      return {
        'success': true,
        'message': description,
        'offer': _promoCodeOffer,
        'discountPercent': discountPercent,
      };
    } catch (e) {
      debugPrint('BillingService: Error validating custom promo code: $e');
      return {'success': false, 'error': 'Failed to validate promo code'};
    }
  }

  /// Build offer description from pricing phases
  String _buildOfferDescription(List<PricingPhaseWrapper> pricingPhases) {
    if (pricingPhases.isEmpty) return 'Promo code applied. Discount will reflect before payment';

    List<String> descriptions = [];

    for (final phase in pricingPhases) {
      final price = phase.formattedPrice;
      final period = _formatBillingPeriod(phase.billingPeriod);
      final cycles = phase.billingCycleCount;

      // RecurrenceMode enum values
      if (phase.recurrenceMode == RecurrenceMode.nonRecurring) {
        // Free trial
        descriptions.add('Free trial for $period');
      } else if (phase.recurrenceMode == RecurrenceMode.finiteRecurring && cycles > 0) {
        // Discounted period
        if (price == '\$0.00' || price == '0') {
          descriptions.add('Free for $cycles ${period}s');
        } else {
          descriptions.add('$price/$period for $cycles ${period}s');
        }
      }
    }

    if (descriptions.isEmpty) {
      return 'Promo code applied. Discount will reflect before payment';
    }

    return descriptions.join(' then ');
  }

  /// Format billing period code to readable string
  String _formatBillingPeriod(String period) {
    // ISO 8601 duration format: P1W, P1M, P1Y, etc.
    if (period.contains('W')) return 'week';
    if (period.contains('M')) return 'month';
    if (period.contains('Y')) return 'year';
    if (period.contains('D')) return 'day';
    return period;
  }

  /// Clear applied promo code
  void clearPromoCode() {
    _appliedPromoCode = null;
    _promoCodeOffer = null;
    debugPrint('BillingService: Promo code cleared');
  }

  /// Purchase subscription with promo code applied
  Future<bool> purchaseSubscriptionWithPromo(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('Store not available');
      return false;
    }

    if (!Platform.isAndroid) {
      onPurchaseError?.call('Promo codes are only supported on Android');
      return false;
    }

    try {
      final ProductDetails? productDetails = _products.firstWhere(
        (product) => product.id == productId,
        orElse: () => throw Exception('Product not found: $productId'),
      );

      if (productDetails == null || productDetails is! GooglePlayProductDetails) {
        onPurchaseError?.call('Product not found');
        return false;
      }

      GooglePlayPurchaseParam purchaseParam;

      String? offerToken;
      final String? googleOfferId = _promoCodeOffer?['googleOfferId'] as String?;

      if (_promoCodeOffer != null && googleOfferId != null && googleOfferId.isNotEmpty) {
        final offers = productDetails.productDetails.subscriptionOfferDetails;
        if (offers != null) {
          for (final offer in offers) {
            if (offer.offerId == googleOfferId) {
              offerToken = offer.offerIdToken;
              debugPrint('BillingService: Found offer token for $productId with offerId: $googleOfferId');
              break;
            }
          }
        }
      }

      if (offerToken != null) {
        debugPrint('BillingService: Purchasing $productId with product-specific offer token');
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          offerToken: offerToken,
        );
      } else {
        debugPrint('BillingService: Purchasing $productId without offer token');
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
        );
      }

      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return success;
    } catch (e) {
      debugPrint('BillingService: Purchase with promo error: $e');
      onPurchaseError?.call('Purchase failed: $e');
      return false;
    }
  }

  /// Record promo code usage in Firebase
  Future<void> recordPromoCodeUsage(String promoCode, String productId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final promoRef = FirebaseFirestore.instance
          .collection('promoCodes')
          .doc(promoCode.toUpperCase());

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final promoDoc = await transaction.get(promoRef);

        if (promoDoc.exists) {
          transaction.update(promoRef, {
            'usageCount': FieldValue.increment(1),
            'usedBy': FieldValue.arrayUnion([user.uid]),
            'lastUsedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Also record in user's subscription data
      await FirebaseFirestore.instance
          .collection('usersAlerts')
          .doc(user.uid)
          .update({
        'promoCodeUsed': promoCode.toUpperCase(),
        'promoCodeAppliedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('BillingService: Promo code usage recorded: $promoCode');
    } catch (e) {
      debugPrint('BillingService: Error recording promo code usage: $e');
    }
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
  }
}
