import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tab_indicator_styler/tab_indicator_styler.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/updates/news_details.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/widgets/custom_image_container.dart';
import 'package:vitals_10/widgets/custom_text.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getArticle();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: CustomText(
              text: "News",
              fontSize: 16,
              fontWeight: FontWeight.bold,
              textColor: primaryColor),
          bottom: TabBar(
            labelStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            isScrollable: true,
            indicatorColor: primaryColor,
            tabs: const [
              Tab(
                text: "All Article",
              ),
              Tab(
                text: "For me",
              )
            ],
            labelColor: Colors.black,
            indicator: MaterialIndicator(
              height: 5,
              topLeftRadius: 8,
              topRightRadius: 8,
              horizontalPadding: 0,
              tabPosition: TabPosition.bottom,
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _tab1(context),
            _tab2(context),
          ],
        ),
      ),
    );
  }

  Widget _tab1(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: ListView.builder(
          itemCount: allArticle.length,
          itemBuilder: (context, i) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
              child: PhysicalModel(
                borderRadius: BorderRadius.circular(0),
                color: Colors.white,
                elevation: 4.0,
                shadowColor: Colors.grey.shade200,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      allArticle[i]["fileType"] == "IMAGE"
                          ? CustomImageContainer(
                              height: 200,
                              wight: double.infinity,
                              radius: 12,
                              image: allArticle[i]["file"])
                          : Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () {
                                  NavigationHelper.navPush(
                                      context,
                                      NewsDetails(
                                        newsData: allArticle[i],
                                      ));
                                },
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                      10.height,
                      CustomText(
                        text: allArticle[i]["title"],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        textColor: Colors.black,
                        overflow: TextOverflow.ellipsis,
                      ),
                      10.height,
                      Container(
                        height: 50,
                        width: double.infinity,
                        child: CustomText(
                            text: allArticle[i]["description"],
                            fontSize: 14,
                            overflow: TextOverflow.fade,
                            fontWeight: FontWeight.normal,
                            textColor: Colors.black),
                      ),
                      10.height,
                      Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () {
                              NavigationHelper.navPush(
                                  context,
                                  NewsDetails(
                                    newsData: allArticle[i],
                                  ));
                            },
                            child: CustomText(
                                text: "Read More",
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                textColor: primaryColor),
                          ))
                    ],
                  ),
                ),
              ),
            );
          }),
    );
  }

  Widget _tab2(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: ListView.builder(
          itemCount: userArticle.length,
          itemBuilder: (context, i) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
              child: PhysicalModel(
                borderRadius: BorderRadius.circular(0),
                color: Colors.white,
                elevation: 4.0,
                shadowColor: Colors.grey.shade200,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      userArticle[i]["fileType"] == "IMAGE"
                          ? CustomImageContainer(
                              height: 200,
                              wight: double.infinity,
                              radius: 12,
                              image: userArticle[i]["file"])
                          : Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () {
                                  NavigationHelper.navPush(
                                      context,
                                      NewsDetails(
                                        newsData: userArticle[i],
                                      ));
                                },
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                      10.height,
                      CustomText(
                        text: userArticle[i]["title"],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        textColor: Colors.black,
                        overflow: TextOverflow.ellipsis,
                      ),
                      10.height,
                      Container(
                        height: 50,
                        width: double.infinity,
                        child: CustomText(
                            text: userArticle[i]["description"],
                            fontSize: 14,
                            overflow: TextOverflow.fade,
                            fontWeight: FontWeight.normal,
                            textColor: Colors.black),
                      ),
                      10.height,
                      Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () {
                              NavigationHelper.navPush(
                                  context,
                                  NewsDetails(
                                    newsData: userArticle[i],
                                  ));
                            },
                            child: CustomText(
                                text: "Read More",
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                textColor: primaryColor),
                          ))
                    ],
                  ),
                ),
              ),
            );
          }),
    );
  }

  List<DocumentSnapshot> allArticle = [];
  List<DocumentSnapshot> userArticle = [];

  _getArticle() async {
    await firebaseFirestore
        .collection("articleCollection")
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      allArticle.clear();
      snapshot.docs.forEach((element) {
        if (element["patientID"] == "") {
          allArticle.add(element);
          setState(() {});
        } else {
          if (element["patientID"] == firebaseAuth.currentUser!.uid) {
            userArticle.add(element);
            setState(() {});
          }
        }
      });
    });
  }
}
