import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/reminder_time_selection.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/weekly_day_selectio.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../../widgets/custom_text.dart';

class ReminderDaySelection extends StatefulWidget {
  final String selectedHealth;
  final String selectedHealthID;

  const ReminderDaySelection({super.key,
    required this.selectedHealth,
    required this.selectedHealthID});

  @override
  State<ReminderDaySelection> createState() => _ReminderDaySelectionState();
}

class _ReminderDaySelectionState extends State<ReminderDaySelection> {
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
              text: "Select Reminder",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          5.height,
          CustomText(
              text: "How often do you want\nto be reminded?",
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
          20.height,
          _tile("Daily Reminder", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealth: widget.selectedHealth,
                  selectedDay: "",
                  selectedReminder: "Daily Reminder",
                  selectedHealthID: widget.selectedHealthID
                  ,selectedDate: '${DateTime.now().day}',
                ));
          }),
          _tile("Weekly Reminder", () {
            NavigationHelper.navPush(
                context,
                WeeklyDaySelection(
                    selectedHealth: widget.selectedHealth,
                    day: "Weekly Reminder", selectedHealthID: widget.selectedHealthID

                ));
          }),
          _tile("Monthly Reminder", () {
            NavigationHelper.navPush(
                context,
                ReminderTimeSelection(
                  selectedHealth: widget.selectedHealth,
                  selectedHealthID: widget.selectedHealthID,
                  selectedDay: "",
                  selectedReminder: "Monthly Reminder", selectedDate: '${DateTime.now().day}',
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
