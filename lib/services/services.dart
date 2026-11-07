import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/navigation/navigation_helper.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/medicine_screen.dart';

class NotificationController {
  static ReceivedAction? initialAction;
  static Future<void> startListeningNotificationEvents() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    if (receivedAction.actionType == ActionType.SilentAction) {
      if (receivedAction.payload != null) {
        //////////////////////////////
        if(receivedAction.payload!["med_name"] == "Panadol"){
         print("is panadol");
        }
        print(receivedAction.payload!);
        ////////////////////////////
      }
    } else {
      if (receivedAction.payload != null) {
        //////////////////////////////
        if(receivedAction.payload!["med_name"] == "Panadol"){
          print("is panadol");
        }
        print(receivedAction.payload!);
        ////////////////////////////
      }
    }
  }
}