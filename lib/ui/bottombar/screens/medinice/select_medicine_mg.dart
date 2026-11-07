import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/end_medicine_time.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/how_often.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../navigation/navigation_helper.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text.dart';

class SelectMedicineMG extends StatefulWidget {
  final String medicineName;
  final String medicineType;
  final List allMG;

  const SelectMedicineMG(
      {super.key,
      required this.medicineName,
      required this.medicineType,
      required this.allMG});

  @override
  State<SelectMedicineMG> createState() => _SelectMedicineMGState();
}

class _SelectMedicineMGState extends State<SelectMedicineMG> {
  String selectedMG = "";
  String selectMGID = "";
  List<dynamic> allMgs = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    allMgs = widget.allMG;
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            width: 140,
            child: Image.asset("assets/icons/appicon.jpg"),
          ),
          CustomText(
              text: "What form is your\nmedicine?",
              textAlign: TextAlign.start,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: allMgs.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () {
                        selectedMG = allMgs[i];
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
                                text: "${allMgs[i]}",
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                            selectedMG == allMgs[i]
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
          10.height,
          CustomButton(
              hight: 50,
              width: double.infinity,
              radius: 8,
              text: "Next",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if (selectedMG.trim().isNotEmpty) {
                  NavigationHelper.navPush(
                      context,
                      HowOften(
                          medicineName: widget.medicineName,
                          medicineType: widget.medicineType,
                          selectedMG: selectedMG));
                } else {
                  Fluttertoast.showToast(msg: "Select Milligram");
                }
              },
              padding: 0),
          10.height,
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
                selectedMG = "";
                selectMGID = "";
                setState(() {});
                NavigationHelper.navPush(
                    context,
                    HowOften(
                        medicineName: widget.medicineName,
                        medicineType: widget.medicineType,
                        selectedMG: selectedMG));
              },
              padding: 0),
          20.height,
        ],
      ),
    );
  }
}
