import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/auth/select_gender_dob.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../widgets/custom_button.dart';
import '../../widgets/custom_text.dart';

class SelectOrganization extends StatefulWidget {
  final List selectedAchivement;
  final String name;
  final String email;
  final String password;

  const SelectOrganization(
      {super.key,
      required this.selectedAchivement,
      required this.name,
      required this.email,
      required this.password});

  @override
  State<SelectOrganization> createState() => _SelectOrganizationState();
}

class _SelectOrganizationState extends State<SelectOrganization> {
  TextEditingController _membership = TextEditingController();
  String selectedOrganization = "no";
  String selectedOrganizationName = "No";
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // _getOrganization();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(child: _getUI(context)),
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
              text: "Do you wish to add your health insurance details?",
              textAlign: TextAlign.center,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          selectedOrganization == "no"? const SizedBox.shrink()  : 20.height,
          selectedOrganization == "no"? const SizedBox.shrink() :CustomTextField(
              title: "Enter your HMO ID card number",
              controller: _membership,
              validator: (val) => val.isEmpty ? "Required" : null,
              hint: "Member ID number"),
          20.height,
          Row(
            children: [
              CustomText(
                  text: "if yes, enter your insurance number",
                  textAlign: TextAlign.center,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  textColor: Colors.black),
            ],
          ),
          20.height,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomText(
                  text: "Select",
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  textColor: Colors.black),
              Container(
                height: 200,
                width: double.infinity,
                child: ListView.builder(
                    itemCount: allOrganization.length,
                    itemBuilder: (context, i) {
                      return InkWell(
                        onTap: () {
                          selectedOrganization =
                              allOrganization[i]["docID"]??'';
                          selectedOrganizationName =
                              allOrganization[i]["name"]??'';
                          if(selectedOrganizationName=='No'){
                            _membership.clear();
                          }
                          setState(() {});
                        },
                        child: Container(
                          height: 50,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.shade200))),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              CustomText(
                                  text: allOrganization[i]["name"]??'',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  textColor: Colors.black),
                              selectedOrganization ==
                                      allOrganization[i]["docID"]
                                  ? Icon(
                                      Icons.check,
                                      color: primaryColor,
                                    )
                                  : const SizedBox()
                            ],
                          ),
                        ),
                      );
                    }),
              ),

              20.height,
            ],
          ),
          // Show Skip as primary when "No" is selected, Submit as primary when "Yes" is selected
          if (selectedOrganizationName == 'No') ...[
            CustomButton(
                hight: 50,
                width: double.infinity,
                radius: 8,
                text: "Skip",
                size: 14,
                textColor: Colors.white,
                fontWeight: FontWeight.normal,
                buttonColor: primaryColor,
                onTap: () {
                  NavigationHelper.navPush(
                      context,
                      SelectGenderDob(
                          selectedAchivement: widget.selectedAchivement,
                          name: widget.name,
                          email: widget.email,
                          password: widget.password,
                          memberNo: "",
                          organizationName: "",
                          organizationID: ""));
                },
                padding: 0),
          ] else ...[
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
                  if (selectedOrganizationName=='Yes' &&
                      _membership.text.trim().isNotEmpty) {
                    NavigationHelper.navPush(
                        context,
                        SelectGenderDob(
                            selectedAchivement: widget.selectedAchivement,
                            name: widget.name,
                            email: widget.email,
                            password: widget.password,
                            memberNo: _membership.text,
                            organizationName: selectedOrganizationName,
                            organizationID: selectedOrganization));
                  } else if (selectedOrganizationName=='Yes' &&
                      _membership.text.trim().isEmpty){
                    Fluttertoast.showToast(
                        msg: "Enter Membership number");
                  }
                },
                padding: 0),
          ],
        ],
      ),
    );
  }

  List<Map<String,String>> allOrganization = [
    {"docID": 'yes','name':'Yes'},{"docID": 'no','name':'No'}];

  // _getOrganization() async {
  //   await firebaseFirestore
  //       .collection("organizationCollection")
  //       .snapshots()
  //       .listen((QuerySnapshot snapshot) {
  //     snapshot.docs.forEach((element) {
  //       allOrganization.add(element);
  //       setState(() {});
  //     });
  //   });
  // }
}
