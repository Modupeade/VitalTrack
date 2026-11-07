import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_app_badger/flutter_app_badger.dart'; // Discontinued package
import 'package:url_launcher/url_launcher.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/auth/login_screen.dart';
import 'package:vitals_10/ui/auth/select_achivement.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_button.dart';
import 'package:vitals_10/widgets/custom_text.dart';

class GetStarted extends StatefulWidget {
  const GetStarted({super.key});

  @override
  State<GetStarted> createState() => _GetStartedState();
}

class _GetStartedState extends State<GetStarted> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: _getUI(context),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: Container(
            height: 140,
            width: 140,
            child: Image.asset("assets/icons/appicon.jpg"),
          ),
        ),
        CustomText(
            text: "Your digital healthcare companion",
            textAlign: TextAlign.center,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            textColor: Colors.black),
        10.height,
        // CustomText(
        //     text: "Your digital healthcare companion",
        //     textAlign: TextAlign.center,
        //     fontSize: 14,
        //     fontWeight: FontWeight.normal,
        //     textColor: Colors.grey),
        // 30.height,
        // Features List
        _buildFeaturesList(),
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
              NavigationHelper.navPush(context, LoginScreen());
            },
            padding: 0),
        20.height,
        CustomButton(
            hight: 50,
            width: double.infinity,
            radius: 12,
            text: "Get Started",
            size: 14,
            textColor: primaryColor,
            fontWeight: FontWeight.normal,
            buttonColor: Colors.white,
            onTap: () {
              // FlutterAppBadger.updateBadgeCount(0);
              // FlutterAppBadger.removeBadge();
              NavigationHelper.navPush(context, SelectAchivement());
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
      ],
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': Icons.email_outlined,
        'text': 'Email-notifications for Abnormal BP',
      },
      {
        'icon': Icons.bar_chart,
        'text': 'Automated Blood Pressure Alerts (ABP, TTR, MAP and BPTI)',
      },
      {
        'icon': Icons.description,
        'text': 'Monthly/On-demand Reports',
      },
      {
        'icon': Icons.medication,
        'text': 'Medication Reminders',
      },
      {
        'icon': Icons.headset_mic,
        'text': 'Virtual Consultation with Specialist Doctors',
      },
      {
        'icon': Icons.block,
        'text': 'No Ads',
      },
      
    ];

    return Column(
      children: features
          .map((feature) => _buildFeatureItem(
                icon: feature['icon'] as IconData,
                text: feature['text'] as String,
              ))
          .toList(),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomText(
              text: text,
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.black,
            ),
          ),
          Icon(
            Icons.check,
            color: primaryColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}
