import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Color primaryColor = const Color(0xff017745);

FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
FirebaseAuth firebaseAuth = FirebaseAuth.instance;

extension padding on num {
  SizedBox get height => SizedBox(height: toDouble());

  SizedBox get width => SizedBox(width: toDouble());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

String STRIPE_SECRET =
   
String STRIPE_PUBLISHABLE =
    "pk_test_51SQQDt2EyoPbYQj1WAQnGc1HiRX7tY1Qcl4JEJPZPJInKlZkr9b591kyaIZIm7diWo7DZAh2gr1HmvYgfOIIIwzW00hgLyf7Dk";
