import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../../widgets/custom_button.dart';
import '../../../../../widgets/custom_loader.dart';
import '../../../../../widgets/custom_text.dart';
import '../../../../../widgets/custom_textfield.dart';

class EditTracker extends StatefulWidget {
  var trackerData;

  EditTracker({super.key, this.trackerData});

  @override
  State<EditTracker> createState() => _EditTrackerState();
}

class _EditTrackerState extends State<EditTracker> {
  TextEditingController _reminderDay = TextEditingController();
  TextEditingController _reminderTime = TextEditingController();
  TextEditingController _reminderType = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _reminderType.text = widget.trackerData["reminderType"];
    _reminderDay.text = widget.trackerData["reminderDay"];
    _reminderTime.text = widget.trackerData["reminderTime"];
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
          iconTheme: IconThemeData(color: Colors.black),
        ),
        body: Form(
            key: _key,
            child: _getUI(context)),
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
              text: "Edit your Tracker\nReminder",
              fontSize: 18,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
          20.height,
          InkWell(
            onTap: () async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) {
                setState(() {
                  _reminderTime.text = "${picked.hour}:${picked.minute}";
                  // selectedDate = picked;
                });
              }
            },
            child: CustomTextField(
                isEnabled: false,
                inputType: TextInputType.number,
                title: "Reminder Time",
                controller: _reminderTime,
                validator: (val) => val.isEmpty ? "Required" : null,
                hint: "12:00"),
          ),
          20.height,
          InkWell(
            onTap: () async {
              _showReminderType(context);
              setState(() {});
            },
            child: CustomTextField(
                isEnabled: false,
                inputType: TextInputType.number,
                title: "Reminder Type",
                controller: _reminderType,
                validator: (val) => val.isEmpty ? "Required" : null,
                hint: "Daily"),
          ),
          20.height,
          _reminderType.text == "Weekly Reminder"
              ? InkWell(
                  onTap: () async {
                    _showReminderDay(context);
                  },
                  child: CustomTextField(
                      isEnabled: false,
                      inputType: TextInputType.number,
                      title: "Reminder Day",
                      controller: _reminderDay,
                      validator: (val) => val.isEmpty ? "Required" : null,
                      hint: ""),
                )
              : SizedBox(),
          20.height,
          CustomButton(
              hight: 45,
              width: double.infinity,
              radius: 30,
              text: "Save",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if(!_key.currentState!.validate()){
                  return;
                }
                _updateTracker();
              },
              padding: 20),
          20.height,
          CustomButton(
              hight: 45,
              width: double.infinity,
              radius: 30,
              text: "Delete",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: Colors.red,
              onTap: () {
                _delete();
              },
              padding: 20)
        ],
      ),
    );
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

  List reminderType = ["Daily Reminder", "Weekly Reminder", "Monthly Reminder"];
  List reminderDay = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  ];

  _delete() async {
    await firebaseFirestore
        .collection("trackers")
        .doc(firebaseAuth.currentUser!.uid)
        .collection("tracker")
        .doc(widget.trackerData["trackerID"])
        .delete()
        .then((value) {
      Fluttertoast.showToast(
          msg: "Tracker Deleted", backgroundColor: Colors.red);
      NavigationHelper.navStart(context, BottomBarScreen());
    });
  }

  _updateTracker() async {
    try {
      loadingTrue();
      await firebaseFirestore
          .collection("trackers")
          .doc(firebaseAuth.currentUser!.uid)
          .collection("tracker")
          .doc(widget.trackerData["trackerID"])
          .set({
        "reminderTime": _reminderTime.text,
        "reminderType": _reminderType.text,
        "reminderDay": _reminderDay.text
      },SetOptions(merge: true)).then((value) {
        Fluttertoast.showToast(msg: "Tracker Saved");
        loadingFalse();
      });
    } on FirebaseException catch (e) {
      loadingFalse();
      Fluttertoast.showToast(msg: e.message!);
    }
  }

  _showReminderType(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, StateSetter setModelState) {
            return ListView.builder(
                itemCount: reminderType.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: InkWell(
                      onTap: () {
                        _reminderType.text = reminderType[i];
                        Navigator.pop(context);
                        setModelState(() {});
                        setState(() {});
                      },
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CustomText(
                              text: reminderType[i],
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              textColor: Colors.black),
                        ),
                      ),
                    ),
                  );
                });
          });
        });
  }

  _showReminderDay(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, StateSetter setModelState) {
            return ListView.builder(
                itemCount: reminderDay.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: InkWell(
                      onTap: () {
                        _reminderDay.text = reminderDay[i];
                        Navigator.pop(context);
                        setModelState(() {});
                      },
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CustomText(
                              text: reminderDay[i],
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              textColor: Colors.black),
                        ),
                      ),
                    ),
                  );
                });
          });
        });
  }
}
