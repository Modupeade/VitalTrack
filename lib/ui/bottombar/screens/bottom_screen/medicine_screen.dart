import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/widgets/custom_button.dart';

import '../../../../navigation/navigation_helper.dart';
import '../../../../utils/constants.dart';
import '../../../../widgets/custom_text.dart';
import '../medinice/add_medicine_name.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getAllMed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: CustomText(
            text: "Active Medicines",
            fontSize: 14,
            fontWeight: FontWeight.normal,
            textColor: Colors.black),
        centerTitle: true,
      ),
      body: allMedicines.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  10.height,
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
                                        bottom: BorderSide(
                                            color: Colors.grey.shade200))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomText(
                                        text: allMedicines[i]["takeTime"]
                                            .toString(),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        textColor: Colors.black),
                                    10.height,
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      width: MediaQuery.of(context).size.width,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.white),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CustomText(
                                              text: allMedicines[i]["medName"],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              textColor: Colors.black),
                                          10.height,
                                          CustomText(
                                              text:
                                                  "Take: ${allMedicines[i]["pill"]} pills",
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                              textColor: Colors.grey.shade700),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          })),
                  10.height,
                  CustomButton(
                      hight: 45,
                      width: double.infinity,
                      radius: 8,
                      text: "Add Medicine",
                      size: 14,
                      textColor: Colors.white,
                      fontWeight: FontWeight.normal,
                      buttonColor: primaryColor,
                      onTap: () {
                        NavigationHelper.navPush(context, AddMedicineNAme());
                      },
                      padding: 0),
                  10.height,
                ],
              ),
            )
          : Center(
              child: CustomButton(
                  hight: 50,
                  width: double.infinity,
                  radius: 30,
                  text: "Add Medicine",
                  size: 14,
                  textColor: Colors.white,
                  fontWeight: FontWeight.normal,
                  buttonColor: primaryColor,
                  onTap: () {
                    NavigationHelper.navPush(context, AddMedicineNAme());
                  },
                  padding: 20),
            ),
    );
  }

  List<DocumentSnapshot> allMedicines = [];

  _getAllMed() async {
    firebaseFirestore
        .collection("med")
        .doc(firebaseAuth.currentUser!.uid)
        .collection('medicines')
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      snapshot.docs.forEach((element) {
        if (element["endDate"] >= DateTime.now().millisecondsSinceEpoch ||
            element["endDate"] == 0) {
          allMedicines.add(element);
          setState(() {});
        }
      });
    });
  }
}
