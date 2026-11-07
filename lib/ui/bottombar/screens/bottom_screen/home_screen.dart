import 'dart:math' as math;
import 'dart:math';

import 'package:age_calculator/age_calculator.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/update_tracker.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/edit_medicine/edit_medicine.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../widgets/custom_text.dart';
import '../../../../widgets/side_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();
  bool showFloating = false;
  List<bool> taken = [];
  List<bool> skipped = [];

  @override
  void initState() {
    super.initState();
    AwesomeNotifications().cancelAllSchedules();

    _getLast30Dates();
    _getTrackers();
    _getAllMed();

    // Check and show first-time welcome message
    _checkAndShowWelcomeMessage();

    AwesomeNotifications().isNotificationAllowed().then(
      (isAllowed) {
        if (!isAllowed) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Allow Notifications'),
              content: Text('Our app would like to send you notifications'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Don\'t Allow',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ),
                TextButton(
                  onPressed: () => AwesomeNotifications()
                      .requestPermissionToSendNotifications()
                      .then((_) => Navigator.pop(context)),
                  child: Text(
                    'Allow',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _checkAndShowWelcomeMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('hasSeenWelcomeMessage') ?? false;

    if (!hasSeenWelcome && mounted) {
      // Mark as seen immediately to prevent showing again
      await prefs.setBool('hasSeenWelcomeMessage', true);

      // Show welcome dialog after a short delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Welcome to Vitals101',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xff00b048),
                ),
              ),
              content: const Text(
                'Welcome to Vitals101, your Meds & BP Alerts App. Use the + button below to enter your BP records and go to \u2261Menu to subscribe for BP Alerts! Thank you.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      color: Color(0xff00b048),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      drawer: NavDrawer(),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          showFloating
              ? ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: filteredTrackers.length +
                      2, // +2 for default Blood Pressure and Blood Glucose
                  itemBuilder: (context, index) {
                    Map<String, dynamic> trackerData;
                    bool isDefault = false;

                    if (index == 0) {
                      // Always show Blood Pressure as first item
                      trackerData = defaultBloodPressureTracker;
                      isDefault = true;
                    } else if (index == 1) {
                      // Always show Blood Glucose as second item
                      trackerData = defaultBloodGlucoseTracker;
                      isDefault = true;
                    } else {
                      // Show other trackers
                      trackerData = filteredTrackers[index - 2].data()
                          as Map<String, dynamic>;
                      trackerData["trackerID"] =
                          filteredTrackers[index - 2]["trackerID"];
                    }

                    debugPrint('alert type:\n$trackerData');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            showFloating = false;
                          });
                          NavigationHelper.navPush(
                              context,
                              UpdateTracker(
                                  trackerID: trackerData["trackerID"],
                                  name: trackerData["name"]));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CustomText(
                                text: "Add ${trackerData["name"]} ",
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                textColor: Colors.black),
                            FloatingActionButton(
                              onPressed: () {
                                setState(() {
                                  showFloating = false;
                                });
                                NavigationHelper.navPush(
                                    context,
                                    UpdateTracker(
                                        trackerID: trackerData["trackerID"],
                                        name: trackerData["name"]));
                              },
                              backgroundColor: isDefault
                                  ? const Color(
                                      0xFF005EA6) // Blue color for default
                                  : Color((math.Random().nextDouble() *
                                              0xFFFFFF)
                                          .toInt())
                                      .withOpacity(1.0),
                              child: Image.asset(
                                trackerData["name"] == "Blood Pressure"
                                    ? "assets/icons/bloodPressure.png"
                                    : trackerData["name"] == "Blood Glucose"
                                        ? "assets/icons/glucose.png"
                                        : "assets/icons/weight.png",
                                height: 30,
                                width: 30,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  })
              : const SizedBox.shrink(),
          FloatingActionButton(
            onPressed: () {
              // Always show floating menu since Blood Pressure is always available as default
              showFloating = !showFloating;
              setState(() {});
            },
            backgroundColor: Colors.white,
            child: const Icon(
              Icons.add,
              color: Colors.black,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(child: _getUI(context)),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leadingWidth: 100,
        leading: InkWell(
          onTap: () {
            _key.currentState!.openDrawer();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.menu,
                color: Colors.black,
                size: 32,
              ),
              10.width,
              CustomText(
                  text: "Menu",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  textColor: Colors.black)
            ],
          ),
        ),
      ),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        children: [
          10.height,
          Container(
            height: 100,
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                itemBuilder: (context, i) {
                  DateTime time = days[i];
                  String formattedDate = DateFormat('dd').format(time);
                  String day = DateFormat('EE').format(time);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      height: 60,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: i == 0 ? primaryColor : null,
                        border: Border.all(color: Colors.white, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomText(
                              text: day,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              textColor: i == 0 ? Colors.white : Colors.black),
                          CustomText(
                              text: formattedDate,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              textColor: i == 0 ? Colors.white : Colors.black),
                        ],
                      ),
                    ),
                  );
                }),
          ),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: allMedicines.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Container(
                        // height: 100,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade200))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CustomText(
                                    text:
                                        allMedicines[i]["takeTime"].toString(),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    textColor: Colors.black),
                                IconButton(
                                    onPressed: () {
                                      NavigationHelper.navPush(
                                          context,
                                          EditMedicine(
                                            medData: allMedicines[i],
                                          ));
                                    },
                                    icon: Icon(Icons.edit))
                              ],
                            ),
                            10.height,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                      text: allMedicines[i]["medName"],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      textColor: Colors.black),
                                  10.height,
                                  allMedicines[i]["selectedMG"] == ""
                                      ? SizedBox()
                                      : CustomText(
                                          text:
                                              "Form: ${allMedicines[i]["selectedMG"]}",
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          textColor: Colors.grey.shade800),
                                  10.height,
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CustomText(
                                          text:
                                              "Take: ${allMedicines[i]["pill"]}",
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          textColor: Colors.grey.shade700),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              onTakenPress(
                                                  false,
                                                  allMedicines[i]["medName"],
                                                  allMedicines[i]["medType"],
                                                  i);
                                            },
                                            child: CustomText(
                                                text: "Skip",
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                textColor: skipped[i]
                                                    ? Colors.red
                                                    : Colors.grey),
                                          ),
                                          10.width,
                                          Container(
                                            height: 15,
                                            color: Colors.grey,
                                            width: 1,
                                          ),
                                          10.width,
                                          InkWell(
                                            onTap: () {
                                              onTakenPress(
                                                  true,
                                                  allMedicines[i]["medName"],
                                                  allMedicines[i]["medType"],
                                                  i);
                                            },
                                            child: CustomText(
                                                text: "Taken",
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                textColor: taken[i]
                                                    ? primaryColor
                                                    : Colors.grey),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  }))
        ],
      ),
    );
  }

  List<DateTime> days = [];
  List<DocumentSnapshot> allMedicines = [];

  _getLast30Dates() {
    DateTime start = DateTime.now().add(const Duration(days: 0));
    for (int i = 0; i <= 6; i++) {
      days.add(start.add(Duration(days: i)));
      setState(() {});
    }
  }

  _getAllMed() async {
    firebaseFirestore
        .collection("med")
        .doc(firebaseAuth.currentUser!.uid)
        .collection('medicines')
        // .where("endDate",
        //     isGreaterThanOrEqualTo: DateTime.now().millisecondsSinceEpoch)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      allMedicines.clear();
      snapshot.docs.forEach((element) async {
        if (element["endDate"] >= DateTime.now().millisecondsSinceEpoch ||
            element["endDate"] == 0) {
          taken.add(false);
          skipped.add(false);
          allMedicines.add(element);
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(element.data() as Map? ?? {});
          final takeTimes = List.from(data['takeTime'] ?? []);
          final notificationTimes = List.from(data['notificationTime'] ?? []);
          for (int time = 0; time < takeTimes.length; time++) {
            if (time >= notificationTimes.length) break;
            final item = takeTimes[time].toString();
            final words = item.split(":");
            if (words.length < 2) continue;
            await MedicineNotification(
                notificationTimes[time],
                element["medName"],
                element["medID"],
                element["medType"],
                words[0],
                words[1]);
            if (mounted) setState(() {});
          }

          setState(() {});
        }
      });
    });
  }

  var random =
      Random(); // keep this somewhere in a static variable. Just make sure to initialize only once.

  onTakenPress(bool isTakens, String name, String type, int i) async {
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
          "isTaken": isTakens,
          "medName": name,
          "medType": type,
        }).then((value) {
          if (isTakens) {
            taken[i] = true;
            skipped[i] = false;

            setState(() {});
          } else {
            skipped[i] = true;
            taken[i] = false;

            setState(() {});
          }
          Fluttertoast.showToast(
              msg: isTakens ? "Medicine Taken" : "Medicine Skipped");
        });
      });
    } on FirebaseException catch (e) {
      Fluttertoast.showToast(msg: e.message!);
    }
  }

  List<DocumentSnapshot> allTrackers = [];
  List<DocumentSnapshot> filteredTrackers = [];
  Map<String, dynamic> defaultBloodPressureTracker = {
    "trackerID": "MnkrlMVOS3aDsRXsHF6W",
    "name": "Blood Pressure",
    "reminderType": "Weekly Reminder",
    "notificationID": "999",
    "reminderTime": "13:1",
    "selectedDate": "1",
    "reminderDay": "Monday",
    "isDefault": true,
  };

  Map<String, dynamic> defaultBloodGlucoseTracker = {
    "trackerID": "CjnQVWCMMg3pIvwJX2Ci",
    "name": "Blood Glucose",
    "reminderType": "Daily Reminder",
    "notificationID": "816",
    "reminderTime": "17:56",
    "selectedDate": "11",
    "reminderDay": "",
    "isDefault": true,
  };

  _getTrackers() async {
    firebaseFirestore
        .collection("trackers")
        .doc(firebaseAuth.currentUser!.uid)
        .collection("tracker")
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      allTrackers.clear();
      filteredTrackers.clear();

      snapshot.docs.forEach((element) {
        allTrackers.add(element);

        // Filter out Blood Pressure and Blood Glucose trackers from the list since they're default
        if (element["name"] != "Blood Pressure" &&
            element["name"] != "Blood Glucose") {
          filteredTrackers.add(element);
        }

        List<String> words = element["reminderTime"].split(":");
        trackerNotification(
            "${element["notificationID"]}",
            "${element["trackerID"]}",
            element["name"],
            element["reminderType"],
            words[0],
            words[1],
            element["selectedDate"],
            element["selectedDate"]);

        setState(() {});
      });
    });
  }

  MedicineNotification(int id, String medName, String medID, String medType,
      String reminderHour, String reminderMinute) async {
    await AwesomeNotifications().createNotification(
        schedule: NotificationCalendar(
            hour: int.parse(reminderHour), minute: int.parse(reminderMinute)),
        content: NotificationContent(
            actionType: ActionType.Default,
            id: id,
            channelKey: 'basic_channel',
            title: '$medName Medicine time',
            body: 'It\'s time to take $medName medicine',
            notificationLayout: NotificationLayout.Default,
            payload: {
              "trackerName": medName,
              "medType": medType,
              "medID": medID,
              "notificationType": "Medicine_Notification"
            },
            wakeUpScreen: true),
        actionButtons: [
          NotificationActionButton(key: 'TAKEN_MED', label: 'Take Medicine'),
          NotificationActionButton(key: 'SKIP_MED', label: 'Skip Medicine')
        ]);
  }

  trackerNotification(
      String id,
      String trackerID,
      String trackerName,
      String reminderType,
      String reminderHour,
      String reminderMinute,
      String selectedDay,
      String selectedWeakDay) async {
    await AwesomeNotifications().createNotification(
      schedule: reminderType == "Daily Reminder"
          ? NotificationCalendar(
              hour: int.parse(reminderHour), minute: int.parse(reminderMinute))
          : reminderType == "Monthly Reminder"
              ? NotificationCalendar(
                  day: int.parse(selectedDay),
                  hour: int.parse(reminderHour),
                  minute: int.parse(reminderMinute))
              : NotificationCalendar(
                  weekday: int.parse(selectedWeakDay),
                  hour: int.parse(reminderHour),
                  minute: int.parse(reminderMinute)),
      content: NotificationContent(
          actionType: ActionType.Default,
          id: int.parse(id),
          channelKey: 'basic_channel',
          title: '${trackerName}',
          body: 'Add your new record in ${trackerName}',
          notificationLayout: NotificationLayout.Default,
          payload: {
            "trackerName": trackerName,
            "trackerID": trackerID,
            "notificationType": "Tracker_Notification"
          },
          wakeUpScreen: true),
    );
  }
}
