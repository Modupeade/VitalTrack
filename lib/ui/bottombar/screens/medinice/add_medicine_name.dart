import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/how_often.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/select_medicine_mg.dart';
import 'package:vitals_10/utils/constants.dart';
import '../../../../widgets/custom_text.dart';

class AddMedicineNAme extends StatefulWidget {
  const AddMedicineNAme({super.key});

  @override
  State<AddMedicineNAme> createState() => _AddMedicineNAmeState();
}

class _AddMedicineNAmeState extends State<AddMedicineNAme> {
  List<DocumentSnapshot> allMed = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getMedicine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
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
              text: "Select your medicine",
              textAlign: TextAlign.start,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: Colors.black),
          20.height,
          Container(
              height: 50,
              child: CupertinoSearchTextField(
                backgroundColor: Colors.grey.shade100,
                placeholder: "Search or type medicine name",
                onChanged: (val) {
                  filterList.clear();
                  _filter(val);
                },
              )),
          Expanded(
              child: ListView.builder(
                  itemCount: filterList.length,
                  itemBuilder: (context, i) {
                    return InkWell(
                      onTap: () {
                        NavigationHelper.navPush(
                            context,
                            SelectMedicineMG(
                              medicineName: filterList[i]["medName"],
                              medicineType: filterList[i]["medType"],
                              allMG: filterList[i]["mg"],
                            ));
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
                                text: filterList[i]["medName"],
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                          ],
                        ),
                      ),
                    );
                  })),
          20.height,
        ],
      ),
    );
  }

  List filterList = [];

  _filter(String name) {
    filterList.clear();
    for (var item in allMed) {
      var title = item['medName'].toString().toLowerCase();
      if (title.toLowerCase().toString().contains(name.toString())) {
        filterList.add(item);
        setState(() {});
      }
    }
  }

  _getMedicine() async {
    firebaseFirestore
        .collection("AllMedicine")
        .snapshots()
        .listen((QuerySnapshot snapshot) {
          allMed.clear();
      snapshot.docs.forEach((element) {
        allMed.add(element);
        setState(() {});
      });
    });
  }
}
