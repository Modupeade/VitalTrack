import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/end_medicine_time.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/select_medicine_mg.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../../../navigation/navigation_helper.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text.dart';

class AddMedicineNameAndTime extends StatefulWidget {
  final String medicineName;
  final String medicineType;
  final String howOften;
  final int selectedDay;
  final String selectedMG;

  const AddMedicineNameAndTime(
      {super.key,
      required this.medicineName,
      required this.howOften,
      required this.medicineType,
      required this.selectedDay,
      required this.selectedMG});

  @override
  State<AddMedicineNameAndTime> createState() => _AddMedicineNameAndTimeState();
}

class _AddMedicineNameAndTimeState extends State<AddMedicineNameAndTime> {
  TextEditingController _pill = TextEditingController();
  TextEditingController _startDate = TextEditingController();
  GlobalKey<FormState> _key = GlobalKey<FormState>();
  List<TextEditingController> textEditingControllers = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i <= widget.selectedDay - 1; i++) {
      var textEditingController = TextEditingController();
      textEditingControllers.add(textEditingController);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Form(key: _key, child: _getUI(context)),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            width: 140,
            child: Image.asset("assets/icons/appicon.jpg"),
          ),
          CustomText(
              text: "When do you need to take\nthis medicine?",
              textAlign: TextAlign.start,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          CustomTextField(
              inputType: TextInputType.number,
              title: "How many do you take at a time",
              controller: _pill,
              validator: (val) => val.isEmpty ? "Required" : null,
              hint: "e.g: 1"),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: textEditingControllers.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            textEditingControllers[i].text =
                                "${picked.hour}:${picked.minute}";
                          });
                        }
                      },
                      child: CustomTextField(
                          isEnabled: false,
                          inputType: TextInputType.number,
                          title: "Select Time ${i + 1}",
                          controller: textEditingControllers[i],
                          validator: (val) => val.isEmpty ? "Required" : null,
                          hint: "12:10 PM"),
                    );
                  })),
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
                List time = [];
                List notificationID = [];
                for (var item in textEditingControllers) {
                  var rng = new Random();
                  var code = rng.nextInt(900000) + 100000;
                  time.add(item.text);
                  notificationID.add(code);
                }

                NavigationHelper.navPush(
                    context,
                    EndMedicineTime(
                      medicineName: widget.medicineName,
                      howOften: widget.howOften,
                      pillCount: _pill.text,
                      startTime: time,
                      startDate: _startDate.text,
                      medicineType: widget.medicineType,
                      notificationTime: notificationID,
                      selectedMG: widget.selectedMG,
                    ));
              },
              padding: 0),
          20.height,
        ],
      ),
    );
  }
}
