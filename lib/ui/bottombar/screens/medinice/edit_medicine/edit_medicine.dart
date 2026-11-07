import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/bottom_bar_screen.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_button.dart';
import 'package:vitals_10/widgets/custom_loader.dart';
import 'package:vitals_10/widgets/custom_text.dart';

import '../../../../../widgets/custom_textfield.dart';

class EditMedicine extends StatefulWidget {
  var medData;

  EditMedicine({super.key, this.medData});

  @override
  State<EditMedicine> createState() => _EditMedicineState();
}

class _EditMedicineState extends State<EditMedicine> {
  TextEditingController _pill = TextEditingController();
  TextEditingController _howOften = TextEditingController();
  List howOften = [
    {"name": "Once a day", "day": "${1}"},
    {"name": "Twice a day", "day": "${2}"},
    {"name": "3 times a day", "day": "${3}"},
    {"name": "4 times a day", "day": "${4}"},
    {"name": "More than 4 times a day", "day": "${5}"},
  ];
  List<TextEditingController> textEditingControllers = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _pill.text = widget.medData["pill"];
    for (var item in widget.medData["takeTime"]) {
      var textEditingController = TextEditingController(text: item);
      textEditingControllers.add(textEditingController);
      setState(() {});
    }
    _howOften.text = widget.medData["howOften"];
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
        body: _getUI(context),
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
              text: "Edit your ${widget.medData["medName"]}\nReminder",
              fontSize: 18,
              fontWeight: FontWeight.normal,
              textColor: Colors.black),
          20.height,
          CustomTextField(
              inputType: TextInputType.number,
              title: "Take pill count",
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
          InkWell(
            onTap: () async {
              _showPopUp(context);
            },
            child: CustomTextField(
                isEnabled: false,
                inputType: TextInputType.number,
                title: "How Often do you take this medicine",
                controller: _howOften,
                validator: (val) => val.isEmpty ? "Required" : null,
                hint: ""),
          ),
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
                _updateMedicine();
              },
              padding: 20),
          10.height,
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
                _deleteMedicine();
              },
              padding: 20),
        ],
      ),
    );
  }

  _showPopUp(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, StateSetter setModelState) {
            return ListView.builder(
                itemCount: howOften.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: InkWell(
                      onTap: () {
                        int day = int.parse(howOften[i]['day']);
                        _howOften.text = howOften[i]['name'];
                        textEditingControllers.clear();
                        for (int i = 0; i <= day - 1; i++) {
                          var textEditingController = TextEditingController();
                          textEditingControllers.add(textEditingController);
                        }
                        setState(() {});
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
                              text: howOften[i]['name'],
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

  _updateMedicine() {
    try {
      loadingTrue();
      List time = [];
      for (var item in textEditingControllers) {
        time.add(item.text);
      }
      firebaseFirestore
          .collection("med")
          .doc(firebaseAuth.currentUser!.uid)
          .collection("medicines")
          .doc(widget.medData["medID"])
          .set({
        "howOften": _howOften.text,
        "takeTime": time,
        "pill": _pill.text,
      }, SetOptions(merge: true)).then((value) {
        NavigationHelper.navStart(context, BottomBarScreen());
      });
    } on FirebaseException catch (e) {
      loadingFalse();
      Fluttertoast.showToast(msg: e.message!);
    }
  }

  _deleteMedicine() async {
    await firebaseFirestore
        .collection("med")
        .doc(firebaseAuth.currentUser!.uid)
        .collection("medicines")
        .doc(widget.medData["medID"])
        .delete()
        .then((value) {
      Fluttertoast.showToast(
          msg: "Medicine Deleted", backgroundColor: Colors.red);
      NavigationHelper.navStart(context, BottomBarScreen());
    });
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
}
