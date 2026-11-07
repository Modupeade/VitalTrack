import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_text.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TextEditingController _name = TextEditingController();
  TextEditingController _email = TextEditingController();
  TextEditingController _vitalsNo = TextEditingController();
  TextEditingController _gender = TextEditingController();
  TextEditingController _birthDate = TextEditingController();
  String orgID = "";
  String orgName = "";

  @override
  void initState() {
    super.initState();
    _getUserDetails();
    // Track profile view with Facebook Analytics
    FacebookAnalyticsService.logProfileView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _getUI(context),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
              text: "Profile Information",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          CustomTextField(
              isEnabled: false,
              title: "Name",
              controller: _name,
              validator: (val) => null,
              hint: "name"),
          10.height,
          CustomTextField(
              isEnabled: false,
              title: "Email",
              controller: _email,
              validator: (val) => null,
              hint: "name"),
          20.height,
          CustomTextField(
              isEnabled: false,
              title: "Vitals No",
              controller: _vitalsNo,
              validator: (val) => null,
              hint: "name"),
          20.height,
          CustomTextField(
              isEnabled: false,
              title: "Gender",
              controller: _gender,
              validator: (val) => null,
              hint: "name"),
          20.height,
          CustomTextField(
              isEnabled: false,
              title: "Birth Date",
              controller: _birthDate,
              validator: (val) => null,
              hint: "name"),
          20.height,
        ],
      ),
    );
  }

  _getUserDetails() async {
    print(firebaseAuth.currentUser!.uid);
    await firebaseFirestore
        .collection("users")
        .doc(firebaseAuth.currentUser!.uid)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      print(snapshot.data());
      _name.text = snapshot.get("name");
      _email.text = snapshot.get("email");
      _vitalsNo.text = "${snapshot.get("userID")}";
      _gender.text = snapshot.get("gender");
      _birthDate.text = snapshot.get("dob");
      orgID = snapshot.get("organizationID");
      orgName = snapshot.get("organizationName");
      setState(() {});
    });
  }
}
