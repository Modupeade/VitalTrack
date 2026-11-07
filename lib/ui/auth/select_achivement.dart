import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/auth/enter_account_details.dart';
import 'package:vitals_10/ui/auth/select_organization.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/custom_text.dart';

class SelectAchivement extends StatefulWidget {
  const SelectAchivement({super.key});

  @override
  State<SelectAchivement> createState() => _SelectAchivementState();
}

class _SelectAchivementState extends State<SelectAchivement> {
  List alldata = [
    "Blood Pressure Control",
    "Blood Sugar Control",
    "Get Medication Reminders",
    "Virtual Consultations with specialists",
    "Tracking my Vital Readings",
    "Lifestyle education",
    "Detect rising blood pressure"
  ];
  List selectedAchivement = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _getUI(context),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
              text: "What do you hope to\nachieve ?",
              textAlign: TextAlign.center,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: alldata.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () {
                        if (selectedAchivement.contains(alldata[i])) {
                          selectedAchivement.remove(alldata[i]);
                          setState(() {});
                        }else{
                          selectedAchivement.add(alldata[i]);
                          setState(() {});
                        }

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
                                text: alldata[i],
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                            selectedAchivement.contains(alldata[i])
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
              text: "Proceed",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if (selectedAchivement != "") {
                  NavigationHelper.navPush(
                      context,
                      EnterAccountDetails(
                        selectedAchivement: selectedAchivement,
                      ));
                }
              },
              padding: 0),
          20.height,
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'By proceeding, you agree to our ',
                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
                ),
                TextSpan(
                  text: 'Term and Condition ',
                  
                  recognizer: TapGestureRecognizer()..onTap = ()async {
                    if (!await launchUrl(Uri.parse(
                        "http://vitals101.com/terms"))) {
                      throw Exception('Could not launch');
                    }
                  },
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
         decoration: TextDecoration.underline, 
         decorationColor: Colors.black,
    decorationThickness: 1.5,       
                  ),
                ),
                TextSpan(
                  text: 'and you have read our ',
                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12
                  , decoration: TextDecoration.underline,
                  decorationColor: Colors.black,
    decorationThickness: 1.5,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          20.height,

        ],
      ),
    );
  }
}
