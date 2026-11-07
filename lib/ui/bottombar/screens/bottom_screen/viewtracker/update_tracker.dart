import 'package:age_calculator/age_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/tracker_details.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../../../../navigation/navigation_helper.dart';
import '../../../../../widgets/custom_button.dart';
import '../../../../../widgets/custom_loader.dart';
import '../../../../../widgets/custom_text.dart';

class UpdateTracker extends StatefulWidget {
  final String trackerID;
  final String name;

  const UpdateTracker({super.key, required this.trackerID, required this.name});

  @override
  State<UpdateTracker> createState() => _UpdateTrackerState();
}

class _UpdateTrackerState extends State<UpdateTracker> {
  TextEditingController _readings = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();
  TextEditingController sys = TextEditingController();
  TextEditingController dia = TextEditingController();
  TextEditingController pulse = TextEditingController();
  bool showRecodedDetails = false;

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
              text: widget.name,
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
          widget.name == "Blood Pressure"
              ? Column(
                  children: [
                    Row(
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
                    ),
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
              text: "Save",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if (!_key.currentState!.validate()) {
                  return;
                }
                _getUserDetails();
              },
              padding: 0),
          20.height,
    /*      showRecodedDetails
              ?*/ CustomButton(
                  hight: 50,
                  width: double.infinity,
                  radius: 8,
                  text: "Previous data",
                  size: 14,
                  textColor: Colors.white,
                  fontWeight: FontWeight.normal,
                  buttonColor: primaryColor,
                  onTap: () {
                    NavigationHelper.navPush(
                        context,
                        TrackerDetails(
                            trackerID: widget.trackerID, name: widget.name));
                  },
                  padding: 0)
              // : SizedBox(),
        ],
      ),
    );
  }

  _getUserDetails() async {
    try {
      loadingTrue();
      await firebaseFirestore
          .collection("users")
          .doc(firebaseAuth.currentUser!.uid)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        DateTime tempDate =
            new DateFormat("dd/MM/yyyy").parse(snapshot.get("dob"));
        DateDuration duration;
        duration = AgeCalculator.age(tempDate);
        String id = firebaseFirestore.collection("trackingHistory").doc().id;
        firebaseFirestore.collection("trackingHistory").doc(id).set({
          "addedTime": DateTime.now().millisecondsSinceEpoch,
          "trackerID": widget.trackerID,
          "trackerName": widget.name,
          "trackingHistoryID": id,
          "uid": firebaseAuth.currentUser!.uid,
          "value": _readings.text,
          "sys": sys.text,
          "dia": dia.text,
          "pulse": pulse.text,
          "organizationID": snapshot.get("organizationID"),
          "organizationName": snapshot.get("organizationName"),
          "gender": snapshot.get("gender"),
          "dob": "${duration.years}",
          "name": snapshot.get("name"),
          "email": snapshot.get("email"),
          "disease": snapshot.get("toAchieve"),
        }).then((value) async {
          // Track measurement with Facebook Analytics
          if (widget.name == "Blood Pressure") {
            await FacebookAnalyticsService.logBPMeasurementAdded(
              systolic: sys.text.isNotEmpty ? int.tryParse(sys.text) : null,
              diastolic: dia.text.isNotEmpty ? int.tryParse(dia.text) : null,
              pulse: pulse.text.isNotEmpty ? int.tryParse(pulse.text) : null,
            );
          } else if (widget.name == "Weight") {
            await FacebookAnalyticsService.logWeightMeasurementAdded(
              weight: double.tryParse(_readings.text) ?? 0,
              unit: 'kg',
            );
          } else if (widget.name == "Blood Sugar" || widget.name == "Glucose") {
            await FacebookAnalyticsService.logBloodSugarMeasurementAdded(
              glucose: double.tryParse(_readings.text) ?? 0,
              unit: 'mg/dL',
            );
          }

          _readings.clear();
          dia.clear();
          sys.clear();
          pulse.clear();
          Fluttertoast.showToast(msg: "Well done Measurement recorded");
          showRecodedDetails = true;
          loadingFalse();
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
