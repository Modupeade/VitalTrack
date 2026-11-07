import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_loader.dart';

import '../../../../../widgets/custom_button.dart';
import '../../../../../widgets/custom_text.dart';
import '../../../../../widgets/custom_textfield.dart';

class OrganizationScreen extends StatefulWidget {
  final String orgName;
  final String orgID;

  const OrganizationScreen(
      {super.key, required this.orgName, required this.orgID});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final TextEditingController _organizationName = TextEditingController();
  final TextEditingController _orgID = TextEditingController();
  final TextEditingController _newMemberShipID = TextEditingController();
  bool updateHMO = false;
  String selectedOrganization = "";
  String selectedOrganizationName = "";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _orgID.text = widget.orgID;
    _organizationName.text = widget.orgName;
    _getOrganization();
  }

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: SingleChildScrollView(child: _getUI(context)),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
              text: "HMO Information",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          CustomTextField(
              isEnabled: false,
              title: "HMO Name",
              controller: _organizationName,
              validator: (val) => null,
              hint: ""),
          10.height,
          CustomTextField(
              isEnabled: false,
              title: "HMO membership no",
              controller: _orgID,
              validator: (val) => null,
              hint: ""),
          20.height,
          20.height,
          CustomButton(
              hight: 50,
              width: double.infinity,
              radius: 30,
              text: "Change HMO",
              size: 15,
              textColor: Colors.white,
              fontWeight: FontWeight.bold,
              buttonColor: primaryColor,
              onTap: () {
                updateHMO = !updateHMO;
                setState(() {});
              },
              padding: 0),
          20.height,
          updateHMO
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText(
                        text: "Select HMO",
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        textColor: Colors.black),
                    Column(
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          child: ListView.builder(
                              itemCount: allOrganization.length,
                              itemBuilder: (context, i) {
                                return InkWell(
                                  onTap: () {
                                    selectedOrganization =
                                        allOrganization[i]["docID"];
                                    selectedOrganizationName =
                                        allOrganization[i]["name"];
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
                                            text: allOrganization[i]["name"],
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            textColor: Colors.black),
                                        selectedOrganization ==
                                                allOrganization[i]["docID"]
                                            ? Icon(
                                                Icons.check,
                                                color: primaryColor,
                                              )
                                            : SizedBox()
                                      ],
                                    ),
                                  ),
                                );
                              }),
                        )
                      ],
                    ),
                    10.height,
                    selectedOrganization != ""
                        ? CustomTextField(
                            title: "HMO membership no",
                            controller: _newMemberShipID,
                            validator: (val) => null,
                            hint: "")
                        : SizedBox(),
                    10.height,
                    CustomButton(
                        hight: 50,
                        width: double.infinity,
                        radius: 30,
                        text: "Update HMO",
                        size: 15,
                        textColor: Colors.white,
                        fontWeight: FontWeight.bold,
                        buttonColor: primaryColor,
                        onTap: () {
                          if (_newMemberShipID.text.isNotEmpty &&
                              selectedOrganization.isNotEmpty &&
                              selectedOrganizationName.isNotEmpty) {
                            _updateHMO();
                          } else {
                            Fluttertoast.showToast(
                                msg: "Select new updated HMO");
                          }
                        },
                        padding: 0),
                    20.height,
                  ],
                )
              : SizedBox()
        ],
      ),
    );
  }

  List<DocumentSnapshot> allOrganization = [];

  _getOrganization() async {
    await firebaseFirestore
        .collection("organizationCollection")
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      snapshot.docs.forEach((element) {
        allOrganization.add(element);
        setState(() {});
      });
    });
  }

  _updateHMO() {
    try {
      loadingTrue();
      firebaseFirestore
          .collection("users")
          .doc(firebaseAuth.currentUser!.uid)
          .set({
        "organizationID": selectedOrganization,
        "organizationName": selectedOrganizationName,
        "memberShipNo": _newMemberShipID.text,
      }, SetOptions(merge: true)).then((value) {
        Fluttertoast.showToast(msg: "Updated");
        NavigationHelper.navStart(context, const BottomBarScreen());
      });
    } on FirebaseException catch (e) {
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
