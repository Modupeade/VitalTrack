import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/services/email_service.dart';
import 'package:vitals_10/services/signup_service.dart';
import 'package:vitals_10/ui/auth/email_verification_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_loader.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/custom_text.dart';

class SelectGenderDob extends StatefulWidget {
  final List selectedAchivement;
  final String name;
  final String email;
  final String password;
  final String memberNo;
  final String organizationName;
  final String organizationID;

  const SelectGenderDob(
      {super.key,
        required this.selectedAchivement,
        required this.name,
        required this.email,
        required this.password,
        required this.memberNo,
        required this.organizationName,
        required this.organizationID});

  @override
  State<SelectGenderDob> createState() => _SelectGenderDobState();
}

class _SelectGenderDobState extends State<SelectGenderDob> {
  TextEditingController _dob = TextEditingController();
  List gender = ["Male", "Female"];
  String selectedGender = "";
  DateTime selectedDate = DateTime(2003);
  String selectedDodTimeStamp = "";

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: _getUI(context),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Center(
            child: Container(
              height: 140,
              width: 140,
              child: Image.asset("assets/icons/appicon.jpg"),
            ),
          ),
          CustomText(
              text: "Select your Gender &\nDate of birth",
              textAlign: TextAlign.center,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now());
              if (picked != null && picked != selectedDate) {
                setState(() {
                  _dob.text = "${picked.day}/${picked.month}/${picked.year}";
                  selectedDodTimeStamp = "${picked.millisecondsSinceEpoch}";
                  selectedDate = picked;
                });
              }
            },
            child: CustomTextField(
                title: "Select Date of birth",
                controller: _dob,
                isEnabled: false,
                validator: (val) => val.isEmpty ? "Required" : null,
                hint: "10/10/2023"),
          ),
          20.height,
          Align(
              alignment: Alignment.centerLeft,
              child: CustomText(
                  text: "Select Gender",
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  textColor: Colors.black)),
          Expanded(
              child: ListView.builder(
                  itemCount: gender.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () {
                        selectedGender = gender[i];
                        setState(() {});
                      },
                      child: Container(
                        height: 55,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border(
                                bottom:
                                BorderSide(color: Colors.grey.shade200))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CustomText(
                                text: gender[i],
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                            selectedGender == gender[i]
                                ? Icon(
                              Icons.check,
                              color: primaryColor,
                            )
                                : SizedBox()
                          ],
                        ),
                      ),
                    );
                  })),
          20.height,
          CustomButton(
              hight: 50,
              width: double.infinity,
              radius: 8,
              text: "Send Verification Code",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if (_dob.text.trim().isNotEmpty && selectedGender.isNotEmpty) {
                  _sendVerificationCode();
                } else {
                  Fluttertoast.showToast(msg: "select Date of birth or Gender");
                }
              },
              padding: 0),
          20.height,
        ],
      ),
    );
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

  _sendVerificationCode() async {
    try {
      loadingTrue();

      // Generate 4-digit verification code
      final verificationCode = SignupService.generateVerificationCode();

      // Create signup data object
      final signupData = SignupData(
        email: widget.email,
        password: widget.password,
        name: widget.name,
        selectedAchievement: List<String>.from(widget.selectedAchivement),
        gender: selectedGender,
        dob: _dob.text,
        dobTimeStamp: int.parse(selectedDodTimeStamp),
        organizationID: widget.organizationID,
        organizationName: widget.organizationName,
      );

      // Store pending signup in Firestore
      final stored = await SignupService.storePendingSignup(
        signupData,
        verificationCode,
      );

      if (!stored) {
        throw Exception('Failed to store signup data');
      }

      // Send verification code email
      final emailSent = await EmailService.sendVerificationCodeEmail(
        recipientEmail: widget.email,
        recipientName: widget.name,
        verificationCode: verificationCode,
      );

      loadingFalse();

      if (emailSent) {
        Fluttertoast.showToast(msg: "Verification code sent to your email");
        NavigationHelper.navPush(
          context,
          EmailVerificationScreen(
            userEmail: widget.email,
            userName: widget.name,
          ),
        );
      } else {
        Fluttertoast.showToast(msg: "Failed to send verification email. Please try again.");
      }
    } on FirebaseException catch (e) {
      loadingFalse();
      Fluttertoast.showToast(msg: e.message!);
    } catch (e) {
      loadingFalse();
      Fluttertoast.showToast(msg: "An error occurred. Please try again.");
    }
  }
}
