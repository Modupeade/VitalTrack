import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/services/email_service.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/services/signup_service.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_button.dart';
import 'package:vitals_10/widgets/custom_loader.dart';
import 'package:vitals_10/widgets/custom_text.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String userEmail;
  final String userName;

  const EmailVerificationScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool isLoading = false;
  bool isResending = false;
  int resendCooldown = 0;
  DateTime? lastResendTime;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => _showLogoutConfirmation(),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _getUI(context),
          ),
        ),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        20.height,
        Container(
          height: 120,
          width: 120,
          child: Image.asset("assets/icons/justIcon.png"),
        ),
        20.height,
        CustomText(
          text: "Verify Your Email",
          fontSize: 20,
          fontWeight: FontWeight.bold,
          textColor: Colors.black,
        ),
        10.height,
        CustomText(
          text: "We've sent a 4-digit verification code to",
          fontSize: 14,
          fontWeight: FontWeight.normal,
          textAlign: TextAlign.center,
          textColor: Colors.grey,
        ),
        5.height,
        CustomText(
          text: widget.userEmail,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
          textColor: primaryColor,
        ),
        40.height,
        CustomText(
          text: "Enter Verification Code",
          fontSize: 14,
          fontWeight: FontWeight.w500,
          textColor: Colors.black,
        ),
        20.height,
        _buildCodeInputFields(),
        30.height,
        CustomButton(
          hight: 50,
          width: double.infinity,
          radius: 12,
          text: "Verify",
          size: 16,
          textColor: Colors.white,
          fontWeight: FontWeight.bold,
          buttonColor: primaryColor,
          onTap: _verifyCode,
          padding: 0,
        ),
        20.height,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomText(
              text: "Didn't receive the code? ",
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.black,
            ),
            InkWell(
              onTap: (isResending || resendCooldown > 0) ? null : _resendCode,
              child: CustomText(
                text: isResending
                    ? "Sending..."
                    : resendCooldown > 0
                        ? "Resend (${resendCooldown}s)"
                        : "Resend",
                fontSize: 14,
                fontWeight: FontWeight.bold,
                textColor: (isResending || resendCooldown > 0)
                    ? Colors.grey
                    : primaryColor,
              ),
            ),
          ],
        ),
        20.height,
      ],
    );
  }

  Widget _buildCodeInputFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (index) {
        return Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                _focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  String _getEnteredCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _clearCode() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _verifyCode() async {
    final enteredCode = _getEnteredCode();

    if (enteredCode.length != 4) {
      Fluttertoast.showToast(msg: "Please enter the 4-digit code");
      return;
    }

    try {
      setState(() => isLoading = true);

      // Get verification data from pending signup
      final verificationData = await SignupService.getVerificationData(widget.userEmail);

      if (verificationData == null) {
        setState(() => isLoading = false);
        Fluttertoast.showToast(msg: "Verification session not found. Please restart signup.");
        return;
      }

      final storedCode = verificationData['verificationCode'] as String?;
      final codeExpiry = verificationData['codeExpiry'] as int?;

      if (storedCode == null || codeExpiry == null) {
        setState(() => isLoading = false);
        Fluttertoast.showToast(msg: "Verification code not found. Please resend.");
        return;
      }

      // Check if code has expired
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > codeExpiry) {
        setState(() => isLoading = false);
        _clearCode();
        Fluttertoast.showToast(msg: "Code expired. Please request a new code.");
        return;
      }

      // Verify the code
      if (enteredCode == storedCode) {
        // Get pending signup data
        final pendingData = await SignupService.getPendingSignup(widget.userEmail);

        if (pendingData == null) {
          setState(() => isLoading = false);
          Fluttertoast.showToast(msg: "Signup data not found. Please restart signup.");
          return;
        }

        // CODE IS VALID - NOW CREATE FIREBASE ACCOUNT
        final userCredential = await SignupService.createAccountFromPendingSignup(
          widget.userEmail,
          pendingData.password,
        );

        if (userCredential == null) {
          setState(() => isLoading = false);
          Fluttertoast.showToast(msg: "Failed to create account. Please try again.");
          return;
        }

        final uid = userCredential.user!.uid;

        // Delete pending signup document
        await SignupService.completePendingSignup(widget.userEmail);

        setState(() => isLoading = false);

        // Track signup and verification with Facebook Analytics
        await FacebookAnalyticsService.logSignUp(method: 'email');
        await FacebookAnalyticsService.setUserId(uid);
        await FacebookAnalyticsService.logEmailVerification(success: true);

        // Send welcome email
        EmailService.sendWelcomeEmail(
          recipientEmail: widget.userEmail,
          recipientName: widget.userName,
        );

        Fluttertoast.showToast(msg: "Account created successfully!");
        NavigationHelper.navStart(context, const BottomBarScreen());
      } else {
        setState(() => isLoading = false);
        _clearCode();
        Fluttertoast.showToast(msg: "Invalid code. Please try again.");
      }
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      _clearCode();
      if (e.code == 'email-already-in-use') {
        Fluttertoast.showToast(msg: "Email already registered. Please login instead.");
      } else {
        Fluttertoast.showToast(msg: "Error: ${e.message}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _clearCode();
      Fluttertoast.showToast(msg: "Error verifying code: ${e.toString()}");
    }
  }

  Future<void> _resendCode() async {
    // Check cooldown
    if (lastResendTime != null) {
      final timeSinceLastResend = DateTime.now().difference(lastResendTime!);
      if (timeSinceLastResend.inSeconds < 60) {
        final remainingSeconds = 60 - timeSinceLastResend.inSeconds;
        Fluttertoast.showToast(
            msg: "Please wait $remainingSeconds seconds before resending");
        return;
      }
    }

    try {
      setState(() => isResending = true);

      // Verify pending signup exists
      final pendingData = await SignupService.getPendingSignup(widget.userEmail);
      if (pendingData == null) {
        setState(() => isResending = false);
        Fluttertoast.showToast(msg: "Signup session expired. Please restart signup.");
        return;
      }

      // Generate new 4-digit code
      final newCode = SignupService.generateVerificationCode();

      // Update pending signup with new code
      final updated = await SignupService.updateVerificationCode(
        widget.userEmail,
        newCode,
      );

      if (!updated) {
        setState(() => isResending = false);
        Fluttertoast.showToast(msg: "Failed to update verification code. Please try again.");
        return;
      }

      // Send new verification email
      final emailSent = await EmailService.sendVerificationCodeEmail(
        recipientEmail: widget.userEmail,
        recipientName: widget.userName,
        verificationCode: newCode,
      );

      setState(() {
        isResending = false;
        lastResendTime = DateTime.now();
        resendCooldown = 60;
      });

      // Start cooldown timer
      _startCooldownTimer();

      if (emailSent) {
        _clearCode();
        Fluttertoast.showToast(msg: "New verification code sent to your email");
      } else {
        Fluttertoast.showToast(msg: "Failed to send email. Please try again.");
      }
    } catch (e) {
      setState(() => isResending = false);
      Fluttertoast.showToast(msg: "Error resending code: ${e.toString()}");
    }
  }

  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && resendCooldown > 0) {
        setState(() => resendCooldown--);
        return true;
      }
      return false;
    });
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit Verification?"),
        content: const Text(
          "You need to verify your email to create your account. If you go back, your signup progress will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text("Go Back", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
