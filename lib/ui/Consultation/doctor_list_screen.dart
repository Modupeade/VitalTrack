import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vitals_10/models/doctor_model.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/utils/currency_formatter.dart';

class DoctorListScreen extends StatefulWidget {
  final Function(Doctor) onDoctorSelected;

  const DoctorListScreen({
    Key? key,
    required this.onDoctorSelected,
  }) : super(key: key);

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  List<Doctor> doctors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  

  Future<void> _loadDoctors() async {
    try {
      FirebaseFirestore.instance
          .collection('doctorCollection')
          .where('isBlocked', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        doctors =
            snapshot.docs.map((doc) => Doctor.fromFirestore(doc)).toList();
        setState(() {
          isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading doctors: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Doctor'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctors.isEmpty
              ? const Center(child: Text('No doctors available now'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          widget.onDoctorSelected(doctor);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                primaryColor.withOpacity(0.1),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor:
                                      primaryColor.withOpacity(0.1),
                                  backgroundImage:
                                      AssetImage('assets/icons/doctor_calendar.png'),
                                  /*Text(
                                    doctor.name[0],
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),*/
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doctor.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        doctor.hospital,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        doctor.orgName,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Consultation Fee: ${CurrencyFormatter.formatUSD(doctor.fee)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Icon(
                                //   Icons.arrow_forward_ios,
                                //   color: primaryColor,
                                //   size: 16,
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
