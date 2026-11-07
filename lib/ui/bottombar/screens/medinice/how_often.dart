import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/add_medicine_name_time.dart';
import 'package:vitals_10/utils/constants.dart';

import '../../../../widgets/custom_button.dart';
import '../../../../widgets/custom_text.dart';

class HowOften extends StatefulWidget {
  final String medicineName;
  final String medicineType;
  final String selectedMG;

  const HowOften(
      {super.key,
      required this.medicineName,
      required this.medicineType,
      required this.selectedMG});

  @override
  State<HowOften> createState() => _HowOftenState();
}

class _HowOftenState extends State<HowOften> {
  List<dynamic> howOften = [
    {"name": "Once a day", "day": "${1}"},
    {"name": "Twice a day", "day": "${2}"},
    {"name": "3 times a day", "day": "${3}"},
    {"name": "4 times a day", "day": "${4}"},
    {"name": "More than 4 times a day", "day": "${5}"},
  ];
  String selectedhowOften = "";
  int selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: _getUI(context),
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
              text: "How often do you take this\nMedicine?",
              textAlign: TextAlign.start,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          Expanded(
              child: ListView.builder(
                  itemCount: howOften.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () {
                        selectedhowOften = howOften[i]["name"];
                        selectedDay = int.parse(howOften[i]["day"]);
                        setState(() {});
                      },
                      child: Container(
                        height: 55,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade200))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CustomText(
                                text: howOften[i]["name"],
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                            selectedhowOften == howOften[i]["name"]
                                ? Icon(
                                    Icons.check,
                                    color: primaryColor,
                                  )
                                : SizedBox()
                          ],
                        ),
                      ),
                    );
                  })),
          10.height,
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
                if (selectedhowOften.trim().isNotEmpty) {
                  NavigationHelper.navPush(
                      context,
                      AddMedicineNameAndTime(
                        medicineName: widget.medicineName,
                        howOften: selectedhowOften,
                        medicineType: widget.medicineType,
                        selectedDay: selectedDay,
                        selectedMG: widget.selectedMG,
                      ));
                } else {
                  Fluttertoast.showToast(msg: "Select time");
                }
              },
              padding: 0),
          20.height,
        ],
      ),
    );
  }
}
