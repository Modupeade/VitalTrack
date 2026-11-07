import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/reminder_day_selection.dart';

import '../../../../../utils/constants.dart';
import '../../../../../widgets/custom_text.dart';

class SelectHealthTracker extends StatefulWidget {
  const SelectHealthTracker({super.key});

  @override
  State<SelectHealthTracker> createState() => _SelectHealthTrackerState();
}

class _SelectHealthTrackerState extends State<SelectHealthTracker> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAllTracker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _getUI(context),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
              textAlign: TextAlign.start,
              text: "What Vitals would you\nlike to track?",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          5.height,
          CustomText(
              text: "Select what you want to track",
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: allTracker.length,
                  itemBuilder: (context, i) {
                    return _tile(allTracker[i]["trackerName"], () {
                      NavigationHelper.navPush(
                          context,
                           ReminderDaySelection(
                            selectedHealth: allTracker[i]["trackerName"],
                            selectedHealthID: allTracker[i]["trackerID"],
                          ));
                    });
                  })),
        ],
      ),
    );
  }

  Widget _tile(String title, Function onTap) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Align(
            alignment: Alignment.centerLeft,
            child: CustomText(
                text: title,
                fontSize: 14,
                fontWeight: FontWeight.normal,
                textColor: Colors.black)),
      ),
    );
  }

  List<DocumentSnapshot> allTracker = [];

  _getAllTracker() {
    firebaseFirestore
        .collection("allTracker")
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      snapshot.docs.forEach((element) {
        allTracker.add(element);
        setState(() {});
      });
    });
  }
}
