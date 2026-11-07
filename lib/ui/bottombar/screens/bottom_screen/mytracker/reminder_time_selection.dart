import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/add_tracker_details.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../../widgets/custom_button.dart';
import '../../../../../widgets/custom_text.dart';
import '../../../../../widgets/custom_textfield.dart';

class ReminderTimeSelection extends StatefulWidget {
  final String selectedHealth;
  final String selectedReminder;
  final String? selectedDay;
  final String selectedHealthID;
  final String selectedDate;

  const ReminderTimeSelection(
      {super.key,
      required this.selectedHealth,
      required this.selectedReminder,
      this.selectedDay = "",
      required this.selectedHealthID,
      required this.selectedDate});

  @override
  State<ReminderTimeSelection> createState() => _ReminderTimeSelectionState();
}

class _ReminderTimeSelectionState extends State<ReminderTimeSelection> {
  TextEditingController _starttime = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();

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
      body: Form(key: _key, child: _getUI(context)),
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
              text: "What time do you want to\nbe reminded?",
              fontSize: 14,
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
                  _starttime.text = "${picked.hour}:${picked.minute}";
                  // selectedDate = picked;
                });
              }
            },
            child: CustomTextField(
                isEnabled: false,
                inputType: TextInputType.number,
                title: "Select time",
                controller: _starttime,
                validator: (val) => val.isEmpty ? "Required" : null,
                hint: "12:10 pm"),
          ),
          20.height,
          CustomButton(
              hight: 50,
              width: double.infinity,
              radius: 8,
              text: "Next",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {
                if (!_key.currentState!.validate()) {
                  return;
                }
                NavigationHelper.navPush(
                    context,
                    AddTrackerDetails(
                      selectedHealth: widget.selectedHealth,
                      selectedReminder: widget.selectedReminder,
                      selectedTime: _starttime.text,
                      selectedDay: widget.selectedDay,
                      selectedHealthID: widget.selectedHealthID,
                      selectedDate: widget.selectedDate,
                    ));
              },
              padding: 0),
        ],
      ),
    );
  }
}
