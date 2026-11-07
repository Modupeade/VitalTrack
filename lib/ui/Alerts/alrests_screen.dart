import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pay/pay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../navigation/navigation_helper.dart';
import '../../services/billing_service.dart';
import '../../utils/payment_config.dart';
import '../../utils/currency_formatter.dart';
import 'alerts_pages.dart';

class VitalsAlertsScreen extends StatefulWidget {
  const VitalsAlertsScreen({super.key});

  @override
  State<VitalsAlertsScreen> createState() => _VitalsAlertsScreenState();
}

class _VitalsAlertsScreenState extends State<VitalsAlertsScreen> {
  ApplePayButton? _applePayButton;
  bool _isPaymentProcessing = false;
  bool _isSubscribed = false;
  bool _isLoadingSubscription = true;
  bool _agreeToTerms = false;
  String os = Platform.operatingSystem;
  String _selectedSubscriptionType = 'monthly'; // 'monthly' or 'annually'

  // Google Play Billing
  final BillingService _billingService = BillingService();
  bool _isBillingAvailable = false;

  // Promo Code
  final TextEditingController _promoCodeController = TextEditingController();
  bool _isValidatingPromo = false;
  bool _promoApplied = false;
  String? _promoError;
  String? _promoSuccessMessage;

  // Restore Purchases
  bool _isRestoringPurchases = false;

  @override
  void initState() {
    super.initState();
    _initializePaymentButtons();
    _checkSubscriptionStatus();
    _initializeBilling();
  }

