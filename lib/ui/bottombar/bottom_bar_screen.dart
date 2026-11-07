import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/home_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/medicine_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/more_screen.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/update_screens.dart';
import 'package:vitals_10/ui/bottombar/screens/bottom_screen/viewtracker/my_tracker_screen.dart';
import '../../utils/constants.dart';

class BottomBarScreen extends StatefulWidget {
  const BottomBarScreen({super.key});

  @override
  State<BottomBarScreen> createState() => _BottomBarScreenState();
}

class _BottomBarScreenState extends State<BottomBarScreen> {
  int _selectedIndex = 0;
  List<Widget> _tabs = [];

  void _onItemTapped(int index) {
    _selectedIndex = index;

    setState(() {});
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _tabs = [
      const HomeScreen(),
      const UpdateScreen(),
      const MedicineScreen(),
      const MyTrackerScreen(),
    ];
    // EasyLocalization.of(context);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.doc),
              label: 'Updates',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_outlined),
              label: 'Medicine',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_liquid_sharp ),
              label: 'Vitals',
            ),
          ],
          currentIndex: _selectedIndex,
          unselectedItemColor: Colors.black,
          selectedItemColor: primaryColor,
          backgroundColor: Colors.white,
          onTap: (index) => _onItemTapped(index),
          unselectedFontSize: 10,
          unselectedIconTheme: const IconThemeData(size: 14),
          type: BottomNavigationBarType.fixed, // Fixed
        ),
        body: _tabs[_selectedIndex],
      ),
    );
  }
}
