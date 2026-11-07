import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_loader.dart';

import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text.dart';

class EndMedicineTime extends StatefulWidget {
  final String medicineName;
  final String medicineType;
  final String howOften;
  final String pillCount;
  final List startTime;
  final List notificationTime;
  final String startDate;
  final String selectedMG;


  const EndMedicineTime(
      {super.key,
      required this.medicineName,
      required this.howOften,
      required this.pillCount,
      required this.startTime,
      required this.startDate,
      required this.medicineType,
      required this.notificationTime,
      required this.selectedMG,});

  @override
  State<EndMedicineTime> createState() => _EndMedicineTimeState();
}

class _EndMedicineTimeState extends State<EndMedicineTime> {
  List times = [
    "5 days",
    "1 week",
    "10 days",
    "30 days",
    "Ongoing treatment, no end date",
  ];
  String selectedTime = "";
  int selectedTimeMilliSecond = 0;

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: _getUI(context),
      ),
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
              text: "How long is the treatment?",
              textAlign: TextAlign.start,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: times.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () {
                        if (times[i] == "5 days") {
                          DateTime dt1 = DateTime.now();
                          DateTime dt2 = dt1.add(const Duration(days: 5));
                          selectedTime = times[i];
                          selectedTimeMilliSecond = dt2.millisecondsSinceEpoch;
                          setState(() {});
                        } else if (times[i] == "1 week") {
                          DateTime dt1 = DateTime.now();
                          DateTime dt2 = dt1.add(const Duration(days: 7));
                          selectedTime = times[i];
                          selectedTimeMilliSecond = dt2.millisecondsSinceEpoch;
                          setState(() {});
                        } else if (times[i] == "10 days") {
                          DateTime dt1 = DateTime.now();
                          DateTime dt2 = dt1.add(const Duration(days: 10));
                          selectedTime = times[i];
                          selectedTimeMilliSecond = dt2.millisecondsSinceEpoch;
                          setState(() {});
                        } else if (times[i] == "30 days") {
                          DateTime dt1 = DateTime.now();
                          DateTime dt2 = dt1.add(const Duration(days: 30));
                          selectedTime = times[i];
                          selectedTimeMilliSecond = dt2.millisecondsSinceEpoch;
                          setState(() {});
                        } else if (times[i] ==
                            "Ongoing treatment, no end date") {
                          selectedTime = times[i];
                          selectedTimeMilliSecond = 0;
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
                                text: times[i],
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                            selectedTime == times[i]
                                ? Icon(
                                    Icons.check,
                                    color: primaryColor,
                                  )
                                : const SizedBox()
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
              text: "Add Medicine",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if (selectedTime.isNotEmpty) {
                  _addMedicine();
                }
              },
              padding: 0),
          20.height,
        ],
      ),
    );
  }

  var rng = Random();

  _addMedicine() async {
    try {
      loadingTrue();
      String medID = firebaseFirestore.collection("med").doc().id;
      firebaseFirestore
          .collection("med")
          .doc(firebaseAuth.currentUser!.uid)
          .collection("medicines")
          .doc(medID)
          .set({
        "medID": medID,
        "medName": widget.medicineName,
        "medType": widget.medicineType,
        "howOften": widget.howOften,
        "takeTime": widget.startTime,
        "notificationTime": widget.notificationTime,
        "startDate": widget.startDate,
        "pill": widget.pillCount,
        "notificationID": rng.nextInt(9000),
        "selectedMG": widget.selectedMG,
        "endDate": selectedTimeMilliSecond,
      }).then((value) async {
        // Track medicine added with Facebook Analytics
        await FacebookAnalyticsService.logMedicineAdded(
          medicineName: widget.medicineName,
          medicineType: widget.medicineType,
        );

        loadingFalse();
        Fluttertoast.showToast(msg: "Medicine Added");
        NavigationHelper.navStart(context, const BottomBarScreen());
      });
    } on FirebaseException catch (e) {
      loadingFalse();
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
