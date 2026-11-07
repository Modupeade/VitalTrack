import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_button.dart';
import 'package:vitals_10/widgets/custom_text.dart';
import 'package:vitals_10/widgets/custom_textfield.dart';

import '../../../../../widgets/custom_loader.dart';

class TrackerDetails extends StatefulWidget {
  final String trackerID;
  final String name;

  const TrackerDetails(
      {super.key, required this.trackerID, required this.name});

  @override
  State<TrackerDetails> createState() => _TrackerDetailsState();
}

class _TrackerDetailsState extends State<TrackerDetails> {
  bool isDetails = true;
  bool isGraph = false;
  List<_ChartData> chartData = <_ChartData>[];
  List<_AllChartData> allChartData = <_AllChartData>[]; // For second chart with all data
  bool isDay = false;
  bool isWeek = true;
  bool isMonth = false;
  bool isYear = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getTrackerHistory();
    _getDataFromFireStore(7).then((results) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        setState(() {});
      });
    });
    _getAllDataFromFireStore(); // Fetch all data for second chart
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _getUI(context),
    );
  }

  Widget _getUI(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: CustomButton(
                    hight: 50,
                    width: double.infinity,
                    radius: 30,
                    text: "History",
                    size: 14,
                    textColor: isDetails ? Colors.white : Colors.black,
                    fontWeight: isDetails ? FontWeight.bold : FontWeight.normal,
                    buttonColor: isDetails ? primaryColor : Colors.white,
                    onTap: () {
                      isGraph = false;
                      isDetails = true;
                      setState(() {});
                    },
                    padding: 10)),
            Expanded(
                child: CustomButton(
                    hight: 50,
                    width: double.infinity,
                    radius: 30,
                    text: "Graph",
                    size: 14,
                    textColor: isGraph ? Colors.white : Colors.black,
                    fontWeight: isGraph ? FontWeight.bold : FontWeight.normal,
                    buttonColor: isGraph ? primaryColor : Colors.white,
                    onTap: () {
                      isGraph = true;
                      isDetails = false;
                      setState(() {});
                    },
                    padding: 10)),
          ],
        ),
        20.height,
        if (isDetails)
          Expanded(
              child: ListView.builder(
                  itemCount: allHistory.length,
                  itemBuilder: (context, i) {
                    DateTime date = DateTime.fromMillisecondsSinceEpoch(
                        allHistory[i]["addedTime"]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        height: 80,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade200))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                CustomText(
                                    text: "Recorded Value: ",
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    textColor: Colors.black),
                                CustomText(
                                    text:
                                        "${allHistory[i]["value"] == "" ? "Sys:${allHistory[i]["sys"]}, Dia: ${allHistory[i]["dia"]}" : allHistory[i]["value"]}",
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    textColor: Colors.black),
                              ],
                            ),
                            CustomText(
                                text:
                                    '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}',
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                                textColor: Colors.black),
                          ],
                        ),
                      ),
                    );
                  }))
        else
          Expanded(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
            child: Column(
              children: [
                Container(
                  height: 50,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _graphTile("day", isDay, () {
                        isDay = true;
                        isWeek = false;
                        isMonth = false;
                        isYear = false;
                        _getDataFromFireStore(1).then((results) {
                          SchedulerBinding.instance
                              .addPostFrameCallback((timeStamp) {
                            setState(() {});
                          });
                        });
                      }),
                      _graphTile("Week", isWeek, () {
                        isDay = false;
                        isWeek = true;
                        isMonth = false;
                        isYear = false;
                        _getDataFromFireStore(7).then((results) {
                          SchedulerBinding.instance
                              .addPostFrameCallback((timeStamp) {
                            setState(() {});
                          });
                        });
                      }),
                      _graphTile("Month", isMonth, () {
                        isDay = false;
                        isWeek = false;
                        isMonth = true;
                        isYear = false;
                        _getDataFromFireStore(30).then((results) {
                          SchedulerBinding.instance
                              .addPostFrameCallback((timeStamp) {
                            setState(() {});
                          });
                        });
                      }),
                      _graphTile("Year", isYear, () {
                        isDay = false;
                        isWeek = false;
                        isMonth = false;
                        isYear = true;
                        _getDataFromFireStore(360).then((results) {
                          SchedulerBinding.instance
                              .addPostFrameCallback((timeStamp) {
                            setState(() {});
                          });
                        });
                      }),
                    ],
                  ),
                ),
                10.height,
                Container(
                    height: 400,
                    width: double.infinity,
                    child: SfCartesianChart(
                        primaryXAxis: DateTimeAxis(
                          labelRotation: -45,
                          labelStyle: TextStyle(fontSize: 10),
                          interval: isDay ? 2 : (isWeek ? 1 : (isMonth ? 5 : 30)),
                          dateFormat: DateFormat('d MMM'),
                        ),
                        primaryYAxis: NumericAxis(
                          labelStyle: TextStyle(fontSize: 12),
                          interval: widget.name == "Blood Pressure" ? 25 : null,
                          minimum: widget.name == "Blood Pressure" ? 50 : null,
                          maximum: widget.name == "Blood Pressure" ? 225 : null,
                        ),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <CartesianSeries<_ChartData, DateTime>>[
                          LineSeries<_ChartData, DateTime>(
                              name: widget.name == "Blood Pressure" ? "Systolic" : widget.name,
                              dataSource: chartData,
                              xValueMapper: (_ChartData data, _) => data.x,
                              yValueMapper: (_ChartData data, _) => data.y,
                              color: Colors.blue,
                              markerSettings: MarkerSettings(isVisible: true, height: 4, width: 4)),
                          if (widget.name == "Blood Pressure")
                            LineSeries<_ChartData, DateTime>(
                                name: "Diastolic",
                                dataSource: chartData,
                                xValueMapper: (_ChartData data, _) => data.x,
                                yValueMapper: (_ChartData data, _) => data.z,
                                color: Colors.pink,
                                markerSettings: MarkerSettings(isVisible: true, height: 4, width: 4)),
                        ])),
                widget.name == "Blood Pressure"
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 20,
                                width: 20,
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              10.width,
                              CustomText(
                                  text: "Sys",
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  textColor: Colors.black)
                            ],
                          ),
                          10.width,
                          Row(
                            children: [
                              Container(
                                height: 20,
                                width: 20,
                                decoration: BoxDecoration(
                                    color: Colors.pink,
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              10.width,
                              CustomText(
                                  text: "Dia",
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  textColor: Colors.black)
                            ],
                          ),
                        ],
                      )
                    : SizedBox(),
                // Second chart - All data points without dates
                30.height,
                CustomText(
                    text: "All Readings (${allChartData.length} points)",
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    textColor: Colors.black),
                10.height,
                Container(
                    height: 300,
                    width: double.infinity,
                    child: SfCartesianChart(
                        primaryXAxis: NumericAxis(
                          labelStyle: TextStyle(fontSize: 10),
                          title: AxisTitle(text: 'Reading #', textStyle: TextStyle(fontSize: 10)),
                        ),
                        primaryYAxis: NumericAxis(
                          labelStyle: TextStyle(fontSize: 12),
                          interval: widget.name == "Blood Pressure" ? 25 : null,
                          minimum: widget.name == "Blood Pressure" ? 50 : null,
                          maximum: widget.name == "Blood Pressure" ? 225 : null,
                        ),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        series: <CartesianSeries<_AllChartData, int>>[
                          LineSeries<_AllChartData, int>(
                              name: widget.name == "Blood Pressure" ? "Systolic" : widget.name,
                              dataSource: allChartData,
                              xValueMapper: (_AllChartData data, _) => data.index,
                              yValueMapper: (_AllChartData data, _) => data.y,
                              color: Colors.blue,
                              markerSettings: MarkerSettings(isVisible: true, height: 3, width: 3)),
                          if (widget.name == "Blood Pressure")
                            LineSeries<_AllChartData, int>(
                                name: "Diastolic",
                                dataSource: allChartData,
                                xValueMapper: (_AllChartData data, _) => data.index,
                                yValueMapper: (_AllChartData data, _) => data.z,
                                color: Colors.pink,
                                markerSettings: MarkerSettings(isVisible: true, height: 3, width: 3)),
                        ])),
                widget.name == "Blood Pressure"
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 20,
                                width: 20,
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              10.width,
                              CustomText(
                                  text: "Sys",
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  textColor: Colors.black)
                            ],
                          ),
                          10.width,
                          Row(
                            children: [
                              Container(
                                height: 20,
                                width: 20,
                                decoration: BoxDecoration(
                                    color: Colors.pink,
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              10.width,
                              CustomText(
                                  text: "Dia",
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  textColor: Colors.black)
                            ],
                          ),
                        ],
                      )
                    : SizedBox(),
                20.height,
              ],
            ),
          ),
          )
      ],
    );
  }

  List<DocumentSnapshot> allHistory = [];

  _getTrackerHistory() async {
    await firebaseFirestore
        .collection("trackingHistory")
        .where("trackerID", isEqualTo: widget.trackerID)
        .where("uid", isEqualTo: firebaseAuth.currentUser!.uid)
        .orderBy("addedTime", descending: true)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      snapshot.docs.forEach((element) {
        if (element["value"] != "0") {
          allHistory.add(element);
          setState(() {});
        }
      });
    });
  }

  Future<void> _getDataFromFireStore(int days) async {
    DateTime dt1 = DateTime.now();
    DateTime dt2 = dt1.subtract(Duration(days: days));
    print(dt2.millisecondsSinceEpoch);

    var snapShotsValue = await FirebaseFirestore.instance
        .collection("trackingHistory")
        .where("trackerID", isEqualTo: widget.trackerID)
        .where("addedTime", isGreaterThanOrEqualTo: dt2.millisecondsSinceEpoch)
        .where("uid", isEqualTo: firebaseAuth.currentUser!.uid)
        .orderBy("addedTime", descending: false)
        .get();
    List<_ChartData> list = snapShotsValue.docs
        .map((e) => _ChartData(
            x: DateTime.fromMillisecondsSinceEpoch(e.data()['addedTime']),
            y: int.tryParse(e.data()[
                    widget.name == "Blood Pressure" ? 'sys' : 'value']) ??
                0,
            z: int.tryParse(e.data()[
                    widget.name == "Blood Pressure" ? 'dia' : 'value']) ??
                0))
        .toList();
    setState(() {
      chartData = list;
    });
  }

  /// Fetch ALL data points for the second chart (no date filter)
  Future<void> _getAllDataFromFireStore() async {
    var snapShotsValue = await FirebaseFirestore.instance
        .collection("trackingHistory")
        .where("trackerID", isEqualTo: widget.trackerID)
        .where("uid", isEqualTo: firebaseAuth.currentUser!.uid)
        .orderBy("addedTime", descending: false)
        .get();

    List<_AllChartData> list = [];
    int index = 1;
    for (var e in snapShotsValue.docs) {
      list.add(_AllChartData(
          index: index,
          y: int.tryParse(e.data()[
                  widget.name == "Blood Pressure" ? 'sys' : 'value']) ??
              0,
          z: int.tryParse(e.data()[
                  widget.name == "Blood Pressure" ? 'dia' : 'value']) ??
              0));
      index++;
    }
    setState(() {
      allChartData = list;
    });
  }

  _graphTile(String name, bool isSelected, Function onSelect) {
    return InkWell(
      onTap: () => onSelect(),
      child: Container(
        height: 40,
        width: isSelected ? 100 : 50,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: isSelected ? primaryColor : Colors.white),
        child: Center(
            child: CustomText(
                text: name,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                textColor: isSelected ? Colors.white : Colors.black)),
      ),
    );
  }
}

class _ChartData {
  _ChartData({this.x, this.y, this.z});

  final DateTime? x;
  final int? y;
  final int? z;
}

/// Chart data class for all readings (uses index instead of date)
class _AllChartData {
  _AllChartData({required this.index, this.y, this.z});

  final int index;
  final int? y;
  final int? z;
}
