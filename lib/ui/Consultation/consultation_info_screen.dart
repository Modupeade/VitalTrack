import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitals_10/models/doctor_model.dart';
import 'package:vitals_10/utils/constants.dart';
import 'package:vitals_10/utils/currency_formatter.dart';
import '../../services/email_service.dart';

class ConsultationInfoScreen extends StatefulWidget {
  const ConsultationInfoScreen({Key? key}) : super(key: key);

  @override
  State<ConsultationInfoScreen> createState() => _ConsultationInfoScreenState();
}

class _ConsultationInfoScreenState extends State<ConsultationInfoScreen> {
  bool agreedToTerms = false;
  // String? selectedSpecialist;
  // final List<Map<String, String>> specialists = [
  //   {
  //     'label': 'Cardiologist (Hypertension)',
  //     'value': 'Cardiologist (Hypertension)'
  //   },
  //   {
  //     'label': 'Endocrinologist (Diabetes)',
  //     'value': 'Endocrinologist (Diabetes)'
  //   },
  // ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Consultation'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor,
              Colors.white,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Banner image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/doctor.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ) /*Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/vh-1-5ed7e.appspot.com/o/images%2FArticleImg1699139909189?alt=media&token=478623b1-f956-4204-bd58-ec10666e4398',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )*/
                  ,
                ),
              ),
              const SizedBox(height: 24),
              // Info Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row(
                          //   children: [
                          //     Icon(
                          //       Icons.medical_services_outlined,
                          //       color: primaryColor,
                          //       size: 28,
                          //     ),
                          //     const SizedBox(width: 10),
                          //     Text(
                          //       'Specialist Consultation',
                          //       style: TextStyle(
                          //         fontSize: 22,
                          //         fontWeight: FontWeight.bold,
                          //         color: primaryColor,
                          //       ),
                          //     ),
                          //   ],
                          // ),

                          Row(
                            children: [
                              Icon(
                                Icons.medical_services_outlined,
                                color: primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Specialist Consultation',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              // 'We recommend you register your Medication(s) on the App, as well as log your Vitals measurements before booking this Specialist Consultation.',
                              "Are you concerned about your blood pressure or blood sugar numbers? Book a second-opinion consultation to speak with a Specialist Doctor!",
                               textAlign: TextAlign
                                        .justify,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment
                                  .center, 
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: primaryColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Having either high blood pressure or high sugar numbers can increase your risk of a heart attack, stroke or kidney failure.",
                                    textAlign: TextAlign
                                        .justify,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // Terms and Next button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: agreedToTerms
                                    ? primaryColor
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Checkbox(
                              value: agreedToTerms,
                              onChanged: (val) {
                                setState(() => agreedToTerms = val ?? false);
                              },
                              activeColor: primaryColor,
                              shape: const CircleBorder(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms',
                                    style: TextStyle(
                                      color: primaryColor,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        if (!await launchUrl(Uri.parse("http://vitals101.com/terms"))) {
                                          throw Exception('Could not launch');
                                        }
                                      },
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: primaryColor,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () async {
                                        if (!await launchUrl(Uri.parse("https://vitals101.com/privacy"))) {
                                          throw Exception('Could not launch');
                                        }
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Specialist selection
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: Column(
                    //         crossAxisAlignment: CrossAxisAlignment.stretch,
                    //         children: specialists.map((spec) {
                    //           final isSelected =
                    //               selectedSpecialist == spec['value'];
                    //           return GestureDetector(
                    //             onTap: () {
                    //               setState(() {
                    //                 selectedSpecialist = spec['value'];
                    //               });
                    //             },
                    //             child: Container(
                    //               margin: const EdgeInsets.only(bottom: 8),
                    //               padding: const EdgeInsets.symmetric(
                    //                   horizontal: 12, vertical: 12),
                    //               decoration: BoxDecoration(
                    //                 color: isSelected
                    //                     ? Colors.green
                    //                     : Colors.white,
                    //                 borderRadius: BorderRadius.circular(8),
                    //                 border: Border.all(
                    //                     color: Colors.green, width: 2),
                    //               ),
                    //               child: Row(
                    //                 children: [
                    //                   Icon(Icons.check_circle,
                    //                       color: isSelected
                    //                           ? Colors.white
                    //                           : Colors.green,
                    //                       size: 22),
                    //                   const SizedBox(width: 10),
                    //                   Expanded(
                    //                     child: Text(
                    //                       spec['label']!,
                    //                       style: TextStyle(
                    //                         color: isSelected
                    //                             ? Colors.white
                    //                             : Colors.green,
                    //                         fontWeight: FontWeight.bold,
                    //                         fontSize: 16,
                    //                       ),
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //             ),
                    //           );
                    //         }).toList(),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            agreedToTerms /*&& selectedSpecialist != null*/
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ConsultationBookingScreen(
                                                /* selectedSpecialist:
                                                selectedSpecialist!*/
                                                ),
                                      ),
                                    );
                                  }
                                : null,
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConsultationBookingScreen extends StatefulWidget {
  // final String selectedSpecialist;
  const ConsultationBookingScreen(
      {Key? key /*, required this.selectedSpecialist*/})
      : super(key: key);

  @override
  State<ConsultationBookingScreen> createState() =>
      _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState extends State<ConsultationBookingScreen> {
  final List<String> selectedTimes = [];
  final List<String> selectedDays = [];
  final List<String> days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  String? selectedPlatform;
  final List<Map<String, dynamic>> platforms = [
    {'name': 'WhatsApp', 'icon': Icons.chat, 'color': Colors.green},
    {'name': 'Zoom', 'icon': Icons.video_call, 'color': Colors.blue},
    {'name': 'Teams', 'icon': Icons.groups, 'color': Colors.indigo},
    {
      'name': 'Google Meet',
      'icon': Icons.video_camera_front,
      'color': Colors.teal
    },
    {'name': 'Phone Call', 'icon': Icons.phone, 'color': Colors.black},
  ];
  String? selectedPacket;
  final List<Map<String, dynamic>> packets = [
    {'name': 'Second-Opinion Consultation', 'price': AppPricing.secondOpinionPrice},
    {'name': 'Follow-ups', 'price': AppPricing.followUpPrice},
  ];

  Doctor? selectedDoctor;
  bool isLoading = false;
  bool _isSubmitting = false;

  // JotForm link for consultation booking
  static const String jotFormLink = 'https://jotform.com/app/253315266354557';

  @override
  void initState() {
    super.initState();
    _loadFirstDoctor();
  }

  Future<void> _loadFirstDoctor() async {
    setState(() {
      selectedDoctor = Doctor(
          docId: '5GNb0ps8R3ZEunLnWiycbfQtBOn2',
          name: 'Dr. Jerome Iyamu (MBBS, FWACP)',
          email: '',
          hospital: 'Specialist in Internal Medicine',
          isBlocked: false,
          orgId: '1VJAcODjZhYtoV6pISqCAVxK01h2',
          orgName: 'England · United Kingdom.',
          date: Timestamp.now(),
          fee: 120);
    });
    // try {
    //   FirebaseFirestore.instance
    //       .collection('doctorCollection')
    //       .where('isBlocked', isEqualTo: false)
    //       .limit(1)
    //       .snapshots()
    //       .listen((snapshot) {
    //     if (snapshot.docs.isNotEmpty) {
    //       setState(() {
    //         selectedDoctor = Doctor.fromFirestore(snapshot.docs.first);
    //         isLoading = false;
    //       });
    //     } else {
    //       setState(() {
    //         isLoading = false;
    //       });
    //     }
    //   });
    // } catch (e) {
    //   print('Error loading first doctor: $e');
    //   setState(() {
    //     isLoading = false;
    //   });
    // }
  }

  // void _onDoctorSelected(Doctor doctor) {
  //   setState(() {
  //     selectedDoctor = doctor;
  //   });
  // }

  void _toggleTime(int time, String period) {
    setState(() {
      final idx = selectedTimes.indexWhere((t) => t == "$time $period");
      if (idx != -1) {
        selectedTimes.removeAt(idx);
      } else {
        selectedTimes.add("$time $period");
      }
    });
  }

  void _toggleDay(String day) {
    setState(() {
      if (selectedDays.contains(day)) {
        selectedDays.remove(day);
      } else {
        selectedDays.add(day);
      }
    });
  }

  void _submit() {
    if (selectedTimes.isEmpty ||
        selectedDays.isEmpty ||
        selectedPlatform == null ||
        selectedPacket == null ||
        selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required options.')),
      );
      return;
    }

    // Show review dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Icon(Icons.info_outline, color: primaryColor, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Review Your Request',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Times:', selectedTimes.join(", ")),
                    _infoRow('Days:', selectedDays.join(", ")),
                    _infoRow('Platform:', selectedPlatform ?? ''),
                    _infoRow('Consultation:', selectedPacket ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Request Consultation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    setState(() {
      _isSubmitting = true;
    });

    // Show "Sending..." dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF005EA6)),
              const SizedBox(height: 20),
              const Text(
                'Sending...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we submit your request',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get user email
      final userEmail = user.email ?? '';

      // Get user name from Firestore (where it's stored during registration)
      String userName = user.displayName ?? 'User';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()?['name'] != null) {
          userName = userDoc.data()!['name'];
        }
      } catch (e) {
        print('Error fetching user name from Firestore: $e');
      }

      // Send consultation request to support team
      final emailSent = await EmailService.sendEmail(
        recipientEmail: 'support@vitals101.com',
        subject: 'New Consultation Request from $userName',
        htmlContent: _getSupportEmailHTML(userName, userEmail),
        textContent: _getSupportEmailText(userName, userEmail),
      );

      if (emailSent) {
        print('Consultation email sent successfully');
      } else {
        print('Failed to send consultation email');
      }

      // Close the sending dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      print('Error submitting consultation request: $e');
      // Close the sending dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Submitted!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your consultation request has been submitted successfully. Our team will contact you shortly to confirm your booking.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getConsultationEmailHTML(String name) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Consultation Request</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f4f4f4;
            }
            .container {
                background-color: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 0 10px rgba(0,0,0,0.1);
            }
            .header {
                text-align: center;
                background: linear-gradient(135deg, #005EA6, #0078D4);
                color: white;
                padding: 20px;
                border-radius: 10px 10px 0 0;
                margin: -30px -30px 30px -30px;
            }
            .logo {
                font-size: 28px;
                font-weight: bold;
                margin-bottom: 10px;
            }
            .cta-button {
                display: inline-block;
                background-color: #005EA6;
                color: white;
                padding: 15px 30px;
                text-decoration: none;
                border-radius: 25px;
                font-weight: bold;
                margin: 20px 0;
            }
            .footer {
                text-align: center;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                color: #666;
                font-size: 14px;
            }
            .booking-details {
                background-color: #f8f9fa;
                padding: 15px;
                margin: 15px 0;
                border-left: 4px solid #005EA6;
                border-radius: 5px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">Vitals 101</div>
                <div>Consultation Request Received</div>
            </div>

            <h2>Hello $name! 👋</h2>

            <p>Thank you for submitting your consultation request. We have received your booking details:</p>

            <div class="booking-details">
                <p><strong>Preferred Times:</strong> ${selectedTimes.join(", ")}</p>
                <p><strong>Preferred Days:</strong> ${selectedDays.join(", ")}</p>
                <p><strong>Platform:</strong> $selectedPlatform</p>
                <p><strong>Consultation Type:</strong> $selectedPacket</p>
            </div>

            <p>To complete your booking, please fill out the consultation form by clicking the button below:</p>

            <center>
                <a href="$jotFormLink" class="cta-button">Complete Your Booking</a>
            </center>

            <p>If the button doesn't work, copy and paste this link into your browser:</p>
            <p style="color: #005EA6; word-break: break-all;">$jotFormLink</p>

            <div class="footer">
                <p>Thank you for choosing Vitals 101!</p>
                <p>Stay healthy, stay informed!</p>
                <br>
                <p>Best regards,<br>The Vitals 101 Team</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  String _getConsultationEmailText(String name) {
    return '''
Consultation Request Received

Hello $name! 👋

Thank you for submitting your consultation request. We have received your booking details:

Preferred Times: ${selectedTimes.join(", ")}
Preferred Days: ${selectedDays.join(", ")}
Platform: $selectedPlatform
Consultation Type: $selectedPacket

To complete your booking, please fill out the consultation form at:
$jotFormLink

Thank you for choosing Vitals 101!
Stay healthy, stay informed!

Best regards,
The Vitals 101 Team
    ''';
  }

  String _getSupportEmailHTML(String userName, String userEmail) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: #005EA6; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
            .booking-details { background: #e8f4f8; padding: 15px; border-radius: 8px; margin: 15px 0; }
            .booking-details p { margin: 8px 0; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            h2 { color: #005EA6; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>New Consultation Request</h1>
            </div>

            <div class="content">
                <h2>User Details</h2>
                <div class="booking-details">
                    <p><strong>Name:</strong> $userName</p>
                    <p><strong>Email:</strong> $userEmail</p>
                </div>

                <h2>Consultation Preferences</h2>
                <div class="booking-details">
                    <p><strong>Preferred Times:</strong> ${selectedTimes.join(", ")}</p>
                    <p><strong>Preferred Days:</strong> ${selectedDays.join(", ")}</p>
                    <p><strong>Platform:</strong> $selectedPlatform</p>
                    <p><strong>Consultation Type:</strong> $selectedPacket</p>
                </div>

                <p>Please contact the user to confirm their consultation booking.</p>
            </div>

            <div class="footer">
                <p>This is an automated message from Vitals 101 App</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  String _getSupportEmailText(String userName, String userEmail) {
    return '''
NEW CONSULTATION REQUEST

User Details:
- Name: $userName
- Email: $userEmail

Consultation Preferences:
- Preferred Times: ${selectedTimes.join(", ")}
- Preferred Days: ${selectedDays.join(", ")}
- Platform: $selectedPlatform
- Consultation Type: $selectedPacket

Please contact the user to confirm their consultation booking.

---
This is an automated message from Vitals 101 App
    ''';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Consultation'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width doctor banner image (scrolls with content)
            Image.asset(
              'assets/icons/doctor_calendar.png',
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Time and Day Selection Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Preferred Time and Day',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...List.generate(12, (i) {
                          final timeLabels = [
                            '9am',
                            '10am',
                            '11am',
                            '12pm',
                            '1pm',
                            '2pm',
                            '3pm',
                            '4pm',
                            '5pm',
                            '6pm',
                            '7pm',
                            '8pm',
                          ];
                          final label = timeLabels[i];
                          final isSelected = selectedTimes.contains(label);
                          return ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (!isSelected) {
                                  selectedTimes.add(label);
                                } else {
                                  selectedTimes.remove(label);
                                }
                              });
                            },
                            selectedColor: primaryColor,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          );
                        })
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You can select multiple options',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: days.map((day) {
                        final selected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: selected,
                          onSelected: (_) => _toggleDay(day),
                          selectedColor: primaryColor,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Platform Selection Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.video_call, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Preferred Platform',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: platforms.map((platform) {
                        final selected = selectedPlatform == platform['name'];
                        return ChoiceChip(
                          avatar: Icon(
                            platform['icon'],
                            color: selected ? Colors.white : platform['color'],
                            size: 18,
                          ),
                          label: Text(platform['name']),
                          selected: selected,
                          onSelected: (_) => setState(
                              () => selectedPlatform = platform['name']),
                          selectedColor: platform['color'],
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Fees Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No charge message
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You will not be charged for requesting this Consultation',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.medical_services_outlined, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Consultation Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: packets.map((packet) {
                        final selected = selectedPacket == packet['name'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedPacket = packet['name'];
                              });
                            },
                            child: Container(
                              height: 130,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: selected ? primaryColor : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? primaryColor
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    packet['name'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    packet['price'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Submit Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
                    const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
