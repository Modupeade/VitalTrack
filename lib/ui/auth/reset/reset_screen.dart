import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_loader.dart';
import '../../../widgets/custom_text.dart';
import '../../../widgets/custom_textfield.dart';

class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key});

  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  TextEditingController _email = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        body: SingleChildScrollView(child: _getUI(context)),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomText(
              text: "Password Reset",
              fontSize: 22,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          10.height,
          CustomText(
              text:
                  "Enter your email address and we'll send you instruction on how to reset your password",
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.grey),
          20.height,
          CustomTextField(
              title: "Email",
              controller: _email,
              validator: (val) => val.isEmpty ? "Required" : null,
              hint: "name@gmail.com"),
          40.height,
          CustomButton(
              hight: 50,
              width: double.infinity,
              radius: 30,
              text: "Reset Password",
              size: 15,
              textColor: Colors.white,
              fontWeight: FontWeight.w500,
              buttonColor: primaryColor,
              onTap: () async {
                resetPassword(_email.text);
              },
              padding: 0)
        ],
      ),
    );
  }

  resetPassword(String email) async {
    try {
      loadingTrue();
      await firebaseAuth.sendPasswordResetEmail(email: email).then((value) {
        Fluttertoast.showToast(msg: "Email Sent");
        _email.clear();
        loadingFalse();
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
