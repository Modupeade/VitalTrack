import 'dart:math';

import 'package:age_calculator/age_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_loader.dart';
import 'package:vitals_10/widgets/custom_text.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../../../../navigation/navigation_helper.dart';
import '../../../../../widgets/custom_button.dart';

class AddTrackerDetails extends StatefulWidget {
  final String selectedHealth;
  final String selectedReminder;
  final String? selectedDay;
  final String selectedTime;
  final String selectedHealthID;
  final String selectedDate;

  const AddTrackerDetails(
      {super.key,
      required this.selectedHealth,
      required this.selectedReminder,
      this.selectedDay,
      required this.selectedTime,
      required this.selectedHealthID,
      required this.selectedDate});

  @override
  State<AddTrackerDetails> createState() => _AddTrackerDetailsState();
}

class _AddTrackerDetailsState extends State<AddTrackerDetails> {
  TextEditingController _readings = TextEditingController();
  TextEditingController sys = TextEditingController();
  TextEditingController dia = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return CustomLoader(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.black),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: Form(key: _key, child: _getUI(context)),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          10.height,
          CustomText(
              textAlign: TextAlign.start,
              text: widget.selectedHealth,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          5.height,
          Row(
            children: [
              CustomText(
                  text: "Time: ",
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  textColor: Colors.black),
              CustomText(
                  text:
                      "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  textColor: primaryColor)
            ],
          ),
          20.height,
          widget.selectedHealth == "Blood Pressure"
              ? Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                          title: "Systolic (Top number)",
                          controller: sys,
                          inputType: TextInputType.number,
                          validator: (val) => val.isEmpty ? "Required" : null,
                          hint: "e.g. 120"),
                    ),
                    20.width,
                    Expanded(
                      child: CustomTextField(
                          title: "Diastolic (Bottom number)",
                          controller: dia,
                          inputType: TextInputType.number,
                          validator: (val) => val.isEmpty ? "Required" : null,
                          hint: "e.g. 80"),
                    )
                  ],
                )
              : CustomTextField(
                  title: "Enter your Readings",
                  controller: _readings,
                  inputType: TextInputType.number,
                  validator: (val) => val.isEmpty ? "Required" : null,
                  hint: "e.g. 95"),
          20.height,
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
                if (!_key.currentState!.validate()) {
                  return;
                }
                _uploadTracker(_readings.text);
              },
              padding: 0),
          20.height,
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
                _uploadTracker("0");
              },
              padding: 0),
        ],
      ),
    );
  }

  var rng = Random();

  _uploadTracker(String record) async {
    try {
      loadingTrue();
      await firebaseFirestore
          .collection("users")
          .doc(firebaseAuth.currentUser!.uid)
          .snapshots()
          .listen((DocumentSnapshot snapshot) async {
        await firebaseFirestore
            .collection("trackers")
            .doc(firebaseAuth.currentUser!.uid)
            .collection("tracker")
            .doc(widget.selectedHealthID)
            .set({
          "trackerID": widget.selectedHealthID,
          "name": widget.selectedHealth,
          "reminderTime": widget.selectedTime,
          "reminderType": widget.selectedReminder,
          "uid": firebaseAuth.currentUser!.uid,
          "notificationID": rng.nextInt(1000),
          "selectedDate": widget.selectedDate,
          "reminderDay": widget.selectedDay
        }).then((value) async {
          // Track health tracker creation with Facebook Analytics
          await FacebookAnalyticsService.logHealthTrackerAdded(
            trackerType: widget.selectedHealth,
          );

          // Only create tracking history record if user actually entered data (not skipped)
          if (record != "0" && (sys.text.isNotEmpty || dia.text.isNotEmpty)) {
            String trackingHistoryID =
                firebaseFirestore.collection("trackingHistory").doc().id;
            DateTime tempDate =
                DateFormat("dd/MM/yyyy").parse(snapshot.get("dob"));
            DateDuration duration;
            duration = AgeCalculator.age(tempDate);
            await firebaseFirestore
                .collection("trackingHistory")
                .doc(trackingHistoryID)
                .set({
              "uid": firebaseAuth.currentUser!.uid,
              "trackerID": widget.selectedHealthID,
              "trackerName": widget.selectedHealth,
              "value": record,
              "sys": sys.text,
              "dia": dia.text,
              "trackingHistoryID": trackingHistoryID,
              "addedTime": DateTime.now().millisecondsSinceEpoch,
              "organizationID": snapshot.get("organizationID"),
              "organizationName": snapshot.get("organizationName"),
              "gender": snapshot.get("gender"),
              "dob": "${duration.years}",
              "name": snapshot.get("name"),
              "email": snapshot.get("email"),
              "disease": snapshot.get("toAchieve"),
            }).then((value) async {
              // Track initial measurement with Facebook Analytics
              if (widget.selectedHealth == "Blood Pressure") {
                await FacebookAnalyticsService.logBPMeasurementAdded(
                  systolic: sys.text.isNotEmpty ? int.tryParse(sys.text) : null,
                  diastolic: dia.text.isNotEmpty ? int.tryParse(dia.text) : null,
                );
              } else if (widget.selectedHealth == "Weight") {
                await FacebookAnalyticsService.logWeightMeasurementAdded(
                  weight: double.tryParse(record) ?? 0,
                  unit: 'kg',
                );
              } else if (widget.selectedHealth == "Blood Sugar" || widget.selectedHealth == "Glucose") {
                await FacebookAnalyticsService.logBloodSugarMeasurementAdded(
                  glucose: double.tryParse(record) ?? 0,
                  unit: 'mg/dL',
                );
              }

              loadingFalse();
              Fluttertoast.showToast(msg: "Tracker Added");
              NavigationHelper.navStart(context, BottomBarScreen());
            });
          } else {
            // User skipped, just show success message without creating tracking history
            loadingFalse();
            Fluttertoast.showToast(msg: "Tracker Added");
            NavigationHelper.navStart(context, BottomBarScreen());
          }
        });
      });
    } on FirebaseException catch (e) {
      Fluttertoast.showToast(msg: e.message!);
      loadingFalse();
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
