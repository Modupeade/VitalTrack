import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/add_blood_pressure.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/add_tracker_details.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/edit_tracker.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/tracker_details.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/update_tracker.dart';
import 'package:vitals_10/widgets/custom_button.dart';

import '../../../../../utils/constants.dart';
import '../../../../../widgets/custom_text.dart';
import '../mytracker/select_health_tracker.dart';

class MyTrackerScreen extends StatefulWidget {
  const MyTrackerScreen({super.key});

  @override
  State<MyTrackerScreen> createState() => _MyTrackerScreenState();
}

class _MyTrackerScreenState extends State<MyTrackerScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getTrackers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: CustomText(
            text: "My Vitals Tracker",
            fontSize: 16,
            fontWeight: FontWeight.bold,
            textColor: primaryColor),
      ),
      body: allTrackers.isNotEmpty
          ? _getUI(context)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CustomText(
                      text: "No Tracker Available",
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      textColor: Colors.black),
                  10.height,
                  CustomText(
                      text: "Kindly add your tracker from the\n☰ Menu",
                      fontSize: 14,
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.normal,
                      textColor: Colors.black),
                ],
              ),
            ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
                itemCount: allTrackers.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 10),
                    child: PhysicalModel(
                      borderRadius: BorderRadius.circular(0),
                      color: Colors.white,
                      elevation: 4.0,
                      shadowColor: Colors.grey.shade200,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10),
                        width: MediaQuery.of(context).size.width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CustomText(
                                    text: allTrackers[i]["name"],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    textColor: Colors.black),
                                IconButton(
                                    onPressed: () {
                                      NavigationHelper.navPush(
                                          context,
                                          EditTracker(
                                              trackerData: allTrackers[i]));
                                    },
                                    icon: Icon(Icons.edit))
                              ],
                            ),
                            10.height,
                            CustomText(
                                text:
                                    "${allTrackers[i]["reminderType"]} at ${allTrackers[i]["reminderDay"]} ${allTrackers[i]["reminderTime"]}",
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.grey),
                            20.height,
                            Row(
                              children: [
                                Expanded(
                                    child: CustomButton(
                                        hight: 45,
                                        width: double.infinity,
                                        radius: 30,
                                        text: "View Details",
                                        size: 14,
                                        textColor: primaryColor,
                                        fontWeight: FontWeight.normal,
                                        buttonColor: Colors.grey.shade100,
                                        onTap: () {
                                          NavigationHelper.navPush(
                                              context,
                                              TrackerDetails(
                                                  trackerID: allTrackers[i]
                                                      ["trackerID"],
                                                  name: allTrackers[i]
                                                      ["name"]));
                                        },
                                        padding: 0)),
                                20.width,
                                Expanded(
                                    child: CustomButton(
                                        hight: 45,
                                        width: double.infinity,
                                        radius: 30,
                                        text: "Track",
                                        size: 14,
                                        textColor: Colors.white,
                                        fontWeight: FontWeight.normal,
                                        buttonColor: primaryColor,
                                        onTap: () {
                                          NavigationHelper.navPush(
                                              context,
                                              UpdateTracker(
                                                  trackerID: allTrackers[i]
                                                      ["trackerID"],
                                                  name: allTrackers[i]
                                                      ["name"]));
                                          // scheduleNotification();
                                        },
                                        padding: 0)),
                              ],
                            ),
                            20.height,
                          ],
                        ),
                      ),
                    ),
                  );
                }),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal:16,vertical: 10),
            child: CustomButton(
                hight: 50,
                width: double.infinity,
                radius: 30,
                text: "Add Vitals Tracker",
                size: 15,
                textColor: Colors.white,
                fontWeight: FontWeight.bold,
                buttonColor: primaryColor,
                onTap: () {
                  NavigationHelper.navPush(context, const SelectHealthTracker());
                },
                padding: 0),
          ),
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 10),
          //   child: OutlinedButton(
          //     style: ButtonStyle(
          //       shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          //         RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(4),
          //         ),
          //       ),
          //     ),
          //     onPressed:(){
          //
          //       NavigationHelper.navPush(
          //           context, const SelectHealthTracker());
          //     },
          //     child: const Text("Add Vital Tracker",
          //         style: TextStyle(
          //             color: Colors.black, fontWeight: FontWeight.w900)),
          //   ),
          // ),
        ],
      ),
    );
  }

  List<DocumentSnapshot> allTrackers = [];

  _getTrackers() async {
    firebaseFirestore
        .collection("trackers")
        .doc(firebaseAuth.currentUser!.uid)
        .collection("tracker")
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      allTrackers.clear();
      snapshot.docs.forEach((element) {
        allTrackers.add(element);
        setState(() {});
      });
    });
  }
}
