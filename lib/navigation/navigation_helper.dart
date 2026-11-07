import 'package:flutter/material.dart';

class NavigationHelper {
  static navPush(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  static navReplace(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => screen));
  }

  static navStart(BuildContext context, Widget screen) {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => screen),
        ModalRoute.withName("/Home"));
  }
}