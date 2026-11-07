import 'package:flutter/material.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../../../../utils/constants.dart';
import '../../../../../widgets/custom_button.dart';
import '../../../../../widgets/custom_text.dart';

class AddBloodPressure extends StatefulWidget {
  const AddBloodPressure({super.key});

  @override
  State<AddBloodPressure> createState() => _AddBloodPressureState();
}

class _AddBloodPressureState extends State<AddBloodPressure> {
  TextEditingController _sys = TextEditingController();
  TextEditingController _dia = TextEditingController();

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
            text: "Track your progress",
            fontSize: 16,
            fontWeight: FontWeight.bold,
            textColor: primaryColor),
      ),
      body: _getUI(context),
    );
  }

  Widget _getUI(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText(
              text: "Blood Pressure",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          10.height,
          Row(
            children: [
              CustomText(
                  text: "Time: ",
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  textColor: Colors.black),
              CustomText(
                  text: "${DateTime.now()}",
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  textColor: primaryColor),
            ],
          ),
          10.height,
          Row(
            children: [
              Expanded(
                  child: CustomTextField(
                      title: "Sys (high)",
                      controller: _sys,
                      validator: (val) => val.isEmpty ? "Required" : null,
                      hint: "")),
              20.width,
              Expanded(
                  child: CustomTextField(
                      title: "Dia (low)",
                      controller: _dia,
                      validator: (val) => val.isEmpty ? "Required" : null,
                      hint: "")),
            ],
          ),
          20.height,
          CustomButton(
              hight: 50,
              width: double.infinity,
              radius: 30,
              text: "Track",
              size: 14,
              textColor: Colors.white,
              fontWeight: FontWeight.normal,
              buttonColor: primaryColor,
              onTap: () {},
              padding: 0)
        ],
      ),
    );
  }
}
