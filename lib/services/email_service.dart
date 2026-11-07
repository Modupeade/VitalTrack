import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class EmailService {
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;

  // Fallback credentials (remove these in production)
  static const String _fallbackUsername = 'your-email@gmail.com';
  static const String _fallbackPassword = 'your-app-password';

  // Method to fetch email credentials from Firebase
  static Future<Map<String, String>> _getEmailCredentials() async {
    try {
      // Fetch from Firebase
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('email_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final username = data['email_username'] as String?;
        final password = data['email_password'] as String?;

        if (username != null && password != null) {
          return {'username': username, 'password': password};
        }
      }

      // Fallback to hardcoded credentials if Firebase fetch fails
      print(
        'Warning: Using fallback email credentials. Please configure Firebase email settings.',
      );
      return {'username': _fallbackUsername, 'password': _fallbackPassword};
    } catch (e) {
      print('Error fetching email credentials from Firebase: $e');
      // Fallback to hardcoded credentials
      return {'username': _fallbackUsername, 'password': _fallbackPassword};
    }
  }

  static Future<bool> sendWelcomeEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    try {
      // Get email credentials from Firebase
      final credentials = await _getEmailCredentials();

      // Create SMTP server
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: credentials['username']!,
        password: credentials['password']!,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      // Create the email message
      final message = Message()
        ..from = Address(credentials['username']!, 'Vitals 101 Team')
        ..recipients.add(recipientEmail)
        ..subject = 'Welcome to Vitals 101! 🎉'
        ..html = _getWelcomeEmailHTML(recipientName)
        ..text = _getWelcomeEmailText(recipientName);

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Welcome email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending welcome email: $e');
      return false;
    }
  }

  // Send 4-digit verification code email
  static Future<bool> sendVerificationCodeEmail({
    required String recipientEmail,
    required String recipientName,
    required String verificationCode,
  }) async {
    try {
      // Get email credentials from Firebase
      final credentials = await _getEmailCredentials();

      // Create SMTP server
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: credentials['username']!,
        password: credentials['password']!,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      // Create the email message
      final message = Message()
        ..from = Address(credentials['username']!, 'Vitals 101 Team')
        ..recipients.add(recipientEmail)
        ..subject = 'Verify Your Email - Vitals 101'
        ..html = _getVerificationCodeEmailHTML(recipientName, verificationCode)
        ..text = _getVerificationCodeEmailText(recipientName, verificationCode);

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Verification code email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending verification code email: $e');
      return false;
    }
  }

  // Generic email sending method for global use
  static Future<bool> sendEmail({
    required String recipientEmail,
    required String subject,
    required String htmlContent,
    String? textContent,
    String? recipientName,
    String? senderName,
  }) async {
    try {
      // Get email credentials from Firebase
      final credentials = await _getEmailCredentials();
      debugPrint('email credentials ${credentials['username']!}');
      // Create SMTP server
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: credentials['username']!,
        password: credentials['password']!,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      // Create the email message
      final message = Message()
        ..from = Address(
          credentials['username']!,
          senderName ?? 'Vitals 101 Team',
        )
        ..recipients.add(recipientEmail)
        ..subject = subject
        ..html = htmlContent
        ..text = textContent ?? _stripHtml(htmlContent);

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  // Send report email method
  static Future<bool> sendReportEmail({
    required String recipientEmail,
    required String reportType,
    required String reportData,
    String? recipientName,
  }) async {
    const subject = 'Blood Pressure Alerts Report';
    final htmlContent = _getReportEmailHTML(
      recipientName ?? 'User',
      reportType,
      reportData,
    );
    final textContent = _getReportEmailText(
      recipientName ?? 'User',
      reportType,
      reportData,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      subject: subject,
      htmlContent: htmlContent,
      textContent: textContent,
      recipientName: recipientName,
    );
  }

  // Send BP records report with table format
  static Future<bool> sendBPRecordsReport({
    required String recipientEmail,
    required String recipientName,
    required List<Map<String, dynamic>> bpRecords,
    String? dateRange,
  }) async {
    final subject = 'Blood Pressure Alerts Report';
    final htmlContent = _getBPRecordsEmailHTML(
      recipientName,
      bpRecords,
      dateRange,
    );
    final textContent = _getBPRecordsEmailText(
      recipientName,
      bpRecords,
      dateRange,
    );

    return await sendEmail(
      recipientEmail: recipientEmail,
      subject: subject,
      htmlContent: htmlContent,
      textContent: textContent,
      recipientName: recipientName,
    );
  }

  // Generate PDF and upload to Firebase Storage
  static Future<String?> _generateAndUploadPDF({
    required String recipientName,
    required List<Map<String, dynamic>> bpRecords,
    List<Map<String, dynamic>>? glucoseRecords,
    List<Map<String, dynamic>>? weightRecords,
    String? dateRange,
    int? systolicThreshold,
    int? diastolicThreshold,
    double? systolicTrend,
    double? diastolicTrend,
  }) async {
    try {
      final pdf = pw.Document();

      // Calculate BP statistics
      final bpStats = _calculateBPStatistics(bpRecords);

      // Calculate additional stats for PDF (Time in Target, Time in Elevated, MAP)
      int timeInTarget = 0;
      int timeInElevated = 0;
      double avgMap = 0;
      if (bpRecords.isNotEmpty) {
        final sysThreshold = systolicThreshold ?? 120;
        final diaThreshold = diastolicThreshold ?? 80;
        final inTargetCount = bpRecords.where((r) {
          final sys = int.tryParse(r['sys']?.toString() ?? '0') ?? 0;
          final dia = int.tryParse(r['dia']?.toString() ?? '0') ?? 0;
          return sys > 0 && dia > 0 && sys < sysThreshold && dia < diaThreshold;
        }).length;
        timeInTarget = ((inTargetCount / bpRecords.length) * 100).round();

        // Calculate Time in Elevated Range (sys >= 120 OR dia >= 80)
        final elevatedCount = bpRecords.where((r) {
          final sys = int.tryParse(r['sys']?.toString() ?? '0') ?? 0;
          final dia = int.tryParse(r['dia']?.toString() ?? '0') ?? 0;
          return sys > 0 && dia > 0 && (sys >= sysThreshold || dia >= diaThreshold);
        }).length;
        timeInElevated = ((elevatedCount / bpRecords.length) * 100).round();

        // Calculate Mean Arterial Pressure (MAP = (2 * DBP + SBP) / 3)
        double mapSum = 0;
        int validCount = 0;
        for (var r in bpRecords) {
          final sys = int.tryParse(r['sys']?.toString() ?? '0') ?? 0;
          final dia = int.tryParse(r['dia']?.toString() ?? '0') ?? 0;
          if (sys > 0 && dia > 0) {
            mapSum += (2 * dia + sys) / 3;
            validCount++;
          }
        }
        if (validCount > 0) avgMap = mapSum / validCount;
      }

      // Add pages to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (context) => [
            // Header with colorful banner
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'VITALS101',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.Text(
                    'Comprehensive Health Report',
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.blue100,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            // Report details box
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Patient: $recipientName',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      if (dateRange != null)
                        pw.Text(
                          'Period: $dateRange',
                          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Time: ${DateFormat('HH:mm').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Blood Pressure Section
            pw.Row(
              children: [
                pw.Container(
                  width: 4,
                  height: 40,
                  color: PdfColors.red700,
                ),
                pw.Expanded(
                  child: pw.Container(
                    padding: pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                    ),
                    child: pw.Text(
                      'Blood Pressure Analysis',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // BP Statistics Grid
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary Statistics',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  // Row 1: Avg Systolic (pink), Avg Diastolic (blue)
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildStatCard('Avg Systolic', '${bpStats['avgSystolic']} mmHg', color: PdfColors.pink100)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: _buildStatCard('Avg Diastolic', '${bpStats['avgDiastolic']} mmHg', color: PdfColors.lightBlue100)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  // Row 2: Highest BP (pink), Lowest BP (blue), Total Count (yellow)
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildStatCard('Highest BP', '${bpStats['highestSystolic']}/${bpStats['highestDiastolic']}', color: PdfColors.pink100)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: _buildStatCard('Lowest BP', '${bpStats['lowestSystolic']}/${bpStats['lowestDiastolic']}', color: PdfColors.lightBlue100)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: _buildStatCard('No. of BP Readings', '${bpRecords.length}', color: PdfColors.amber100)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  // Row 3: Target Range, Time in Target Range, Time in Elevated Range (RED)
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildStatCard('Target Range', '<${systolicThreshold ?? 120}/<${diastolicThreshold ?? 80}', color: PdfColors.grey200)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: _buildStatCard('Time in Target Range', '$timeInTarget%', color: PdfColors.grey200)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: _buildStatCard('Time in Elevated Range', '$timeInElevated%', color: PdfColors.red)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  // Row 4: Systolic Trend, Diastolic Trend, Avg MAP
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildStatCard(
                          'Systolic Trend',
                          '${(systolicTrend ?? 0).abs().toStringAsFixed(1)} mmHg ${_getPdfTrendArrow(systolicTrend ?? 0)}',
                          color: PdfColors.grey200,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: _buildStatCard(
                          'Diastolic Trend',
                          '${(diastolicTrend ?? 0).abs().toStringAsFixed(1)} mmHg ${_getPdfTrendArrow(diastolicTrend ?? 0)}',
                          color: PdfColors.grey200,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: _buildStatCard('Avg MAP', '${avgMap.toStringAsFixed(0)} mmHg', color: PdfColors.grey200)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // BP Trend Line Chart (Last 20 readings with dates)
            _buildBPLineChart(bpRecords),
            pw.SizedBox(height: 20),

            // All BP Readings Chart - only show if more than 20 readings
            if (bpRecords.length > 20) ...[
              _buildBPAllReadingsChart(bpRecords),
              pw.SizedBox(height: 20),
            ],

            // BP Category Distribution Pie Chart
            _buildBPCategoryPieChart(bpRecords),
            pw.SizedBox(height: 20),

            // BP Readings Table
            pw.Text(
              'Blood Pressure Readings',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildBPTable(bpRecords),

            // Add glucose section if data exists
            if (glucoseRecords != null && glucoseRecords.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Row(
                children: [
                  pw.Container(
                    width: 4,
                    height: 40,
                    color: PdfColors.green700,
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                      ),
                      child: pw.Text(
                        'Blood Glucose Analysis',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              _buildGlucoseSection(glucoseRecords),
            ],

            // Add weight section if data exists
            if (weightRecords != null && weightRecords.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Row(
                children: [
                  pw.Container(
                    width: 4,
                    height: 40,
                    color: PdfColors.orange700,
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange50,
                      ),
                      child: pw.Text(
                        'Weight Tracking',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              _buildWeightSection(weightRecords),
              // All Weight Readings Chart - only show if more than 20 readings
              if (weightRecords.length > 20) ...[
                pw.SizedBox(height: 20),
                _buildWeightAllReadingsChart(weightRecords),
              ],
            ],

            // Footer note
            pw.SizedBox(height: 30),
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue600,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'i',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'Important Note',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This report is generated by Vitals101 for informational purposes only. Always consult with your healthcare provider for medical advice and before making any health-related decisions.',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.blue200),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      'Powered by Vitals101 - Your Health Companion',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.blue600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // Save PDF to temporary file
      final output = await getTemporaryDirectory();
      // Format filename as Vitals101_Report_Oct22-Nov30.pdf
      String formattedDateRange;
      if (dateRange != null && dateRange.contains(' - ')) {
        final parts = dateRange.split(' - ');
        if (parts.length == 2) {
          // Parse start date (e.g., "Oct 22, 2024" -> "Oct22")
          final startParts = parts[0].trim().split(RegExp(r'[,\s]+'));
          final startFormatted = startParts.length >= 2
              ? '${startParts[0]}${startParts[1]}'
              : parts[0].replaceAll(RegExp(r'[,\s/]'), '');

          // Parse end date (e.g., "Nov 30, 2024" -> "Nov30")
          final endParts = parts[1].trim().split(RegExp(r'[,\s]+'));
          final endFormatted = endParts.length >= 2
              ? '${endParts[0]}${endParts[1]}'
              : parts[1].replaceAll(RegExp(r'[,\s/]'), '');

          formattedDateRange = '$startFormatted-$endFormatted';
        } else {
          formattedDateRange = dateRange.replaceAll(RegExp(r'[/\s,]+'), '-');
        }
      } else {
        formattedDateRange = DateFormat('MMMdd').format(DateTime.now());
      }
      final fileName = 'Vitals101_Report_$formattedDateRange.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('pdf_reports/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Delete temporary file
      await file.delete();

      return downloadUrl;
    } catch (e) {
      print('Error generating/uploading PDF: $e');
      return null;
    }
  }

  // Helper function to build stat cards for PDF with color coding
  static pw.Widget _buildStatCard(String label, String value, {PdfColor? color}) {
    // Use provided color or determine based on label
    PdfColor cardColor = color ?? PdfColors.grey100;

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: pw.BoxDecoration(
        color: cardColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper function to calculate BP statistics
  static Map<String, dynamic> _calculateBPStatistics(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {
        'avgSystolic': 0,
        'avgDiastolic': 0,
        'avgPulse': 0,
        'highestSystolic': 0,
        'highestDiastolic': 0,
        'lowestSystolic': 0,
        'lowestDiastolic': 0,
      };
    }

    int totalSystolic = 0, totalDiastolic = 0, totalPulse = 0;
    int highestSys = 0, highestDia = 0;
    int lowestSys = 999, lowestDia = 999;
    int validSysCount = 0, validDiaCount = 0;

    for (var record in records) {
      int sys = int.tryParse(record['sys']?.toString() ?? '0') ?? 0;
      int dia = int.tryParse(record['dia']?.toString() ?? '0') ?? 0;
      int pulse = int.tryParse(record['pul']?.toString() ?? '0') ?? 0;

      totalSystolic += sys;
      totalDiastolic += dia;
      totalPulse += pulse;

      if (sys > 0) {
        validSysCount++;
        if (sys > highestSys) highestSys = sys;
        if (sys < lowestSys) lowestSys = sys;
      }
      if (dia > 0) {
        validDiaCount++;
        if (dia > highestDia) highestDia = dia;
        if (dia < lowestDia) lowestDia = dia;
      }
    }

    // Handle edge case: if no valid readings, set lowest to 0
    if (validSysCount == 0) lowestSys = 0;
    if (validDiaCount == 0) lowestDia = 0;

    return {
      'avgSystolic': (totalSystolic / records.length).round(),
      'avgDiastolic': (totalDiastolic / records.length).round(),
      'avgPulse': (totalPulse / records.length).round(),
      'highestSystolic': highestSys,
      'highestDiastolic': highestDia,
      'lowestSystolic': lowestSys,
      'lowestDiastolic': lowestDia,
    };
  }

  // Helper to format date/time from record
  static String _formatRecordDateTime(Map<String, dynamic> record) {
    // Try 'time' field first
    final timeStr = record['time']?.toString();
    if (timeStr != null && timeStr.isNotEmpty && timeStr != 'null') {
      return timeStr;
    }
    // Fall back to 'addedTime' (milliseconds timestamp)
    final addedTime = record['addedTime'];
    if (addedTime != null) {
      try {
        final timestamp = addedTime is int ? addedTime : int.tryParse(addedTime.toString()) ?? 0;
        if (timestamp > 0) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }
    return 'N/A';
  }

  // Helper to classify BP reading
  static String _classifyBP(int sys, int dia) {
    // Check for invalid/missing data
    if (sys <= 0 || dia <= 0) return 'Invalid';
    // Hypotension (low BP) - systolic < 90 or diastolic < 60
    if (sys < 90 || dia < 60) return 'Low';
    // Normal: Systolic < 120 AND Diastolic < 80
    if (sys < 120 && dia < 80) return 'Normal';
    // Elevated: Systolic 120-129 AND Diastolic < 80
    if (sys >= 120 && sys <= 129 && dia < 80) return 'Elevated';
    // Stage 1: Systolic 130-139 OR Diastolic 80-89
    if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) return 'Stage 1';
    // Stage 2: Systolic >= 140 OR Diastolic >= 90
    return 'Stage 2';
  }

  // Build BP readings table
  static pw.Widget _buildBPTable(List<Map<String, dynamic>> records) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
      },
      headers: ['Date/Time', 'Systolic', 'Diastolic', 'Status'],
      data: records.take(50).map((record) {
        final sys = int.tryParse(record['sys']?.toString() ?? '0') ?? 0;
        final dia = int.tryParse(record['dia']?.toString() ?? '0') ?? 0;
        final status = _classifyBP(sys, dia);

        return [
          _formatRecordDateTime(record),
          record['sys']?.toString() ?? 'N/A',
          record['dia']?.toString() ?? 'N/A',
          status,
        ];
      }).toList(),
    );
  }

  // Build glucose section
  static pw.Widget _buildGlucoseSection(List<Map<String, dynamic>> records) {
    final glucoseStats = _calculateGlucoseStatistics(records);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Summary Statistics',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(child: _buildStatCard('Average', '${glucoseStats['average']} mg/dL')),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _buildStatCard('Highest', '${glucoseStats['highest']} mg/dL')),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _buildStatCard('Lowest', '${glucoseStats['lowest']} mg/dL')),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        // Glucose Trend Line Chart (Last 20 readings with dates)
        _buildGlucoseLineChart(records),
        pw.SizedBox(height: 15),

        // All Glucose Readings Chart - only show if more than 20 readings
        if (records.length > 20) ...[
          _buildGlucoseAllReadingsChart(records),
          pw.SizedBox(height: 15),
        ],

        pw.Text(
          'Blood Glucose Readings',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: PdfColors.green800),
          cellHeight: 30,
          headers: ['Date/Time', 'Glucose (mg/dL)', 'Type'],
          data: records.take(50).map((record) => [
            _formatRecordDateTime(record),
            record['glucose']?.toString() ?? record['value']?.toString() ?? 'N/A',
            record['type']?.toString() ?? 'N/A',
          ]).toList(),
        ),
      ],
    );
  }

  // Calculate glucose statistics
  static Map<String, dynamic> _calculateGlucoseStatistics(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {'average': 0, 'highest': 0, 'lowest': 0};
    }

    int total = 0, highest = 0, lowest = 9999;

    for (var record in records) {
      int value = int.tryParse(record['glucose']?.toString() ?? record['value']?.toString() ?? '0') ?? 0;
      if (value > 0) {
        total += value;
        if (value > highest) highest = value;
        if (value < lowest) lowest = value;
      }
    }

    return {
      'average': (total / records.length).round(),
      'highest': highest,
      'lowest': lowest,
    };
  }

  // Build weight section
  static pw.Widget _buildWeightSection(List<Map<String, dynamic>> records) {
    final weightStats = _calculateWeightStatistics(records);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Summary Statistics',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Expanded(child: _buildStatCard('Average', '${weightStats['average']} ${weightStats['unit']}')),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _buildStatCard('Highest', '${weightStats['highest']} ${weightStats['unit']}')),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: _buildStatCard('Lowest', '${weightStats['lowest']} ${weightStats['unit']}')),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Text(
          'Weight Readings',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(color: PdfColors.orange800),
          cellHeight: 30,
          headers: ['Date/Time', 'Weight', 'Unit'],
          data: records.take(50).map((record) => [
            _formatRecordDateTime(record),
            record['weight']?.toString() ?? record['value']?.toString() ?? 'N/A',
            record['unit']?.toString() ?? 'kg',
          ]).toList(),
        ),
      ],
    );
  }

  // Calculate weight statistics
  static Map<String, dynamic> _calculateWeightStatistics(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {'average': 0, 'highest': 0, 'lowest': 0, 'unit': 'kg'};
    }

    double total = 0, highest = 0, lowest = 9999;
    String unit = records.first['unit']?.toString() ?? 'kg';

    for (var record in records) {
      double value = double.tryParse(record['weight']?.toString() ?? record['value']?.toString() ?? '0') ?? 0;
      if (value > 0) {
        total += value;
        if (value > highest) highest = value;
        if (value < lowest) lowest = value;
      }
    }

    return {
      'average': (total / records.length).toStringAsFixed(1),
      'highest': highest.toStringAsFixed(1),
      'lowest': lowest.toStringAsFixed(1),
      'unit': unit,
    };
  }

  // Calculate BP category distribution for pie chart
  static Map<String, dynamic> _calculateBPCategoryDistribution(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return {
        'low': 0,
        'normal': 0,
        'elevated': 0,
        'stage1': 0,
        'stage2': 0,
        'lowPercent': 0.0,
        'normalPercent': 0.0,
        'elevatedPercent': 0.0,
        'stage1Percent': 0.0,
        'stage2Percent': 0.0,
      };
    }

    int low = 0, normal = 0, elevated = 0, stage1 = 0, stage2 = 0;
    int validRecords = 0;

    for (var record in records) {
      final sys = int.tryParse(record['sys']?.toString() ?? '0') ?? 0;
      final dia = int.tryParse(record['dia']?.toString() ?? '0') ?? 0;

      // Skip invalid records (sys=0 or dia=0)
      if (sys <= 0 || dia <= 0) continue;
      validRecords++;

      // Low (Hypotension): Systolic < 90 OR Diastolic < 60
      if (sys < 90 || dia < 60) {
        low++;
      }
      // Normal: Systolic < 120 AND Diastolic < 80
      else if (sys < 120 && dia < 80) {
        normal++;
      }
      // Elevated: Systolic 120-129 AND Diastolic < 80
      else if (sys >= 120 && sys <= 129 && dia < 80) {
        elevated++;
      }
      // Stage 1: Systolic 130-139 OR Diastolic 80-89
      else if ((sys >= 130 && sys <= 139) || (dia >= 80 && dia <= 89)) {
        stage1++;
      }
      // Stage 2: Systolic >= 140 OR Diastolic >= 90
      else {
        stage2++;
      }
    }

    // Use validRecords count for percentages, avoid division by zero
    final total = validRecords > 0 ? validRecords : 1;
    return {
      'low': low,
      'normal': normal,
      'elevated': elevated,
      'stage1': stage1,
      'stage2': stage2,
      'lowPercent': (low / total * 100),
      'normalPercent': (normal / total * 100),
      'elevatedPercent': (elevated / total * 100),
      'stage1Percent': (stage1 / total * 100),
      'stage2Percent': (stage2 / total * 100),
    };
  }

  // Helper to format date for chart x-axis
  static String _formatChartDate(Map<String, dynamic> record) {
    final addedTime = record['addedTime'];
    if (addedTime != null) {
      try {
        final timestamp = addedTime is int ? addedTime : int.tryParse(addedTime.toString()) ?? 0;
        if (timestamp > 0) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${months[date.month - 1]} ${date.day}';
        }
      } catch (e) {
        // Ignore
      }
    }
    final timeStr = record['time']?.toString();
    if (timeStr != null && timeStr.isNotEmpty && timeStr != 'null') {
      // Try to extract just date part
      final parts = timeStr.split(' ');
      if (parts.isNotEmpty) return parts[0].length > 6 ? parts[0].substring(0, 6) : parts[0];
    }
    return '';
  }

  // Helper to get trend arrow for PDF (text-based since PDF doesn't support emoji well)
  static String _getPdfTrendArrow(double trend) {
    if (trend > 0.5) return '(up)';
    if (trend < -0.5) return '(down)';
    return '(stable)';
  }

  // Build BP Line Chart using Chart widget
  static pw.Widget _buildBPLineChart(List<Map<String, dynamic>> records) {
    if (records.isEmpty || records.length < 2) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('Not enough data for chart', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    // Take last 20 records for the chart
    final chartRecords = records.take(20).toList().reversed.toList();

    final sysValues = chartRecords.map((r) => (int.tryParse(r['sys']?.toString() ?? '0') ?? 0).toDouble()).toList();
    final diaValues = chartRecords.map((r) => (int.tryParse(r['dia']?.toString() ?? '0') ?? 0).toDouble()).toList();

    // Extract date labels for x-axis
    final dateLabels = chartRecords.map((r) => _formatChartDate(r)).toList();

    // Check if we have valid data (not all zeros)
    final allValues = [...sysValues, ...diaValues];
    final hasValidData = allValues.any((v) => v > 0);
    if (!hasValidData) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No valid BP readings to display', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    final rawMax = allValues.reduce((a, b) => a > b ? a : b);
    final rawMin = allValues.where((v) => v > 0).fold<double>(rawMax, (a, b) => a < b ? a : b);

    // Create clean Y-axis intervals of 25 units for BP charts
    final minValue = ((rawMin - 10) / 25).floor() * 25.0;
    final maxValue = ((rawMax + 10) / 25).ceil() * 25.0;
    final cleanMin = minValue < 50 ? 50.0 : minValue;
    final cleanMax = maxValue < cleanMin + 50 ? cleanMin + 100 : maxValue;

    // Generate Y-axis values at 25-unit intervals
    List<double> yAxisValues = [];
    for (double v = cleanMin; v <= cleanMax; v += 25) {
      yAxisValues.add(v);
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Blood Pressure Trend (Last ${chartRecords.length} Readings)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),
          // Use Chart widget with proper numerical axis
          pw.SizedBox(
            height: 120,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  [for (int i = 0; i < chartRecords.length; i++) i.toDouble()],
                  format: (v) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < dateLabels.length) {
                      return dateLabels[idx];
                    }
                    return '';
                  },
                  textStyle: pw.TextStyle(fontSize: 7),
                ),
                yAxis: pw.FixedAxis(yAxisValues, divisions: true),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: 'Systolic',
                  color: PdfColors.blue,
                  drawLine: true,
                  lineWidth: 2,
                  drawPoints: true,
                  pointSize: 4,
                  data: List.generate(sysValues.length, (i) => pw.PointChartValue(i.toDouble(), sysValues[i])),
                ),
                pw.LineDataSet(
                  legend: 'Diastolic',
                  color: PdfColors.red,
                  drawLine: true,
                  lineWidth: 2,
                  drawPoints: true,
                  pointSize: 4,
                  data: List.generate(diaValues.length, (i) => pw.PointChartValue(i.toDouble(), diaValues[i])),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 15, height: 3, color: PdfColors.blue),
              pw.SizedBox(width: 4),
              pw.Text('Systolic (mmHg)', style: pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 20),
              pw.Container(width: 15, height: 3, color: PdfColors.red),
              pw.SizedBox(width: 4),
              pw.Text('Diastolic (mmHg)', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // Build BP All Readings Chart - shows ALL data points without dates
  static pw.Widget _buildBPAllReadingsChart(List<Map<String, dynamic>> records) {
    if (records.isEmpty || records.length < 2) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('Not enough data for chart', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    // Use ALL records (reversed to show oldest first)
    final allRecords = records.reversed.toList();

    final sysValues = allRecords.map((r) => (int.tryParse(r['sys']?.toString() ?? '0') ?? 0).toDouble()).toList();
    final diaValues = allRecords.map((r) => (int.tryParse(r['dia']?.toString() ?? '0') ?? 0).toDouble()).toList();

    // Check if we have valid data (not all zeros)
    final allValues = [...sysValues, ...diaValues];
    final hasValidData = allValues.any((v) => v > 0);
    if (!hasValidData) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No valid BP readings to display', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    final rawMax = allValues.reduce((a, b) => a > b ? a : b);
    final rawMin = allValues.where((v) => v > 0).fold<double>(rawMax, (a, b) => a < b ? a : b);

    // Create clean Y-axis intervals of 25 units for BP charts
    final minValue = ((rawMin - 10) / 25).floor() * 25.0;
    final maxValue = ((rawMax + 10) / 25).ceil() * 25.0;
    final cleanMin = minValue < 50 ? 50.0 : minValue;
    final cleanMax = maxValue < cleanMin + 50 ? cleanMin + 100 : maxValue;

    // Generate Y-axis values at 25-unit intervals
    List<double> yAxisValues = [];
    for (double v = cleanMin; v <= cleanMax; v += 25) {
      yAxisValues.add(v);
    }

    // Extract date labels for x-axis
    final totalReadings = allRecords.length;
    final dateLabels = allRecords.map((r) => _formatChartDate(r)).toList();

    // Create x-axis with periodic date labels
    List<double> xAxisValues = [];
    if (totalReadings <= 10) {
      xAxisValues = [for (int i = 0; i < totalReadings; i++) i.toDouble()];
    } else {
      // Show labels at intervals (5-6 labels max for readability)
      final interval = (totalReadings / 5).ceil();
      for (int i = 0; i < totalReadings; i += interval) {
        xAxisValues.add(i.toDouble());
      }
      if (!xAxisValues.contains((totalReadings - 1).toDouble())) {
        xAxisValues.add((totalReadings - 1).toDouble());
      }
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'All Blood Pressure Readings ($totalReadings Total)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),
          pw.SizedBox(
            height: 120,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  xAxisValues,
                  format: (v) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < dateLabels.length) {
                      return dateLabels[idx];
                    }
                    return '';
                  },
                  textStyle: pw.TextStyle(fontSize: 7),
                ),
                yAxis: pw.FixedAxis(yAxisValues, divisions: true),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: 'Systolic',
                  color: PdfColors.blue,
                  drawLine: true,
                  lineWidth: 1.5,
                  drawPoints: totalReadings <= 30,
                  pointSize: 3,
                  data: List.generate(sysValues.length, (i) => pw.PointChartValue(i.toDouble(), sysValues[i])),
                ),
                pw.LineDataSet(
                  legend: 'Diastolic',
                  color: PdfColors.red,
                  drawLine: true,
                  lineWidth: 1.5,
                  drawPoints: totalReadings <= 30,
                  pointSize: 3,
                  data: List.generate(diaValues.length, (i) => pw.PointChartValue(i.toDouble(), diaValues[i])),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 15, height: 3, color: PdfColors.blue),
              pw.SizedBox(width: 4),
              pw.Text('Systolic (mmHg)', style: pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 20),
              pw.Container(width: 15, height: 3, color: PdfColors.red),
              pw.SizedBox(width: 4),
              pw.Text('Diastolic (mmHg)', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // Build BP Category Pie Chart using Chart widget
  static pw.Widget _buildBPCategoryPieChart(List<Map<String, dynamic>> records) {
    final distribution = _calculateBPCategoryDistribution(records);

    if (records.isEmpty) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No data for chart', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    final colors = [
      PdfColors.blue300,    // Low (Hypotension)
      PdfColors.green,      // Normal
      PdfColors.amber,      // Elevated (distinct yellow)
      PdfColors.deepOrange, // Stage 1 (distinct orange)
      PdfColors.red,        // Stage 2
    ];

    final categoryNames = ['Low', 'Normal', 'Elevated', 'Stage 1', 'Stage 2'];
    final percentages = [
      distribution['lowPercent'] as double,
      distribution['normalPercent'] as double,
      distribution['elevatedPercent'] as double,
      distribution['stage1Percent'] as double,
      distribution['stage2Percent'] as double,
    ];

    final values = [
      distribution['low'] as int,
      distribution['normal'] as int,
      distribution['elevated'] as int,
      distribution['stage1'] as int,
      distribution['stage2'] as int,
    ];

    // Check if all values are 0 (no valid categorization)
    final totalCategorized = values.reduce((a, b) => a + b);
    if (totalCategorized == 0) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No categorizable BP readings', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BP Readings Distribution',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Pie chart using Chart widget - multiple datasets for each category
              pw.SizedBox(
                width: 130,
                height: 130,
                child: pw.Chart(
                  grid: pw.PieGrid(),
                  datasets: [
                    if (values[0] > 0)
                      pw.PieDataSet(
                        legend: 'Low',
                        value: values[0].toDouble(),
                        color: colors[0],
                        legendPosition: pw.PieLegendPosition.none,
                      ),
                    if (values[1] > 0)
                      pw.PieDataSet(
                        legend: 'Normal',
                        value: values[1].toDouble(),
                        color: colors[1],
                        legendPosition: pw.PieLegendPosition.none,
                      ),
                    if (values[2] > 0)
                      pw.PieDataSet(
                        legend: 'Elevated',
                        value: values[2].toDouble(),
                        color: colors[2],
                        legendPosition: pw.PieLegendPosition.none,
                      ),
                    if (values[3] > 0)
                      pw.PieDataSet(
                        legend: 'Stage 1',
                        value: values[3].toDouble(),
                        color: colors[3],
                        legendPosition: pw.PieLegendPosition.none,
                      ),
                    if (values[4] > 0)
                      pw.PieDataSet(
                        legend: 'Stage 2',
                        value: values[4].toDouble(),
                        color: colors[4],
                        legendPosition: pw.PieLegendPosition.none,
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 15),
              // Legend with colored bars
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: List.generate(5, (i) {
                    return pw.Padding(
                      padding: pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 14,
                            height: 14,
                            decoration: pw.BoxDecoration(
                              color: colors[i],
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  categoryNames[i],
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text(
                                  '${values[i]} readings (${percentages[i].toStringAsFixed(1)}%)',
                                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Readings:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('${records.length}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build Glucose Line Chart using Chart widget
  static pw.Widget _buildGlucoseLineChart(List<Map<String, dynamic>> records) {
    if (records.isEmpty || records.length < 2) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('Not enough data for chart', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    // Take last 20 records for the chart
    final chartRecords = records.take(20).toList().reversed.toList();

    final glucoseValues = chartRecords.map((r) {
      final value = r['glucose']?.toString() ?? r['value']?.toString() ?? '0';
      return (double.tryParse(value) ?? 0);
    }).toList();

    // Extract date labels for x-axis
    final dateLabels = chartRecords.map((r) => _formatChartDate(r)).toList();

    // Check if we have valid data (not all zeros)
    final hasValidData = glucoseValues.any((v) => v > 0);
    if (!hasValidData) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No valid glucose readings to display', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    final rawMax = glucoseValues.reduce((a, b) => a > b ? a : b);
    final rawMin = glucoseValues.where((v) => v > 0).fold<double>(rawMax, (a, b) => a < b ? a : b);

    // Create clean Y-axis intervals of 25 units for glucose charts
    final minValue = ((rawMin - 10) / 25).floor() * 25.0;
    final maxValue = ((rawMax + 10) / 25).ceil() * 25.0;
    final cleanMin = minValue < 25 ? 25.0 : minValue;
    final cleanMax = maxValue < cleanMin + 50 ? cleanMin + 100 : maxValue;

    // Generate Y-axis values at 25-unit intervals
    List<double> yAxisValues = [];
    for (double v = cleanMin; v <= cleanMax; v += 25) {
      yAxisValues.add(v);
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Blood Glucose Trend (Last ${chartRecords.length} Readings)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
          ),
          pw.SizedBox(height: 10),
          // Use Chart widget with proper numerical axis
          pw.SizedBox(
            height: 100,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  [for (int i = 0; i < chartRecords.length; i++) i.toDouble()],
                  format: (v) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < dateLabels.length) {
                      return dateLabels[idx];
                    }
                    return '';
                  },
                  textStyle: pw.TextStyle(fontSize: 7),
                ),
                yAxis: pw.FixedAxis(yAxisValues, divisions: true),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: 'Blood Glucose',
                  color: PdfColors.green700,
                  drawLine: true,
                  lineWidth: 2,
                  drawPoints: true,
                  pointSize: 4,
                  data: List.generate(glucoseValues.length, (i) => pw.PointChartValue(i.toDouble(), glucoseValues[i])),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 15, height: 3, color: PdfColors.green700),
              pw.SizedBox(width: 4),
              pw.Text('Blood Glucose (mg/dL)', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // Build Glucose All Readings Chart - shows ALL data points without dates
  static pw.Widget _buildGlucoseAllReadingsChart(List<Map<String, dynamic>> records) {
    if (records.isEmpty || records.length < 2) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('Not enough data for chart', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    // Use ALL records (reversed to show oldest first)
    final allRecords = records.reversed.toList();

    final glucoseValues = allRecords.map((r) {
      final value = r['glucose']?.toString() ?? r['value']?.toString() ?? '0';
      return (double.tryParse(value) ?? 0);
    }).toList();

    // Check if we have valid data (not all zeros)
    final hasValidData = glucoseValues.any((v) => v > 0);
    if (!hasValidData) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No valid glucose readings to display', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    final rawMax = glucoseValues.reduce((a, b) => a > b ? a : b);
    final rawMin = glucoseValues.where((v) => v > 0).fold<double>(rawMax, (a, b) => a < b ? a : b);

    // Create clean Y-axis intervals of 25 units for glucose charts
    final minValue = ((rawMin - 10) / 25).floor() * 25.0;
    final maxValue = ((rawMax + 10) / 25).ceil() * 25.0;
    final cleanMin = minValue < 25 ? 25.0 : minValue;
    final cleanMax = maxValue < cleanMin + 50 ? cleanMin + 100 : maxValue;

    // Generate Y-axis values at 25-unit intervals
    List<double> yAxisValues = [];
    for (double v = cleanMin; v <= cleanMax; v += 25) {
      yAxisValues.add(v);
    }

    // Extract date labels for x-axis
    final totalReadings = allRecords.length;
    final dateLabels = allRecords.map((r) => _formatChartDate(r)).toList();

    // Create x-axis with periodic date labels
    List<double> xAxisValues = [];
    if (totalReadings <= 10) {
      xAxisValues = [for (int i = 0; i < totalReadings; i++) i.toDouble()];
    } else {
      // Show labels at intervals (5-6 labels max for readability)
      final interval = (totalReadings / 5).ceil();
      for (int i = 0; i < totalReadings; i += interval) {
        xAxisValues.add(i.toDouble());
      }
      if (!xAxisValues.contains((totalReadings - 1).toDouble())) {
        xAxisValues.add((totalReadings - 1).toDouble());
      }
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'All Blood Glucose Readings ($totalReadings Total)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
          ),
          pw.SizedBox(height: 10),
          pw.SizedBox(
            height: 100,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  xAxisValues,
                  format: (v) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < dateLabels.length) {
                      return dateLabels[idx];
                    }
                    return '';
                  },
                  textStyle: pw.TextStyle(fontSize: 7),
                ),
                yAxis: pw.FixedAxis(yAxisValues, divisions: true),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: 'Blood Glucose',
                  color: PdfColors.green700,
                  drawLine: true,
                  lineWidth: 1.5,
                  drawPoints: totalReadings <= 30,
                  pointSize: 3,
                  data: List.generate(glucoseValues.length, (i) => pw.PointChartValue(i.toDouble(), glucoseValues[i])),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 15, height: 3, color: PdfColors.green700),
              pw.SizedBox(width: 4),
              pw.Text('Blood Glucose (mg/dL)', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // Build Weight All Readings Chart (all data points with periodic dates on x-axis)
  static pw.Widget _buildWeightAllReadingsChart(List<Map<String, dynamic>> records) {
    if (records.isEmpty || records.length < 2) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('Not enough data for chart', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    // Use ALL records (reversed to show oldest first)
    final allRecords = records.reversed.toList();

    final weightValues = allRecords.map((r) {
      final value = r['weight']?.toString() ?? r['value']?.toString() ?? '0';
      return (double.tryParse(value) ?? 0);
    }).toList();

    // Check if we have valid data (not all zeros)
    final hasValidData = weightValues.any((v) => v > 0);
    if (!hasValidData) {
      return pw.Container(
        height: 150,
        child: pw.Center(
          child: pw.Text('No valid weight readings to display', style: pw.TextStyle(color: PdfColors.grey600)),
        ),
      );
    }

    final rawMax = weightValues.reduce((a, b) => a > b ? a : b);
    final rawMin = weightValues.where((v) => v > 0).fold<double>(rawMax, (a, b) => a < b ? a : b);

    // Create clean Y-axis intervals of 10 units for weight charts
    final minValue = ((rawMin - 5) / 10).floor() * 10.0;
    final maxValue = ((rawMax + 5) / 10).ceil() * 10.0;
    final cleanMin = minValue < 10 ? 10.0 : minValue;
    final cleanMax = maxValue < cleanMin + 20 ? cleanMin + 40 : maxValue;

    // Generate Y-axis values at 10-unit intervals
    List<double> yAxisValues = [];
    for (double v = cleanMin; v <= cleanMax; v += 10) {
      yAxisValues.add(v);
    }

    // Extract date labels for x-axis
    final totalReadings = allRecords.length;
    final dateLabels = allRecords.map((r) => _formatChartDate(r)).toList();

    // Create x-axis with periodic date labels
    List<double> xAxisValues = [];
    if (totalReadings <= 10) {
      xAxisValues = [for (int i = 0; i < totalReadings; i++) i.toDouble()];
    } else {
      // Show labels at intervals (5-6 labels max for readability)
      final interval = (totalReadings / 5).ceil();
      for (int i = 0; i < totalReadings; i += interval) {
        xAxisValues.add(i.toDouble());
      }
      if (!xAxisValues.contains((totalReadings - 1).toDouble())) {
        xAxisValues.add((totalReadings - 1).toDouble());
      }
    }

    // Get unit from first record
    final unit = records.first['unit']?.toString() ?? 'kg';

    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'All Weight Readings ($totalReadings Total)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900),
          ),
          pw.SizedBox(height: 10),
          pw.SizedBox(
            height: 100,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis(
                  xAxisValues,
                  format: (v) {
                    final idx = v.toInt();
                    if (idx >= 0 && idx < dateLabels.length) {
                      return dateLabels[idx];
                    }
                    return '';
                  },
                  textStyle: pw.TextStyle(fontSize: 7),
                ),
                yAxis: pw.FixedAxis(yAxisValues, divisions: true),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: 'Weight',
                  color: PdfColors.orange700,
                  drawLine: true,
                  lineWidth: 1.5,
                  drawPoints: totalReadings <= 30,
                  pointSize: 3,
                  data: List.generate(weightValues.length, (i) => pw.PointChartValue(i.toDouble(), weightValues[i])),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(width: 15, height: 3, color: PdfColors.orange700),
              pw.SizedBox(width: 4),
              pw.Text('Weight ($unit)', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // Send comprehensive BP insights report with all four alert types
  static Future<bool> sendComprehensiveBPReport({
    required String recipientEmail,
    required String recipientName,
    required List<Map<String, dynamic>> bpRecords,
    List<Map<String, dynamic>>? glucoseRecords,
    List<Map<String, dynamic>>? weightRecords,
    String? dateRange,
    int? totalMeasurements,
    double? systolicTrend,
    double? diastolicTrend,
    int? systolicThreshold,
    int? diastolicThreshold,
  }) async {
    try {
      // Generate PDF and upload to Firebase Storage
      String? pdfDownloadUrl;

      if (bpRecords.isNotEmpty) {
        pdfDownloadUrl = await _generateAndUploadPDF(
          recipientName: recipientName,
          bpRecords: bpRecords,
          glucoseRecords: glucoseRecords,
          weightRecords: weightRecords,
          dateRange: dateRange,
          systolicThreshold: systolicThreshold,
          diastolicThreshold: diastolicThreshold,
          systolicTrend: systolicTrend,
          diastolicTrend: diastolicTrend,
        );
      }

      final subject = 'Blood Pressure Alerts Report';
      final htmlContent = _getComprehensiveBPReportHTML(
        recipientName,
        bpRecords,
        dateRange,
        totalMeasurements,
        systolicTrend,
        diastolicTrend,
        systolicThreshold,
        diastolicThreshold,
        pdfDownloadUrl,
      );
      final textContent = _getComprehensiveBPReportText(
        recipientName,
        bpRecords,
        dateRange,
        totalMeasurements,
        systolicTrend,
        diastolicTrend,
        systolicThreshold,
        diastolicThreshold,
        pdfDownloadUrl,
      );

      return await sendEmail(
        recipientEmail: recipientEmail,
        subject: subject,
        htmlContent: htmlContent,
        textContent: textContent,
        recipientName: recipientName,
      );
    } catch (e) {
      print('Error in sendComprehensiveBPReport: $e');
      return false;
    }
  }

  static String _sanitizePdfText(String text) {
    return text
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2026', '...')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2022', '-')
        .replaceAll('\u25CF', '-')
        .replaceAll('\u2212', '-')
        // Helvetica cannot draw emoji or other Unicode (e.g. thumbs up).
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '');
  }

  /// Helvetica cannot split one tall Text across pages, so break copy into
  /// short blocks MultiPage can paginate.
  static List<pw.Widget> _pdfTextBlocks(String text) {
    final sanitized = _sanitizePdfText(text).trim();
    if (sanitized.isEmpty) {
      return [pw.Text(' ', style: const pw.TextStyle(fontSize: 11))];
    }

    final blocks = <pw.Widget>[];
    for (final rawLine in sanitized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        blocks.add(pw.SizedBox(height: 6));
        continue;
      }
      const chunkSize = 400;
      for (var i = 0; i < line.length; i += chunkSize) {
        final end = (i + chunkSize < line.length) ? i + chunkSize : line.length;
        blocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              line.substring(i, end),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        );
      }
    }
    return blocks;
  }

  static Future<bool> sendAIHealthReport({
    required String recipientEmail,
    required String recipientName,
    required String dateRange,
    required String reportText,
    required List<Map<String, String>> followUps,
  }) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Text(
                'VITALS101 AI Health Insights',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(_sanitizePdfText('Prepared for: $recipientName')),
              pw.Text(_sanitizePdfText('Period: $dateRange')),
              pw.SizedBox(height: 12),
              pw.Text(
                'This is not medical advice. It is based only on the data you logged in Vitals.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'AI report',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ..._pdfTextBlocks(reportText),
            ];

            if (followUps.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 18));
              widgets.add(
                pw.Text(
                  'Follow-up questions',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              for (final turn in followUps) {
                final label = turn['role'] == 'user' ? 'You' : 'AI';
                widgets.add(pw.SizedBox(height: 10));
                widgets.addAll(
                  _pdfTextBlocks('$label: ${turn['text'] ?? ''}'),
                );
              }
            }

            return widgets;
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final fileName =
          'Vitals101_AI_Health_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      String? downloadUrl;
      try {
        final ref = FirebaseStorage.instance.ref().child('pdf_reports/$fileName');
        await ref.putFile(file);
        downloadUrl = await ref.getDownloadURL();
      } catch (e) {
        print('AI PDF upload failed, sending as email attachment only: $e');
      }

      final credentials = await _getEmailCredentials();
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: credentials['username']!,
        password: credentials['password']!,
        allowInsecure: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = Address(credentials['username']!, 'Vitals 101 Team')
        ..recipients.add(recipientEmail)
        ..subject = 'Your Vitals 101 AI Health Insights'
        ..text = '''
Hello $recipientName,

Please find your AI health insights report for $dateRange attached as a PDF.

This is not medical advice. It is based only on the data you logged in Vitals.
${downloadUrl != null ? '\nDownload link: $downloadUrl\n' : ''}
'''
        ..html = '''
<p>Hello $recipientName,</p>
<p>Please find your AI health insights report for <b>$dateRange</b> attached as a PDF.</p>
<p>This is not medical advice. It is based only on the data you logged in Vitals.</p>
${downloadUrl != null ? '<p><a href="$downloadUrl">Download PDF</a></p>' : ''}
'''
        ..attachments = [
          FileAttachment(file, fileName: 'Vitals101_AI_Health_Report.pdf'),
        ];

      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('Error sending AI health report: $e');
      return false;
    }
  }

  // Helper method to strip HTML tags for text content
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[^;]+;'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _getWelcomeEmailHTML(String name) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to Vitals 101</title>
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
                letter-spacing: 1px;
            }
            .welcome-text {
                font-size: 24px;
                margin-bottom: 20px;
            }
            .content {
                margin-bottom: 30px;
            }
            .feature {
                background-color: #f8f9fa;
                padding: 15px;
                margin: 10px 0;
                border-left: 4px solid #005EA6;
                border-radius: 5px;
            }
            .feature h3 {
                margin: 0 0 10px 0;
                color: #005EA6;
            }
            .cta-button {
                display: inline-block;
                background-color: #005EA6;
                color: white;
                padding: 15px 30px;
                text-decoration: none;
                border-radius: 25px;
                font-weight: bold;
                text-align: center;
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
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">
  <img src="https://firebasestorage.googleapis.com/v0/b/vh-1-5ed7e.appspot.com/o/appicon.jpg?alt=media&token=ac2252b1-6153-4752-b3d5-96a59a8e4c99" 
       alt="Vitals" 
       width="40" 
       height="40" 
       style="vertical-align:middle; border-radius:4px;">
  Vitals 101
</div>
                <div class="welcome-text">Welcome to Your Health Journey!</div>
            </div>
            
            <div class="content">
                <h2>Hello $name! 👋</h2>
                
                <p>We're thrilled to have you join the Vitals 101 family! Your health and well-being are our top priorities, and we're here to support you every step of the way.</p>
                
                <h3>What you can do with Vitals 101:</h3>
                
                <div class="feature">
                    <h3>📊 Track Your Vitals</h3>
                    <p>Monitor your blood pressure, blood glucose, weight, and other important health metrics with our easy-to-use tracking system.</p>
                </div>
                
                <div class="feature">
                    <h3>🔔 Smart Alerts</h3>
                    <p>Get personalized alerts when your readings exceed safe thresholds, helping you stay on top of your health.</p>
                </div>
                
                <div class="feature">
                    <h3>💊 Medicine Reminders</h3>
                    <p>Never miss a dose with our intelligent medication reminder system that adapts to your schedule.</p>
                </div>
                
                <div class="feature">
                    <h3>👨‍⚕️ Doctor Consultations</h3>
                    <p>Connect with healthcare professionals for expert advice and consultations right from the app.</p>
                </div>
                
                <div class="feature">
                    <h3>📈 Health Insights</h3>
                    <p>View detailed BP analysis and trends to understand your health patterns and make informed decisions.</p>
                </div>
                
            
                
                <p><strong>Getting Started Tips:</strong></p>
                <ul>
                    <li>Add your first vital tracker from the menu</li>
                    <li>Set up medication reminders if needed</li>
                    <li>Enable notifications for the best experience</li>
                    <li>Explore the consultation feature for expert advice</li>
                </ul>
            </div>
            
            <div class="footer">
                <p>Thank you for choosing Vitals 101 for your health management needs.</p>
                <p>If you have any questions, feel free to reach out to our support team.</p>
                <p><strong>Stay healthy, stay informed! 💙</strong></p>
                <br>
                <p>Best regards,<br>The Vitals 101 Team</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  static String _getWelcomeEmailText(String name) {
    return '''
Welcome to Vitals 101! 🎉

Hello $name!

We're thrilled to have you join the Vitals 101 family! Your health and well-being are our top priorities, and we're here to support you every step of the way.

What you can do with Vitals 101:

📊 Track Your Vitals
Monitor your blood pressure, blood glucose, weight, and other important health metrics with our easy-to-use tracking system.

🔔 Smart Alerts
Get personalized alerts when your readings exceed safe thresholds, helping you stay on top of your health.

💊 Medicine Reminders
Never miss a dose with our intelligent medication reminder system that adapts to your schedule.

👨‍⚕️ Doctor Consultations
Connect with healthcare professionals for expert advice and consultations right from the app.

📈 Health Insights
View detailed BP analysis and trends to understand your health patterns and make informed decisions.

Getting Started Tips:
• Add your first vital tracker from the menu
• Set up medication reminders if needed
• Enable notifications for the best experience
• Explore the consultation feature for expert advice

Thank you for choosing Vitals 101 for your health management needs.
If you have any questions, feel free to reach out to our support team.

Stay healthy, stay informed! 💙

Best regards,
The Vitals 101 Team
    ''';
  }

  static String _getReportEmailHTML(
    String name,
    String reportType,
    String reportData,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Blood Pressure Alerts Report</title>
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
                letter-spacing: 1px;
            }
            .report-title {
                font-size: 24px;
                margin-bottom: 20px;
            }
            .content {
                margin-bottom: 30px;
            }
            .report-data {
                background-color: #f8f9fa;
                padding: 20px;
                margin: 20px 0;
                border-left: 4px solid #005EA6;
                border-radius: 5px;
                font-family: monospace;
                white-space: pre-wrap;
            }
            .footer {
                text-align: center;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                color: #666;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">
  <img src="https://firebasestorage.googleapis.com/v0/b/vh-1-5ed7e.appspot.com/o/appicon.jpg?alt=media&token=ac2252b1-6153-4752-b3d5-96a59a8e4c99" 
       alt="Vitals" 
       width="40" 
       height="40" 
       style="vertical-align:middle; border-radius:4px;">
  Vitals 101
</div>
                <div class="report-title">Blood Pressure Alerts Report</div>
            </div>
            
            <div class="content">
                <h2>Hello $name! 👋</h2>
                
                <p>Please find your $reportType report below. This report contains important health insights based on your recent vital measurements.</p>
                
                <div class="report-data">$reportData</div>
                
                <p><strong>Important Notes:</strong></p>
                <ul>
                    <li>This report is generated based on your Blood Pressure data</li>
                    <li>Please consult with your healthcare provider for medical advice by sharing this report with them.</li>
                    <li>Keep track of your health trends over time</li>
                    <li>Contact us if you have any questions about this report</li>
                </ul>
            </div>
            
            <div class="footer">
                <p>Thank you for using Vitals 101 for your health monitoring.</p>
                <p>Stay healthy, stay informed! 💙</p>
                <br>
                <p>Best regards,<br>The Vitals 101 Team</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  static String _getReportEmailText(
    String name,
    String reportType,
    String reportData,
  ) {
    return '''
Blood Pressure Alerts Report

Hello $name!

Please find your $reportType report below. This report contains important health insights based on your recent vital measurements.

Report Data:
$reportData

Important Notes:
• This report is generated based on your Blood Pressure data
• Please consult with your healthcare provider for medical advice by sharing this report with them.
• Keep track of your health trends over time
• Contact us if you have any questions about this report

Thank you for using Vitals 101 for your health monitoring.
Stay healthy, stay informed! 💙

Best regards,
The Vitals 101 Team
    ''';
  }

  // Generate HTML for BP records email with table
  static String _getBPRecordsEmailHTML(
    String name,
    List<Map<String, dynamic>> bpRecords,
    String? dateRange,
  ) {
    final tableRows = _generateBPTableRows(bpRecords);
    final dateRangeText = dateRange ?? 'Recent records';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Blood Pressure Alerts Report</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
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
                letter-spacing: 1px;
            }
            .report-title {
                font-size: 24px;
                margin-bottom: 20px;
            }
            .content {
                margin-bottom: 30px;
            }
            .summary-stats {
                display: flex;
                justify-content: space-around;
                margin: 20px 0;
                flex-wrap: wrap;
            }
            .stat-card {
                background-color: #f8f9fa;
                padding: 15px;
                border-radius: 8px;
                text-align: center;
                margin: 5px;
                min-width: 120px;
                border-left: 4px solid #005EA6;
            }
            .stat-value {
                font-size: 24px;
                font-weight: bold;
                color: #005EA6;
            }
            .stat-label {
                font-size: 12px;
                color: #666;
                margin-top: 5px;
            }
            .records-table {
                width: 100%;
                border-collapse: collapse;
                margin: 20px 0;
                background-color: white;
                border-radius: 8px;
                overflow: hidden;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .records-table th {
                background-color: #005EA6;
                color: white;
                padding: 12px;
                text-align: left;
                font-weight: bold;
            }
            .records-table td {
                padding: 12px;
                border-bottom: 1px solid #eee;
            }
            .records-table tr:nth-child(even) {
                background-color: #f8f9fa;
            }
            .records-table tr:hover {
                background-color: #e3f2fd;
            }
            .bp-value {
                font-weight: bold;
                font-size: 16px;
            }
            .systolic {
                color: #d32f2f;
            }
            .diastolic {
                color: #1976d2;
            }
            .status-normal {
                color: #4caf50;
                font-weight: bold;
            }
            .status-high {
                color: #f44336;
                font-weight: bold;
            }
            .date-time {
                color: #666;
                font-size: 14px;
            }
            .footer {
                text-align: center;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                color: #666;
                font-size: 14px;
            }
            .no-records {
                text-align: center;
                padding: 40px;
                color: #666;
                font-style: italic;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">
  <img src="https://firebasestorage.googleapis.com/v0/b/vh-1-5ed7e.appspot.com/o/appicon.jpg?alt=media&token=ac2252b1-6153-4752-b3d5-96a59a8e4c99" 
       alt="Vitals" 
       width="40" 
       height="40" 
       style="vertical-align:middle; border-radius:4px;">
  Vitals 101
</div>
                <div class="report-title">Blood Pressure Alerts Report</div>
            </div>
            
            <div class="content">
                <h2>Hello $name! 👋</h2>
                
                <p>Here are your blood pressure records for $dateRangeText. This report shows all your BP measurements in an organized table format for easy review.</p>
                
                ${_generateSummaryStats(bpRecords)}
                
                ${bpRecords.isEmpty ? '<div class="no-records">No blood pressure records found for the selected period.</div>' : '''
                    <h3>📊 Your Blood Pressure Records</h3>
                    <table class="records-table">
                        <thead>
                            <tr>
                                <th>Date & Time</th>
                                <th>Systolic (mmHg)</th>
                                <th>Diastolic (mmHg)</th>
                                <th>Pulse (bpm)</th>
                                <th>Status</th>
                                <th>Notes</th>
                            </tr>
                        </thead>
                        <tbody>
                            $tableRows
                        </tbody>
                    </table>
                    '''}
                
                <div style="margin-top: 30px; padding: 20px; background-color: #e3f2fd; border-radius: 8px;">
                    <h4>📋 Understanding your Blood Pressure Alert Numbers</h4>
                    <ul>
                        <li>Average Blood Pressure: This is an arithmetic average of all your BP measurements for the period.</li>
                        <li>Time-in-Target range is the percentage of time your blood pressure stays within a defined healthy target range. (Sys < 120and Dia < 80)</li>
                        <li>MAP is a calculation that checks if there is enough blood flow and pressure to supply blood to all your major organs.</li>
                        <li>Blood Pressure Trend Indicator detects trends in your blood pressure measurements, such as if it's generally increasing or decreasing and by what amount. For example, Systolic: 13.2↗️ indicates an overall increase in Systolic BP by 13mmHg and Diastolic: 9.4↗️ indicates an overall increase in your Diastolic BP by 9mmHg for the period under review.</li>
                    </ul>
                </div>
                
                <p><strong>Important Notes:</strong></p>
                <ul>
                    <li>This report is generated based on your Blood Pressure data</li>
                    <li>Please consult with your healthcare provider for medical advice by sharing this report with them.</li>
                    <li>Keep track of your health trends over time</li>
                    <li>Contact us if you have any questions about this report</li>
                </ul>
            </div>
            
            <div class="footer">
                <p>Thank you for using Vitals 101 for your health monitoring.</p>
                <p>Stay healthy, stay informed! 💙</p>
                <br>
                <p>Best regards,<br>The Vitals 101 Team</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Generate text version for BP records email
  static String _getBPRecordsEmailText(
    String name,
    List<Map<String, dynamic>> bpRecords,
    String? dateRange,
  ) {
    final dateRangeText = dateRange ?? 'Recent records';
    final summary = _generateSummaryStatsText(bpRecords);

    String recordsText = '';
    if (bpRecords.isNotEmpty) {
      recordsText = '\nYour Blood Pressure Records:\n';
      recordsText += 'Date & Time\t\tSystolic\tDiastolic\tPulse\tStatus\n';
      recordsText += '${'=' * 70}\n';

      for (var record in bpRecords) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          record['addedTime'] ?? 0,
        );
        final dateStr =
            '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        final sys = record['sys'] ?? '0';
        final dia = record['dia'] ?? '0';
        final pulse = record['pulse'] ?? '-';
        final status = _getBPStatus(
          int.tryParse(sys) ?? 0,
          int.tryParse(dia) ?? 0,
        );

        recordsText += '$dateStr\t\t$sys\t\t$dia\t\t$pulse\t$status\n';
      }
    } else {
      recordsText =
          '\nNo blood pressure records found for the selected period.';
    }

    return '''
Blood Pressure Alerts Report

Hello $name!

Here are your blood pressure records for $dateRangeText. This report shows all your BP measurements in an organized format for easy review.

$summary

$recordsText

Understanding your Blood Pressure Alert Numbers:
• Normal: Systolic < 120 mmHg and Diastolic < 80 mmHg
• Elevated: Systolic 120-129 mmHg and Diastolic < 80 mmHg
• High Stage 1: Systolic 130-139 mmHg or Diastolic 80-89 mmHg
• High Stage 2: Systolic ≥ 140 mmHg or Diastolic ≥ 90 mmHg

Important Notes:
• This report is generated based on your Blood Pressure data
• Please consult with your healthcare provider for medical advice by sharing this report with them.
• Keep track of your health trends over time
• Contact us if you have any questions about this report

Thank you for using Vitals 101 for your health monitoring.
Stay healthy, stay informed! 💙

Best regards,
The Vitals 101 Team
    ''';
  }

  // Helper functions for BP records table generation
  static String _generateBPTableRows(List<Map<String, dynamic>> bpRecords) {
    if (bpRecords.isEmpty) return '';

    return bpRecords.map((record) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        record['addedTime'] ?? 0,
      );
      final dateStr = '${date.day}/${date.month}/${date.year}';
      final timeStr =
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      final sys = record['sys'] ?? '0';
      final dia = record['dia'] ?? '0';
      final pulse = record['pulse'] ?? '-';
      final status = _getBPStatus(
        int.tryParse(sys) ?? 0,
        int.tryParse(dia) ?? 0,
      );
      final statusClass = _getBPStatusClass(
        int.tryParse(sys) ?? 0,
        int.tryParse(dia) ?? 0,
      );

      return '''
        <tr>
          <td class="date-time">
            <div>$dateStr</div>
            <div style="font-size: 12px; color: #999;">$timeStr</div>
          </td>
          <td><span class="bp-value systolic">$sys</span></td>
          <td><span class="bp-value diastolic">$dia</span></td>
          <td>$pulse</td>
          <td><span class="$statusClass">$status</span></td>
          <td>-</td>
        </tr>
      ''';
    }).join('');
  }

  static String _generateSummaryStats(List<Map<String, dynamic>> bpRecords) {
    if (bpRecords.isEmpty) {
      return '<div class="no-records">No records available for summary statistics.</div>';
    }

    final sysValues =
        bpRecords.map((r) => int.tryParse(r['sys'] ?? '0') ?? 0).toList();
    final diaValues =
        bpRecords.map((r) => int.tryParse(r['dia'] ?? '0') ?? 0).toList();

    final avgSys = sysValues.reduce((a, b) => a + b) / sysValues.length;
    final avgDia = diaValues.reduce((a, b) => a + b) / diaValues.length;
    final maxSys = sysValues.reduce((a, b) => a > b ? a : b);
    final maxDia = diaValues.reduce((a, b) => a > b ? a : b);
    final minSys = sysValues.reduce((a, b) => a < b ? a : b);
    final minDia = diaValues.reduce((a, b) => a < b ? a : b);

    final normalCount = bpRecords.where((r) {
      final sys = int.tryParse(r['sys'] ?? '0') ?? 0;
      final dia = int.tryParse(r['dia'] ?? '0') ?? 0;
      return sys < 120 && dia < 80;
    }).length;

    return '''
      <div class="summary-stats">
        <div class="stat-card">
          <div class="stat-value">${avgSys.toStringAsFixed(0)}</div>
          <div class="stat-label">Avg Systolic</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${avgDia.toStringAsFixed(0)}</div>
          <div class="stat-label">Avg Diastolic</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">$maxSys/$minSys</div>
          <div class="stat-label">Max/Min Systolic</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">$maxDia/$minDia</div>
          <div class="stat-label">Max/Min Diastolic</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">$normalCount</div>
          <div class="stat-label">Normal Readings</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${bpRecords.length}</div>
          <div class="stat-label">Total Readings</div>
        </div>
      </div>
    ''';
  }

  static String _generateSummaryStatsText(
    List<Map<String, dynamic>> bpRecords,
  ) {
    if (bpRecords.isEmpty) {
      return 'No records available for summary statistics.';
    }

    final sysValues =
        bpRecords.map((r) => int.tryParse(r['sys'] ?? '0') ?? 0).toList();
    final diaValues =
        bpRecords.map((r) => int.tryParse(r['dia'] ?? '0') ?? 0).toList();

    final avgSys = sysValues.reduce((a, b) => a + b) / sysValues.length;
    final avgDia = diaValues.reduce((a, b) => a + b) / diaValues.length;
    final maxSys = sysValues.reduce((a, b) => a > b ? a : b);
    final maxDia = diaValues.reduce((a, b) => a > b ? a : b);
    final minSys = sysValues.reduce((a, b) => a < b ? a : b);
    final minDia = diaValues.reduce((a, b) => a < b ? a : b);

    final normalCount = bpRecords.where((r) {
      final sys = int.tryParse(r['sys'] ?? '0') ?? 0;
      final dia = int.tryParse(r['dia'] ?? '0') ?? 0;
      return sys < 120 && dia < 80;
    }).length;

    return '''
Summary Statistics:
• Average Systolic: ${avgSys.toStringAsFixed(0)} mmHg
• Average Diastolic: ${avgDia.toStringAsFixed(0)} mmHg
• Highest Systolic: $maxSys mmHg
• Lowest Systolic: $minSys mmHg
• Highest Diastolic: $maxDia mmHg
• Lowest Diastolic: $minDia mmHg
• Normal Readings: $normalCount out of ${bpRecords.length}
    ''';
  }

  static String _getBPStatus(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) {
      return 'Normal';
    } else if (systolic >= 120 && systolic < 130 && diastolic < 80) {
      return 'Elevated';
    } else if ((systolic >= 130 && systolic < 140) ||
        (diastolic >= 80 && diastolic < 90)) {
      return 'High Stage 1';
    } else if (systolic >= 140 || diastolic >= 90) {
      return 'High Stage 2';
    } else {
      return 'Unknown';
    }
  }

  static String _getBPStatusClass(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) {
      return 'status-normal';
    } else {
      return 'status-high';
    }
  }

  // Generate comprehensive BP insights report HTML
  static String _getComprehensiveBPReportHTML(
    String name,
    List<Map<String, dynamic>> bpRecords,
    String? dateRange,
    int? totalMeasurements,
    double? systolicTrend,
    double? diastolicTrend,
    int? systolicThreshold,
    int? diastolicThreshold,
    String? pdfDownloadUrl,
  ) {
    final dateRangeText = dateRange ?? 'Recent records';
    final insights = _calculateBPInsights(
      bpRecords,
      systolicTrend,
      diastolicTrend,
      systolicThreshold,
      diastolicThreshold,
    );

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Blood Pressure Alerts Report</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
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
                letter-spacing: 1px;
            }
            .report-title {
                font-size: 24px;
                margin-bottom: 20px;
            }
            .report-subtitle {
                font-size: 14px;
                opacity: 0.9;
                margin-bottom: 10px;
            }
            .content {
                margin-bottom: 30px;
            }
            .insights-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 20px;
                margin: 20px 0;
            }
            .insight-card {
                background-color: white;
                border-radius: 8px;
                padding: 20px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                border-left: 4px solid;
            }
            .card-header {
                font-size: 16px;
                font-weight: bold;
                margin-bottom: 15px;
                padding: 8px 12px;
                border-radius: 4px;
                color: white;
            }
            .card-blue { border-left-color: #2196F3; }
            .card-blue .card-header { background-color: #2196F3; }
            .card-green { border-left-color: #4CAF50; }
            .card-green .card-header { background-color: #4CAF50; }
            .card-yellow { border-left-color: #FF9800; }
            .card-yellow .card-header { background-color: #FF9800; }
            .card-grey { border-left-color: #9E9E9E; }
            .card-grey .card-header { background-color: #9E9E9E; }
            .metric-value {
                font-size: 24px;
                font-weight: bold;
                margin: 10px 0;
            }
            .metric-label {
                font-size: 14px;
                color: #666;
                margin-bottom: 5px;
            }
            .target-range {
                font-size: 12px;
                color: #888;
                margin-top: 5px;
            }
            .trend-item {
                display: flex;
                justify-content: space-between;
                margin: 5px 0;
            }
            .trend-label {
                font-size: 18px;
                font-weight: bold;
            }
            .trend-value {
                font-weight: bold;
                font-size: 18px;
            }
            .trend-stable { color: #4CAF50; }
            .trend-increasing { color: #F44336; }
            .trend-decreasing { color: #2196F3; }
            .footer {
                text-align: center;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                color: #666;
                font-size: 14px;
            }
            .no-data {
                text-align: center;
                color: #666;
                font-style: italic;
                padding: 40px;
            }
            .measurements-info {
                background-color: #f8f9fa;
                padding: 12px 16px;
                border-radius: 8px;
                border-left: 4px solid #005EA6;
                margin: 16px 0;
                font-size: 16px;
                color: #333;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">
  <img src="https://firebasestorage.googleapis.com/v0/b/vh-1-5ed7e.appspot.com/o/appicon.jpg?alt=media&token=ac2252b1-6153-4752-b3d5-96a59a8e4c99" 
       alt="Vitals" 
       width="40" 
       height="40" 
       style="vertical-align:middle; border-radius:4px;">
  Vitals 101
</div>
                <div class="report-title">Blood Pressure Alerts Report</div>
                <div class="report-subtitle">Blood Pressure Insights: ${DateTime.now().millisecondsSinceEpoch}</div>
            </div>
            
            <div class="content">
                <h2>Hello $name! 👋</h2>
                
                <p>Here are your comprehensive blood pressure insights for $dateRangeText. This report includes all four key metrics to help you understand your blood pressure patterns.</p>
                
                <div class="measurements-info">
                    <strong>Total BP Measurements for this Report period: ${totalMeasurements ?? insights['totalMeasurements']}</strong>
                </div>
                
                ${bpRecords.isEmpty ? '<div class="no-data">No blood pressure records found for the selected period.</div>' : '''
                    <div class="insights-grid">
                        <!-- Blood Pressure Averages Card -->
                        <div class="insight-card card-blue">
                            <div class="card-header">Blood Pressure Averages</div>
                            <div class="metric-label">Average Systolic:</div>
                            <div class="metric-value" style="color: #2196F3;">${insights['avgSystolic']} mmHg</div>
                            <div class="metric-label">Average Diastolic:</div>
                            <div class="metric-value" style="color: #2196F3;">${insights['avgDiastolic']} mmHg</div>
                        </div>

                        <!-- Highest BP Card -->
                        <div class="insight-card" style="border-left-color: #F44336;">
                            <div class="card-header" style="background-color: #F44336;">Highest Blood Pressure</div>
                            <div class="metric-label">Highest Systolic:</div>
                            <div class="metric-value" style="color: #F44336;">${insights['highestSystolic']} mmHg</div>
                            <div class="metric-label">Highest Diastolic:</div>
                            <div class="metric-value" style="color: #F44336;">${insights['highestDiastolic']} mmHg</div>
                        </div>

                        <!-- Lowest BP Card -->
                        <div class="insight-card" style="border-left-color: #00BCD4;">
                            <div class="card-header" style="background-color: #00BCD4;">Lowest Blood Pressure</div>
                            <div class="metric-label">Lowest Systolic:</div>
                            <div class="metric-value" style="color: #00BCD4;">${insights['lowestSystolic']} mmHg</div>
                            <div class="metric-label">Lowest Diastolic:</div>
                            <div class="metric-value" style="color: #00BCD4;">${insights['lowestDiastolic']} mmHg</div>
                        </div>

                        <!-- Time in Target Range Card -->
                        <div class="insight-card card-green">
                            <div class="card-header">Time in Target Range</div>
                            <div class="metric-value" style="color: #4CAF50;">${insights['timeInTarget']}%</div>
                            <div class="target-range">(Sys < ${systolicThreshold ?? 120} and Dia < ${diastolicThreshold ?? 80})</div>
                        </div>
                        <!-- Mean Arterial Pressure Card -->
                        <div class="insight-card card-yellow">
                            <div class="card-header">Average Mean Arterial Pressure (MAP)</div>
                            <div class="metric-value" style="color: #FF9800;">${insights['meanArterialPressure']} mmHg</div>
                        </div>

                        <!-- BP Trend Card -->
                        <div class="insight-card card-grey">
                            <div class="card-header">BP Trend</div>
                            <div class="trend-item">
                                <span class="trend-label">Systolic:</span>
                                <span class="trend-value trend-${insights['systolicTrend']}" style="font-size: 18px;">${(double.parse(insights['systolicValue'])).abs().toStringAsFixed(2)} <span style="font-size: 16px;">${_getTrendArrow(insights['systolicTrend'])}</span></span>
                            </div>
                            <div class="trend-item">
                                <span class="trend-label">Diastolic:</span>
                                <span class="trend-value trend-${insights['diastolicTrend']}" style="font-size: 18px;">${(double.parse(insights['diastolicValue'])).abs().toStringAsFixed(2)} <span style="font-size: 16px;">${_getTrendArrow(insights['diastolicTrend'])}</span></span>
                            </div>
                        </div>
                    </div>
                    '''}

                ${pdfDownloadUrl != null ? '''
                <div style="margin-top: 30px; padding: 20px; background-color: #e8f5e9; border-radius: 8px; border-left: 4px solid #4caf50; text-align: center;">
                    <h4 style="margin-top: 0; color: #2e7d32;">📄 Your Comprehensive PDF Report is Ready!</h4>
                    <p style="margin-bottom: 20px; color: #555;">Click the button below to download your detailed health report with all Blood Pressure, Glucose, and Weight data.</p>
                    <a href="$pdfDownloadUrl" style="display: inline-block; background-color: #4caf50; color: white; padding: 15px 30px; text-decoration: none; border-radius: 25px; font-weight: bold; font-size: 16px; box-shadow: 0 2px 4px rgba(0,0,0,0.2);">
                        📥 Download PDF Report
                    </a>
                </div>
                ''' : ''}

                <div style="margin-top: 30px; padding: 20px; background-color: #e3f2fd; border-radius: 8px;">
                    <h4>📋 Understanding your Blood Pressure Alert Numbers</h4>
                    <ul>
                        <li> Average Blood Pressure: This is an arithmetic average of all your BP measurements for the period.</li>
                        <li> Time-in-Target range is the percentage of time your blood pressure stays within a defined healthy target range. (Sys < 120and Dia < 80)</li>
                        <li> MAP is a calculation that checks if there is enough blood flow and pressure to supply blood to all your major organs.</li>
                        <li> Blood Pressure Trend Indicator detects trends in your blood pressure measurements, such as if it's generally increasing or decreasing and by what amount. For example, Systolic: 13.2↗️ indicates an overall increase in Systolic BP by 13mmHg and Diastolic: 9.4↗️ indicates an overall increase in your Diastolic BP by 9mmHg for the period under review.</li>
                    </ul>
                </div>
                
                <p><strong>Important Notes:</strong></p>
                <ul>
                    <li>This report is generated based on your Blood Pressure data</li>
                    <li>Please consult with your healthcare provider for medical advice by sharing this report with them.</li>
                    <li>Keep track of your health trends over time</li>
                    <li>Contact us if you have any questions about this report</li>
                </ul>
            </div>
            
            <div class="footer">
                <p>Thank you for using Vitals 101 for your health monitoring.</p>
                <p>Stay healthy, stay informed! 💙</p>
                <br>
                <p>Best regards,<br>The Vitals 101 Team</p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Calculate comprehensive BP insights
  static Map<String, dynamic> _calculateBPInsights(
    List<Map<String, dynamic>> bpRecords,
    double? systolicTrend,
    double? diastolicTrend,
    int? systolicThreshold,
    int? diastolicThreshold,
  ) {
    if (bpRecords.isEmpty) {
      return {
        'avgSystolic': '0',
        'avgDiastolic': '0',
        'timeInTarget': '0',
        'meanArterialPressure': '0',
        'systolicTrend': 'stable',
        'diastolicTrend': 'stable',
        'systolicValue': '0',
        'diastolicValue': '0',
        'totalMeasurements': '0',
        'highestSystolic': '0',
        'highestDiastolic': '0',
        'lowestSystolic': '0',
        'lowestDiastolic': '0',
      };
    }

    final sysValues = bpRecords
        .map((r) => (int.tryParse(r['sys'] ?? '0') ?? 0).toDouble())
        .toList();
    final diaValues = bpRecords
        .map((r) => (int.tryParse(r['dia'] ?? '0') ?? 0).toDouble())
        .toList();

    // Calculate averages
    final avgSys = sysValues.reduce((a, b) => a + b) / sysValues.length;
    final avgDia = diaValues.reduce((a, b) => a + b) / diaValues.length;

    // Calculate highest and lowest
    final highestSys = sysValues.reduce((a, b) => a > b ? a : b);
    final highestDia = diaValues.reduce((a, b) => a > b ? a : b);

    // Handle edge case: if all values are 0, set lowest to 0
    final validSysValues = sysValues.where((v) => v > 0);
    final validDiaValues = diaValues.where((v) => v > 0);
    final lowestSys = validSysValues.isNotEmpty
        ? validSysValues.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final lowestDia = validDiaValues.isNotEmpty
        ? validDiaValues.reduce((a, b) => a < b ? a : b)
        : 0.0;

    // Calculate time in target range using dynamic thresholds
    final sysThreshold = systolicThreshold ?? 120;
    final diaThreshold = diastolicThreshold ?? 80;
    final inTargetCount = bpRecords.where((r) {
      final sys = int.tryParse(r['sys'] ?? '0') ?? 0;
      final dia = int.tryParse(r['dia'] ?? '0') ?? 0;
      return sys < sysThreshold && dia < diaThreshold;
    }).length;
    final timeInTarget = ((inTargetCount / bpRecords.length) * 100).round();

    // Calculate Mean Arterial Pressure (MAP = (2 * DBP + SBP) / 3)
    final mapValues = bpRecords.map((r) {
      final sys = int.tryParse(r['sys'] ?? '0') ?? 0;
      final dia = int.tryParse(r['dia'] ?? '0') ?? 0;
      return (2 * dia + sys) / 3;
    }).toList();
    final avgMap = mapValues.reduce((a, b) => a + b) / mapValues.length;

    // Use pre-calculated trend values from screen UI instead of calculating here
    final sysTrendValue = systolicTrend ?? 0.0;
    final diaTrendValue = diastolicTrend ?? 0.0;

    final sysTrend = _getTrendFromSlope(sysTrendValue);
    final diaTrend = _getTrendFromSlope(diaTrendValue);

    // Debug print to help troubleshoot
    print('Email Service - Systolic trend: $sysTrendValue -> $sysTrend');
    print('Email Service - Diastolic trend: $diaTrendValue -> $diaTrend');

    return {
      'avgSystolic': avgSys.toStringAsFixed(0),
      'avgDiastolic': avgDia.toStringAsFixed(0),
      'timeInTarget': timeInTarget.toString(),
      'meanArterialPressure': avgMap.toStringAsFixed(0),
      'systolicTrend': sysTrend,
      'diastolicTrend': diaTrend,
      'systolicValue': sysTrendValue.toStringAsFixed(3),
      'diastolicValue': diaTrendValue.toStringAsFixed(3),
      'totalMeasurements': bpRecords.length.toString(),
      'highestSystolic': highestSys.toStringAsFixed(0),
      'highestDiastolic': highestDia.toStringAsFixed(0),
      'lowestSystolic': lowestSys.toStringAsFixed(0),
      'lowestDiastolic': lowestDia.toStringAsFixed(0),
    };
  }

  // Helper function to determine trend from slope (matching app logic)
  static String _getTrendFromSlope(double slope) {
    if (slope > 0) return 'increasing';
    if (slope < 0) return 'decreasing';
    return 'stable';
  }

  // Helper function to get arrow symbol for trend
  static String _getTrendArrow(String trend) {
    switch (trend) {
      case 'increasing':
        return '↗️';
      case 'decreasing':
        return '↘️';
      case 'stable':
        return '→';
      default:
        return '→';
    }
  }

  // Generate comprehensive BP insights report text
  static String _getComprehensiveBPReportText(
    String name,
    List<Map<String, dynamic>> bpRecords,
    String? dateRange,
    int? totalMeasurements,
    double? systolicTrend,
    double? diastolicTrend,
    int? systolicThreshold,
    int? diastolicThreshold,
    String? pdfDownloadUrl,
  ) {
    final dateRangeText = dateRange ?? 'Recent records';
    final insights = _calculateBPInsights(
      bpRecords,
      systolicTrend,
      diastolicTrend,
      systolicThreshold,
      diastolicThreshold,
    );

    return '''
Blood Pressure Alerts Report

Hello $name!

Here are your comprehensive blood pressure insights for $dateRangeText. This report includes all four key metrics to help you understand your blood pressure patterns.

Total BP Measurements for this Report period: ${totalMeasurements ?? insights['totalMeasurements']}

${bpRecords.isEmpty ? 'No blood pressure records found for the selected period.' : '''
BLOOD PRESSURE AVERAGES:
• Average Systolic: ${insights['avgSystolic']} mmHg
• Average Diastolic: ${insights['avgDiastolic']} mmHg

TIME IN TARGET RANGE:
• ${insights['timeInTarget']}% (Sys < ${systolicThreshold ?? 120} and Dia < ${diastolicThreshold ?? 80})

MEAN ARTERIAL PRESSURE (MAP):
• Average MAP: ${insights['meanArterialPressure']} mmHg

BP TREND:
• Systolic: ${(double.parse(insights['systolicValue'])).abs().toStringAsFixed(2)} ${_getTrendArrow(insights['systolicTrend'])}
• Diastolic: ${(double.parse(insights['diastolicValue'])).abs().toStringAsFixed(2)} ${_getTrendArrow(insights['diastolicTrend'])}
'''}

${pdfDownloadUrl != null ? '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 YOUR COMPREHENSIVE PDF REPORT IS READY!

Click the link below to download your detailed health report with all
Blood Pressure, Glucose, and Weight data:

$pdfDownloadUrl

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''' : ''}

Understanding your Blood Pressure Alert Numbers:
• Normal: Systolic < 120 mmHg and Diastolic < 80 mmHg
• Elevated: Systolic 120-129 mmHg and Diastolic < 80 mmHg
• High Stage 1: Systolic 130-139 mmHg or Diastolic 80-89 mmHg
• High Stage 2: Systolic ≥ 140 mmHg or Diastolic ≥ 90 mmHg

Important Notes:
• This report is generated based on your Blood Pressure data
• Please consult with your healthcare provider for medical advice by sharing this report with them.
• Keep track of your health trends over time
• Contact us if you have any questions about this report

Thank you for using Vitals 101 for your health monitoring.
Stay healthy, stay informed! 💙

Best regards,
The Vitals 101 Team
    ''';
  }

  // HTML template for verification code email
  static String _getVerificationCodeEmailHTML(String name, String code) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Verify Your Email</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
            }
            .container {
                background-color: #f9f9f9;
                border-radius: 10px;
                padding: 30px;
                margin: 20px 0;
            }
            .header {
                text-align: center;
                color: #d32f2f;
                margin-bottom: 30px;
            }
            .code-container {
                background-color: white;
                border: 2px solid #d32f2f;
                border-radius: 8px;
                padding: 30px;
                margin: 30px 0;
                text-align: center;
            }
            .verification-code {
                font-size: 48px;
                font-weight: bold;
                color: #d32f2f;
                letter-spacing: 10px;
                font-family: 'Courier New', monospace;
            }
            .instructions {
                background-color: #fff3e0;
                border-left: 4px solid #ff9800;
                padding: 15px;
                margin: 20px 0;
            }
            .footer {
                text-align: center;
                color: #666;
                font-size: 12px;
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #ddd;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1 class="header">Verify Your Email</h1>

            <p>Hello $name,</p>

            <p>Thank you for registering with Vitals 101! To complete your registration and access your account, please verify your email address using the code below:</p>

            <div class="code-container">
                <p style="margin: 0 0 10px 0; color: #666;">Your Verification Code</p>
                <div class="verification-code">$code</div>
                <p style="margin: 10px 0 0 0; color: #999; font-size: 14px;">This code expires in 10 minutes</p>
            </div>

            <div class="instructions">
                <strong>How to verify:</strong>
                <ol style="margin: 10px 0;">
                    <li>Open the Vitals 101 app</li>
                    <li>Enter the 4-digit code shown above</li>
                    <li>Tap "Verify" to access your account</li>
                </ol>
            </div>

            <p style="margin-top: 30px;">If you didn't create an account with Vitals 101, please ignore this email.</p>

            <p>Stay healthy, stay informed!</p>

            <p>Best regards,<br>The Vitals 101 Team</p>
        </div>

        <div class="footer">
            <p>This is an automated message from Vitals 101. Please do not reply to this email.</p>
            <p>&copy; 2024 Vitals 101. All rights reserved.</p>
        </div>
    </body>
    </html>
    ''';
  }

  // Text template for verification code email
  static String _getVerificationCodeEmailText(String name, String code) {
    return '''
Hello $name,

Thank you for registering with Vitals 101! To complete your registration and access your account, please verify your email address using the code below:

YOUR VERIFICATION CODE: $code

This code expires in 10 minutes.

How to verify:
1. Open the Vitals 101 app
2. Enter the 4-digit code shown above
3. Tap "Verify" to access your account

If you didn't create an account with Vitals 101, please ignore this email.

Stay healthy, stay informed!

Best regards,
The Vitals 101 Team

---
This is an automated message from Vitals 101. Please do not reply to this email.
© 2024 Vitals 101. All rights reserved.
    ''';
  }

  // Helper method to set up email configuration in Firebase
  // Call this method once to initialize the email settings in Firebase
  static Future<void> setupEmailConfiguration({
    required String emailUsername,
    required String emailPassword,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('email_settings')
          .set({
        'email_username': emailUsername,
        'email_password': emailPassword,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': 'admin', // You can make this dynamic
      });

      print('Email configuration saved to Firebase successfully');
    } catch (e) {
      print('Error saving email configuration to Firebase: $e');
      rethrow;
    }
  }
}
