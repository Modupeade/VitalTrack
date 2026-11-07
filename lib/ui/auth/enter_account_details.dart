import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/auth/select_organization.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/custom_text.dart';

class EnterAccountDetails extends StatefulWidget {
  final List selectedAchivement;

  const EnterAccountDetails({super.key, required this.selectedAchivement});

  @override
  State<EnterAccountDetails> createState() => _EnterAccountDetailsState();
}

class _EnterAccountDetailsState extends State<EnterAccountDetails> {
  TextEditingController _email = TextEditingController();
  TextEditingController _name = TextEditingController();
  TextEditingController _password = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();
  bool isVisible = true;
  bool isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
            key: _key, child: SingleChildScrollView(child: _getUI(context))),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            height: 140,
            width: 140,
            child: Image.asset("assets/icons/appicon.jpg"),
          ),
        ),
        CustomText(
            text: "Enter your account Details",
            textAlign: TextAlign.center,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            textColor: Colors.black),
        20.height,
        CustomTextField(
            title: "Name",
            controller: _name,
            validator: (val) => val.isEmpty ? "Required" : null,
            hint: "Enter your name"),
        10.height,
        CustomTextField(
            title: "Email",
            controller: _email,
            validator: (value) {
              if(value.isEmpty){
                return "Required";
              }
              if(!value.contains('@') || !value.contains('.')){
                return 'Invalid Email';
              }

              return null;
            },
            hint: "Enter your email"),
        10.height,
        CustomTextField(
            title: "Password",
            isPassword: true,
            onEyeTapped: () {
              isVisible = !isVisible;
              setState(() {});
            },
            onShow: isVisible,
            controller: _password,
            validator: (val) {
              if (_password.text.trim().isEmpty) {
                return "Required";
              }
              if (_password.text.trim().length <= 5) {
                return "Password must be 6 digits";
              }

              return null;
            },
            hint: "Enter your password"),
        20.height,
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              activeColor: primaryColor,
                value: isAccepted,
                onChanged: (val) {
                isAccepted = val!;
                  setState(() {});
                }),
            Container(
              width: MediaQuery.of(context).size.width * 0.7,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'By proceeding you agree to our ',
                      style: TextStyle(
                          fontWeight: FontWeight.normal, fontSize: 12),
                    ),
                    TextSpan(
                      text: 'Term and Condition ',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          if (!await launchUrl(Uri.parse(
                              "http://vitals101.com/terms"))) {
                            throw Exception('Could not launch');
                          }
                        },
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const TextSpan(
                      text: 'and you have read our ',
                      style: TextStyle(
                          fontWeight: FontWeight.normal, fontSize: 12),
                    ),
                    TextSpan(
                      text: 'Privacy policy',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          if (!await launchUrl(Uri.parse(
                              "https://vitals101.com/privacy"))) {
                            throw Exception('Could not launch');
                          }
                        },
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
        20.height,
        CustomButton(
            hight: 50,
            width: double.infinity,
            radius: 8,
            text: "Submit",
            size: 14,
            textColor: Colors.white,
            fontWeight: FontWeight.normal,
            buttonColor: primaryColor,
            onTap: () {
              if (!_key.currentState!.validate()) {
                return;
              }
              if(isAccepted){
                NavigationHelper.navPush(
                    context,
                    SelectOrganization(
                      selectedAchivement: widget.selectedAchivement,
                      name: _name.text,
                      email: _email.text,
                      password: _password.text,
                    ));
              }else{
                Fluttertoast.showToast(msg: "Accept Terms & condition and read Privacy Policy");
              }
            },
            padding: 0),
        20.height,
      ],
    );
  }
}
