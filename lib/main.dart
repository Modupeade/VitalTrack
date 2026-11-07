import 'dart:developer';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

//import the reader device sdk

// import 'package:flutter_app_badger/flutter_app_badger.dart'; // Discontinued package
import 'package:google_fonts/google_fonts.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitals_10/services/facebook_analytics_service.dart';
import 'package:vitals_10/ui/auth/splash_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/home_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/update_tracker.dart';
import 'package:vitals_10/ui/bottombar/screens/medicine_notification/MedicineNotificationDialog.dart';
import 'package:vitals_10/utils/bluotooth_model.dart';
import 'package:vitals_10/utils/constants.dart';
import 'firebase_options.dart';



Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  int badgeCount = prefs.getInt('badgeCount') ?? 0;
  badgeCount++;

// log('badg count $badgeCount');

  await prefs.setInt('badgeCount', badgeCount);
  // FlutterAppBadger.updateBadgeCount(badgeCount); // Discontinued package
}

Future<bool> hasDayChangedSinceLastCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final lastCheckString = prefs.getString('lastCheckedDate');

  DateTime now = DateTime.now();
  DateTime lastCheck;

  if (lastCheckString != null) {
    lastCheck = DateTime.parse(lastCheckString);
  } else {
    // First time run
    await prefs.setString('lastCheckedDate', now.toIso8601String());
    return true;
  }

  // Compare only date (ignore time)
  bool dayChanged = now.year != lastCheck.year ||
      now.month != lastCheck.month ||
      now.day != lastCheck.day;

  if (dayChanged) {
    await prefs.setString('lastCheckedDate', now.toIso8601String());
  }

  return dayChanged;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('Permission status: ${settings.authorizationStatus}');

  try {
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');
  } catch (e) {
    log('Error getting FCM token: $e');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground message: ${message.notification?.title}');
  });
  bool dayChanged = await hasDayChangedSinceLastCheck();
  if (dayChanged) {
    // FlutterAppBadger.removeBadge(); // Discontinued package
  }
  await NotificationController.initializeLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Facebook Analytics
  await FacebookAnalyticsService.initialize();

  // Track app open
  await FacebookAnalyticsService.logAppOpen();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ReceivedAction? receivedAction;

  /// Owned here rather than by a route, so the BLE link lives as long as the
  /// app does and survives navigating between pages.
  final BluetoothScanModel _bluetoothModel = BluetoothScanModel();

  @override
  void initState() {
    receivedAction = NotificationController.initialAction;
    AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod);
    WidgetsBinding.instance.addObserver(this);
    // Pick the band back up after a cold start or a process death.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _bluetoothModel.reconnectLastDevice());
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bluetoothModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android can still drop the GATT link while we're backgrounded despite the
    // foreground service, so re-check on the way back in.
    if (state == AppLifecycleState.resumed) {
      _bluetoothModel.reconnectLastDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BluetoothScanModel>.value(
          value: _bluetoothModel,
        ),
      ],
      child:  KeyboardDismisser(
        gestures: const [GestureType.onTap, GestureType.onPanUpdateDownDirection],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Vitals 101',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              // backgroundColor: Colors.white,
              fontFamily: GoogleFonts.poppins().fontFamily),
          home:

              // VitalsAlertsScreen()

              receivedAction == null ? const SplashScreen() : const HomeScreen(),
        ),
      )
    );
  }
}

class NotificationController {
  static ReceivedAction? initialAction;

  static Future<void> initializeLocalNotifications() async {
    AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
              channelGroupKey: 'basic_channel_group',
              channelKey: 'basic_channel',
              channelName: 'Basic notifications',
              channelDescription: 'Notification channel for basic tests',
              defaultColor: const Color(0xFF9D50DD),
              channelShowBadge: true,
              ledColor: Colors.white)
        ],
        channelGroups: [
          NotificationChannelGroup(
              channelGroupKey: 'basic_channel_group',
              channelGroupName: 'Basic group')
        ],
        debug: true);

    // Get initial notification action is optional
    initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: false);
    print("Notification is working");
  }

  static Future<void> startListeningNotificationEvents() async {
    print("notification arrived");
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    if (receivedAction.payload != null) {
      //////////////////////////////
      if (receivedAction.payload!["notificationType"].toString() ==
          "Tracker_Notification") {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
              builder: (context) => UpdateTracker(
                  trackerID: receivedAction.payload!["trackerID"].toString(),
                  name: receivedAction.payload!["trackerName"].toString())),
        );
      } else {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
              builder: (context) => MedicineNotificationDialog(
                    medName: receivedAction.payload!["trackerName"].toString(),
                    medType: receivedAction.payload!["medType"].toString(),
                    medID: receivedAction.payload!["medID"].toString(),
                  )),
        );
      }
    }
    ////////////////////////////
  }
}
