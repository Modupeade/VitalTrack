import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/auth/email_verification_screen.dart';
import 'package:vitals_10/ui/auth/get_started_screen.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer(Duration(seconds: 2), () {
      _checkUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          height: 140,
          width: 140,
          child: Image.asset("assets/icons/appicon.jpg"),
        ),
      ),
    );
  }

  _checkUser() async {
    User? user = firebaseAuth.currentUser;
    if (user != null) {
      try {
        // Try cached data first so the app opens instantly when offline.
        // Fall back to a server fetch (with a 5-second cap) when no cache exists.
        DocumentSnapshot<Map<String, dynamic>> userDoc;
        try {
          userDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get(const GetOptions(source: Source.cache));
        } catch (_) {
          userDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 5));
        }

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final bool isVerified;
          if (userData.containsKey('isVerified')) {
            isVerified = userData['isVerified'] as bool? ?? true;
          } else {
            isVerified = true;
          }

          if (!isVerified) {
            final userName  = userData['name']  as String? ?? 'User';
            final userEmail = userData['email'] as String? ?? user.email ?? '';
            NavigationHelper.navStart(
              context,
              EmailVerificationScreen(userEmail: userEmail, userName: userName),
            );
          } else {
            NavigationHelper.navStart(context, BottomBarScreen());
          }
        } else {
          NavigationHelper.navStart(context, BottomBarScreen());
        }
      } catch (e) {
        // Offline and no cache — open the app anyway.
        print('Error checking verification status: $e');
        NavigationHelper.navStart(context, BottomBarScreen());
      }
    } else {
      NavigationHelper.navStart(context, GetStarted());
    }
  }
}
