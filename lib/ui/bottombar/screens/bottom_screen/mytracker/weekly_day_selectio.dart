import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/reminder_time_selection.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../../widgets/custom_text.dart';

class WeeklyDaySelection extends StatefulWidget {
  final String selectedHealth;
  final String day;
  final String selectedHealthID;

  const WeeklyDaySelection(
      {super.key,
      required this.selectedHealth,
      required this.day,
      required this.selectedHealthID});

  @override
  State<WeeklyDaySelection> createState() => _WeeklyDaySelectionState();
}

class _WeeklyDaySelectionState extends State<WeeklyDaySelection> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
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
              text: "Set Reminder",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          5.height,
          CustomText(
              text: "Which day do you want\nto be reminded?",
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
          20.height,
          _tile("Sunday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Sunday",
                  selectedReminder: widget.day,selectedDate: '7',
                ));
          }),
          _tile("Monday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Monday",
                  selectedReminder: widget.day,selectedDate: '1'
                ));
          }),
          _tile("Tuesday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Tuesday",
                  selectedReminder: widget.day,selectedDate: '2'
                ));
          }),
          _tile("Wednesday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Wednesday",
                  selectedReminder: widget.day,selectedDate: '3'
                ));
          }),
          _tile("Thursday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Thursday",
                  selectedReminder: widget.day,selectedDate: '4'
                ));
          }),
          _tile("Friday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Friday",
                  selectedReminder: widget.day,selectedDate: '5'
                ));
          }),
          _tile("Saturday", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealthID: widget.selectedHealthID,
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "Saturday",
                  selectedReminder: widget.day,selectedDate: '6'
                ));
          }),
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
}
