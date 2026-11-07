import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/auth/get_started_screen.dart';
import 'package:vitals_10/ui/auth/login_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/mytracker/select_health_tracker.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/profile/profile_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/my_tracker_screen.dart';
import 'package:vitals_10/ui/devices/bluetooth_scan_screen.dart';
import 'package:vitals_10/ui/devices/dashboard/home_dashboard_screen.dart';
import 'package:vitals_10/ui/devices/device_detail_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/medinice/add_medicine_name.dart';
import 'package:vitals_10/utils/constants.dart';
import '../ui/Alerts/alrests_screen.dart';
import 'custom_text.dart';
import 'package:vitals_10/ui/Consultation/consultation_info_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class NavDrawer extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              10.height,
              const Icon(
                Icons.person,
                size: 60,
              ),
              40.height,
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(context, const ProfileScreen());
                  },
                  child: _listTile("Profile", Icons.person)),
              20.height,
              InkWell(
                  onTap: () {
                    Navigator.of(context).pop();

                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: CustomText(
                                text: "Support",
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                textColor: Colors.black),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomText(
                                    text:
                                        "To contact customer support, you can send a WhatsApp message to +447982330474 or send email to support@vitals101.com.\nThank you.",
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    textColor: Colors.black)
                              ],
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () async {
                                  await Clipboard.setData(const ClipboardData(
                                          text: "+447982330474"))
                                      .then((value) {
                                    Navigator.pop(context);
                                    Fluttertoast.showToast(
                                        msg: "Number Copied");
                                  });
                                },
                                child: CustomText(
                                    text: "Copy",
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    textColor: primaryColor),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: CustomText(
                                    text: "Cancel",
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    textColor: Colors.black),
                              ),
                            ],
                          );
                        });
                  },
                  child: _listTile("Support", Icons.call)),
              20.height,
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(context, const AddMedicineNAme());
                  },
                  child: _listTile("Add Medicine", Icons.medication)),
              20.height,
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(
                        context, const VitalsAlertsScreen());
                  },
                  child: _listTile("BP Alerts!", Icons.sd_card_alert_sharp)),
              20.height,
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(
                        context, const ConsultationInfoScreen());
                  },
                  child: _listTile("Request Consultation", Icons.request_page)),
              20.height,
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(
                        context, const SelectHealthTracker());
                  },
                  child: _listTile("Add Vitals Tracker", Icons.track_changes)),
              20.height,
              InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    NavigationHelper.navPush(
                        context, const DeviceHomeDashboardScreen());
                  },
                  child: _listTile("View Device", Icons.visibility)),
              20.height,
              InkWell(
                  onTap: () async {
                    await firebaseAuth.signOut().then((value) {
                      NavigationHelper.navStart(context, const GetStarted());
                    });
                  },
                  child: _button("Sign out", "logout.png")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listTile(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          width: 28,
          child: Icon(icon),
        ),
        20.width,
        CustomText(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            textColor: title == "Inbox" ? Colors.white : Colors.black)
      ],
    );
  }

  Widget _button(String name, String icon) {
    return PhysicalModel(
      color: Colors.grey,
      elevation: 5,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 45,
        width: double.infinity,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: name == "Support" ? const Color(0xff6C7BCC) : Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomText(
                  text: name,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  textColor:
                      name == "Support" ? Colors.white : Colors.grey.shade800),
              const SizedBox(
                height: 20,
                width: 20,
                child: Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
