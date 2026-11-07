import 'package:age_calculator/age_calculator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_button.dart';
import 'package:vitals_10/widgets/custom_text.dart';

class MedicineNotificationDialog extends StatefulWidget {
  final String medName;
  final String medType;
  final String medID;

  const MedicineNotificationDialog(
      {super.key,
      required this.medName,
      required this.medType,
      required this.medID});

  @override
  State<MedicineNotificationDialog> createState() =>
      _MedicineNotificationDialogState();
}

class _MedicineNotificationDialogState
    extends State<MedicineNotificationDialog> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomText(
                text: "Reminder",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                textColor: Colors.black),
            10.height,
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(500)),
              child: Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: 33,
              ),
            ),
            20.height,
            CustomText(
                text: "Its time to take ${widget.medName}",
                fontSize: 14,
                fontWeight: FontWeight.normal,
                textColor: Colors.black),
            20.height,
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                      hight: 40,
                      width: double.infinity,
                      radius: 30,
                      text: "Taken",
                      size: 14,
                      textColor: Colors.white,
                      fontWeight: FontWeight.normal,
                      buttonColor: primaryColor,
                      onTap: () {
                        onTakenPress(true, widget.medName, widget.medType);
                      },
                      padding: 0),
                ),
                20.width,
                Expanded(
                  child: CustomButton(
                      hight: 40,
                      width: double.infinity,
                      radius: 30,
                      text: "Skipped",
                      size: 14,
                      textColor: Colors.white,
                      fontWeight: FontWeight.normal,
                      buttonColor: Colors.red,
                      onTap: () {
                        onTakenPress(false, widget.medName, widget.medType);
                      },
                      padding: 0),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  onTakenPress(bool isTakeen, String name, String type) async {
    try {
      await firebaseFirestore
          .collection("users")
          .doc(firebaseAuth.currentUser!.uid)
          .snapshots()
          .listen((DocumentSnapshot snapshot) {
        DateTime tempDate =
            new DateFormat("dd/MM/yyyy").parse(snapshot.get("dob"));
        DateDuration duration;
        duration = AgeCalculator.age(tempDate);
        String id = firebaseFirestore.collection("doseTracker").doc().id;
        firebaseFirestore.collection("doseTracker").doc(id).set({
          "id": id,
          "addedTime": DateTime.now().millisecondsSinceEpoch,
          "organizationID": snapshot.get("organizationID"),
          "organizationName": snapshot.get("organizationName"),
          "gender": snapshot.get("gender"),
          "dob": "${duration.years}",
          "name": snapshot.get("name"),
          "email": snapshot.get("email"),
          "disease": snapshot.get("toAchieve"),
          "isTaken": isTakeen,
          "medName": name,
          "medType": type,
        }).then((value) async {
          // Track medicine taken with Facebook Analytics (only if taken, not skipped)
          if (isTakeen) {
            await FacebookAnalyticsService.logMedicineTaken(
              medicineName: name,
            );
          }

          Fluttertoast.showToast(
              msg: isTakeen ? "Medicine Taken" : "Medicine Skipped");
          NavigationHelper.navStart(context, const BottomBarScreen());
        });
      });
    } on FirebaseException catch (e) {
      Fluttertoast.showToast(msg: e.message!);
    }
  }
}
