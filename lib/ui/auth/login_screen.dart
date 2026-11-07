import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/auth/email_verification_screen.dart';
import 'package:vitals_10/ui/auth/reset/reset_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_loader.dart';
import 'package:vitals_10/widgets/custom_text.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../navigation/navigation_helper.dart';
import '../../widgets/custom_button.dart';
import '../bottombar/bottom_bar_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController _email = TextEditingController();
  TextEditingController _password = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();
  bool onShow = true;

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Form(
          key: _key,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child:
                SafeArea(child: SingleChildScrollView(child: _getUI(context))),
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
            text: "Hi, Welcome Back! 👋",
            fontSize: 16,
            fontWeight: FontWeight.bold,
            textColor: Colors.black),
        5.height,
        CustomText(
            // text: "Login to your account and Start your\nmedication routine",
            text: "Login to your account and enjoy the\nbest experience",
            fontSize: 14,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.normal,
            textColor: Colors.grey),
        20.height,
        CustomTextField(
            title: "Email",
            controller: _email,
            validator: (val) => val.isEmpty ? "Required" : null,
            hint: "mail@mail.com"),
        10.height,
        CustomTextField(
            title: "Password",
            isPassword: true,
            onShow: onShow,
            onEyeTapped: () {
              onShow = !onShow;
              setState(() {});
            },
            controller: _password,
            validator: (val) => val.isEmpty ? "Required" : null,
            hint: "*****"),
        10.height,
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: (){
              NavigationHelper.navPush(context, ResetScreen());
            },
            child: CustomText(
                text: "Forgot Password?",
                fontSize: 14,
                fontWeight: FontWeight.normal,
                textColor: Colors.red),
          ),
        ),
        30.height,
        CustomButton(
            hight: 50,
            width: double.infinity,
            radius: 12,
            text: "Login",
            size: 16,
            textColor: Colors.white,
            fontWeight: FontWeight.bold,
            buttonColor: primaryColor,
            onTap: () {
              if (!_key.currentState!.validate()) {
                return;
              }
              _loginUser();
            },
            padding: 20),
        20.height,
        InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomText(
                  text: "Don't have an account?",
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  textColor: Colors.black),
              CustomText(
                  text: " Signup",
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  textColor: primaryColor),
            ],
          ),
        )
      ],
    );
  }

  _loginUser() async {
    try {
      loadingTrue();
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: _email.text, password: _password.text)
          .then((value) async {
        // Check verification status
        final uid = value.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;

          // Check if isVerified field exists (new users have it, old users don't)
          // If field doesn't exist, user is from before verification feature - consider verified
          final bool isVerified;
          if (userData.containsKey('isVerified')) {
            isVerified = userData['isVerified'] as bool? ?? true;
          } else {
            // Legacy user created before verification feature
            isVerified = true;
          }

          final userName = userData['name'] as String? ?? 'User';

          // Track successful login with Facebook Analytics
          await FacebookAnalyticsService.logLogin(method: 'email');
          await FacebookAnalyticsService.setUserId(uid);

          loadingFalse();

          if (!isVerified) {
            // Redirect to verification screen
            NavigationHelper.navStart(
              context,
              EmailVerificationScreen(
                userEmail: _email.text,
                userName: userName,
              ),
            );
          } else {
            // User is verified, proceed to app
            NavigationHelper.navStart(context, BottomBarScreen());
          }
        } else {
          loadingFalse();
          NavigationHelper.navStart(context, BottomBarScreen());
        }
      });
    } on FirebaseException catch (e) {
      loadingFalse();
      Fluttertoast.showToast(msg: e.message!);
    }
  }

  bool isLoading = false;

  loadingTrue() {
    isLoading = true;
    setState(() {});
  }

  loadingFalse() {
    isLoading = false;
    setState(() {});
  }
}