  Future<void> _initializeBilling() async {
    if (Platform.isAndroid) {
      await _billingService.initialize();

      // Set up callbacks
      _billingService.onPurchaseSuccess = (message) async {
        if (mounted) {
          final bool wasRestoring = _isRestoringPurchases;

          // Record promo code usage if one was applied (only for new purchases, not restores)
          if (!wasRestoring && _promoApplied && _billingService.appliedPromoCode != null) {
            final String productId = _selectedSubscriptionType == 'monthly'
                ? SubscriptionProducts.monthlySubscription
                : SubscriptionProducts.annualSubscription;
            await _billingService.recordPromoCodeUsage(
              _billingService.appliedPromoCode!,
              productId,
            );
            _clearPromoCode();
          }

          setState(() {
            _isSubscribed = true;
            _isPaymentProcessing = false;
            _isRestoringPurchases = false;
          });

          // Only pop dialog if this is a new purchase (not a restore)
          if (!wasRestoring && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(wasRestoring ? 'Subscription restored successfully!' : message),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to alerts page
          NavigationHelper.navPush(
            context,
            AlertPager(userId: FirebaseAuth.instance.currentUser!.uid),
          );
        }
      };

      _billingService.onPurchaseError = (error) {
        if (mounted) {
          setState(() {
            _isPaymentProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      _billingService.onPurchasePending = (pending) {
        if (mounted) {
          setState(() {
            _isPaymentProcessing = pending;
          });
        }
      };

      if (mounted) {
        setState(() {
          _isBillingAvailable = _billingService.isAvailable;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoringPurchases) return;

    setState(() {
      _isRestoringPurchases = true;
    });

    try {
      if (Platform.isAndroid) {
        final bool restored = await _billingService.restorePurchases();

        if (restored) {
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          await Future.delayed(const Duration(seconds: 4));
        }

        if (mounted && !_isSubscribed) {
          setState(() {
            _isRestoringPurchases = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active subscription found. Please ensure you are signed in with the Google account that purchased the subscription.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoringPurchases = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoadingSubscription = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('usersAlerts')
          .doc(user.uid)
          .get();

      if (mounted) {
        bool isSubscribed = false;

        if (doc.exists && doc.data()?['subscription'] == true) {
          // Check if subscription has expired
          final data = doc.data();
          if (data != null && data.containsKey('subscriptionEndDate')) {
            Timestamp endDateTimestamp = data['subscriptionEndDate'];
            DateTime endDate = endDateTimestamp.toDate();
            DateTime now = DateTime.now();

            // If subscription end date is in the future, subscription is active
            if (endDate.isAfter(now)) {
              isSubscribed = true;
            } else {
              // Subscription has expired, update Firebase
              await FirebaseFirestore.instance
                  .collection('usersAlerts')
                  .doc(user.uid)
                  .update({
                'subscription': false,
                'status': 'expired',
              });
              isSubscribed = false;
              print('Subscription expired on: $endDate');
            }
          } else {
            // Old subscription without end date, keep it active
            isSubscribed = true;
          }
        }

        setState(() {
          _isSubscribed = isSubscribed;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
      print('Error checking subscription status: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
        });
      }
    }
  }

  void _initializePaymentButtons() {
    // Apple Pay for iOS only
    String amount = _selectedSubscriptionType == 'monthly'
        ? AppPricing.monthlySubscription.toString()
        : AppPricing.annualSubscription.toString();
    String label = _selectedSubscriptionType == 'monthly'
        ? 'Monthly BP Alerts Subscription'
        : 'Annual BP Alerts Subscription';

    _applePayButton = ApplePayButton(
      paymentConfiguration:
          PaymentConfiguration.fromJsonString(defaultApplePay),
      paymentItems: [
        PaymentItem(
          label: label,
          amount: amount,
          status: PaymentItemStatus.final_price,
        )
      ],
      style: ApplePayButtonStyle.black,
      width: double.infinity,
      height: 50,
      type: ApplePayButtonType.buy,
      margin: const EdgeInsets.only(top: 15.0),
      onPaymentResult: _onApplePayResult,
      loadingIndicator: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _onApplePayResult(Map<String, dynamic> result) async {
    print('Apple Pay Result: $result');
    await _handleApplePaySuccess(result, 'Apple Pay',
        subscriptionType: _selectedSubscriptionType);
  }

  Future<void> _handleApplePaySuccess(
      Map<String, dynamic> result, String paymentMethod,
      {String? subscriptionType}) async {
    setState(() {
      _isPaymentProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate a unique payment ID
      final paymentId =
          'PAY_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 8)}';

      // Calculate pricing based on subscription type
      String subType = subscriptionType ?? _selectedSubscriptionType;
      double amount = subType == 'monthly'
          ? AppPricing.monthlySubscription
          : AppPricing.annualSubscription;
      String duration = subType == 'monthly' ? 'monthly' : 'annually';

      // Calculate subscription end date
      DateTime now = DateTime.now();
      DateTime subscriptionEndDate;
      if (subType == 'monthly') {
        // Add 30 days for monthly subscription
        subscriptionEndDate = now.add(const Duration(days: 30));
      } else {
        // Add 365 days for annual subscription
        subscriptionEndDate = now.add(const Duration(days: 365));
      }

      // Update Firebase with subscription details
      await FirebaseFirestore.instance
          .collection('usersAlerts')
          .doc(user.uid)
          .set({
        'subscription': true,
        'paymentId': paymentId,
        'paymentMethod': paymentMethod,
        'amount': amount,
        'currency': 'USD',
        'subscriptionDate': FieldValue.serverTimestamp(),
        'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
        'subscriptionDuration': duration,
        'subscriptionType': subType,
        'paymentResult': result,
        'status': 'active',
        'userId': user.uid,
      }, SetOptions(merge: true));

      if (mounted) {
        // Update subscription status
        setState(() {
          _isSubscribed = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Subscription activated.'),
            backgroundColor: Colors.green,
          ),
        );

        // Close the payment dialog first
        Navigator.of(context).pop();

        // Navigate to alerts page after successful payment
        NavigationHelper.navPush(
          context,
          AlertPager(userId: user.uid),
        );
      }
    } catch (e) {
      print('Payment processing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaymentProcessing = false;
        });
      }
    }
  }

  /// Handle Google Play Billing purchase
  Future<void> _handleGooglePlayPurchase() async {
    setState(() {
      _isPaymentProcessing = true;
    });

    final String productId = _selectedSubscriptionType == 'monthly'
        ? SubscriptionProducts.monthlySubscription
        : SubscriptionProducts.annualSubscription;

    bool success;

    // Auto-apply promo code if entered but not yet applied
    final promoText = _promoCodeController.text.trim();
    if (promoText.isNotEmpty && !_promoApplied) {
      final result = await _billingService.applyPromoCode(promoText);
      if (result['success'] == true) {
        setState(() {
          _promoApplied = true;
          final dp = result['discountPercent'] as int? ?? 0;
          _promoSuccessMessage = dp > 0
              ? 'Promo code applied. $dp% discount will reflect before payment'
              : 'Promo code applied. Discount will reflect before payment';
          _promoError = null;
        });
      }
    }

    // Check if promo code is applied
    if (_promoApplied && _billingService.appliedPromoCode != null) {
      success = await _billingService.purchaseSubscriptionWithPromo(productId);

      // Record promo code usage on successful purchase (handled in callback)
    } else {
      success = await _billingService.purchaseSubscription(productId);
    }

    if (!success && mounted) {
      setState(() {
        _isPaymentProcessing = false;
      });
    }
    // Success/error will be handled by callbacks
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isPaymentProcessing,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF005EA6).withOpacity(0.1),
                  child: const Icon(Icons.payment,
                      color: Color(0xFF005EA6), size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm ${_selectedSubscriptionType == 'monthly' ? 'Monthly' : 'Annual'} Subscription',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _selectedSubscriptionType == 'monthly'
                            ? 'Monthly Subscription'
                            : 'Annual Subscription',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Get on-demand/monthly-email analysis and trends in your blood pressure numbers.",
                        style: TextStyle(color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isPaymentProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : Platform.isIOS
                          ? _applePayButton
                          : _buildGooglePlayButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build Google Play Billing button for Android
  Widget _buildGooglePlayButton() {
    return ElevatedButton(
      onPressed: _isPaymentProcessing ? null : _handleGooglePlayPurchase,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://www.gstatic.com/images/branding/googlelogo/svg/googlelogo_clr_74x24px.svg',
            height: 24,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.play_arrow, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Text(
            'Subscribe with Google Play',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BP Alerts!'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BP Alerts!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'BP Alerts generally refer to notifications generated when a blood pressure reading exceeds a predefined threshold. These alerts are designed to prompt medical consultation.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              const Text(
                'Our Blood Pressure Alert-algorithms automatically analyze your Blood Pressure measurements and they are designed to enable you stay Alert!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 16),
              const Text(
                'If you wish to see or receive Alerts based on your BP measurements, we recommend subscribing for these Alerts!',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: Colors.black),
              ),
              const SizedBox(height: 20),
              // Alert Features List
              _buildAlertFeaturesList(),
              const SizedBox(height: 20),
              if (_isSubscribed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'You are subscribed to BP Alerts!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoadingSubscription)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_isSubscribed)
                Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        NavigationHelper.navPush(
                          context,
                          AlertPager(
                            userId: FirebaseAuth.instance.currentUser!.uid,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: const Color(0xFF005EA6),
                      ),
                      child: const Text(
                        'View Alerts',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    _buildTermsAndPrivacyCheckbox(),
                    const SizedBox(height: 10),
                    // Promo Code Section
                    _buildPromoCodeSection(),
                    const SizedBox(height: 10),
                    // Monthly Subscription Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_agreeToTerms) {
                            setState(() {
                              _selectedSubscriptionType = 'monthly';
                            });
                            _initializePaymentButtons();
                            _showPaymentDialog();
                          } else {
                            Fluttertoast.showToast(
                                msg:
                                    "Accept Terms & condition and read Privacy Policy");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: const Color(0xFF005EA6)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Monthly Subscription',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_billingService.getFormattedPrice(SubscriptionProducts.monthlySubscription)} per month',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Annual Subscription Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_agreeToTerms) {
                            setState(() {
                              _selectedSubscriptionType = 'annually';
                            });
                            _initializePaymentButtons();
                            _showPaymentDialog();
                          } else {
                            Fluttertoast.showToast(
                                msg:
                                    "Accept Terms & condition and read Privacy Policy");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: const Color(0xFF005EA6)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Annual Subscription',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    AppPricing.annualSavingsText,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF005EA6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_billingService.getFormattedPrice(SubscriptionProducts.annualSubscription)} per year',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Restore Purchases Button
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isRestoringPurchases ? null : _restorePurchases,
                      child: _isRestoringPurchases
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF005EA6),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Restoring...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF005EA6),
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Restore Purchases',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF005EA6),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertFeaturesList() {
    final alertFeatures = [
      {
        'icon': Icons.email_outlined,
        'text': 'Email-notifications for Abnormal BP',
      },
      {
        'icon': Icons.bar_chart,
        'text': 'Average BP Alert',
      },
      {
        'icon': Icons.description,
        'text': 'Time-in-Target Range Alert',
      },
      {
        'icon': Icons.check_circle_outline,
        'text': 'Mean Arterial Pressure (MAP) Alert',
      },
      {
        'icon': Icons.trending_up,
        'text': 'Blood Pressure Trend Indicator Alert',
      },
      {
        'icon': Icons.report,
        'text': 'Monthly/On-demand Reports',
      },
    ];

    return Column(
      children: alertFeatures
          .map((feature) => _buildAlertFeatureItem(
                icon: feature['icon'] as IconData,
                text: feature['text'] as String,
              ))
          .toList(),
    );
  }

  Widget _buildAlertFeatureItem(
      {required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF005EA6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
          const Icon(
            Icons.check,
            color: Color(0xFF005EA6),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndPrivacyCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) {
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          activeColor: const Color(0xFF005EA6),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF005EA6),
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      if (!await launchUrl(Uri.parse("http://vitals101.com/terms"))) {
                        throw Exception('Could not launch');
                      }
                    },
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF005EA6),
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      if (!await launchUrl(Uri.parse("https://vitals101.com/privacy"))) {
                        throw Exception('Could not launch');
                      }
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _billingService.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  /// Build Promo Code Input Section
  Widget _buildPromoCodeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a promo code?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  enabled: !_promoApplied && !_isValidatingPromo,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter promo code',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF005EA6)),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _promoApplied || _isValidatingPromo
                      ? null
                      : _applyPromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005EA6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: _isValidatingPromo
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          // Success Message
          if (_promoApplied && _promoSuccessMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _promoSuccessMessage!,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Clear button
                  GestureDetector(
                    onTap: _clearPromoCode,
                    child: Icon(
                      Icons.close,
                      color: Colors.green.shade600,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Error Message
          if (_promoError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _promoError!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Apply promo code
  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _promoError = 'Please enter a promo code';
        _promoSuccessMessage = null;
        _promoApplied = false;
      });
      return;
    }

    setState(() {
      _isValidatingPromo = true;
      _promoError = null;
      _promoSuccessMessage = null;
    });

    try {
      // Validate and apply promo code via BillingService
      final result = await _billingService.applyPromoCode(code);

      if (mounted) {
        setState(() {
          _isValidatingPromo = false;
          if (result['success'] == true) {
            _promoApplied = true;
            final dp = result['discountPercent'] as int? ?? 0;
            _promoSuccessMessage = dp > 0
                ? 'Promo code applied. $dp% discount will reflect before payment'
                : 'Promo code applied. Discount will reflect before payment';
            _promoError = null;
          } else {
            _promoApplied = false;
            _promoError = result['error'] ?? 'Invalid promo code';
            _promoSuccessMessage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidatingPromo = false;
          _promoApplied = false;
          _promoError = 'Failed to validate promo code';
          _promoSuccessMessage = null;
        });
      }
    }
  }

  /// Clear promo code
  void _clearPromoCode() {
    setState(() {
      _promoCodeController.clear();
      _promoApplied = false;
      _promoSuccessMessage = null;
      _promoError = null;
    });
    _billingService.clearPromoCode();
  }
}
