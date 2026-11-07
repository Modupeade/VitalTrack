import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class StorageTestService {
  static Future<String?> testFirebaseStorageUpload() async {
    try {
      print('🧪 Testing Firebase Storage...');

      // 1. Create a test file
      final directory = await getTemporaryDirectory();
      final testFile = File('${directory.path}/test_report.txt');
      await testFile.writeAsString(
        'This is a test file to verify Firebase Storage is working.\n'
        'Generated at: ${DateTime.now()}\n'
        'If you can see this, Firebase Storage is configured correctly!',
      );

      print('✅ Test file created: ${testFile.path}');

      // 2. Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final testFileRef = storageRef.child('test_uploads/test_${DateTime.now().millisecondsSinceEpoch}.txt');

      print('📤 Uploading to Firebase Storage...');

      final uploadTask = await testFileRef.putFile(testFile);

      print('✅ Upload complete!');

      // 3. Get download URL
      final downloadURL = await testFileRef.getDownloadURL();

      print('🔗 Download URL: $downloadURL');
      print('✅ Firebase Storage is working correctly!');

      // Clean up local file
      await testFile.delete();

      return downloadURL;
    } catch (e) {
      print('❌ Firebase Storage test failed: $e');
      return null;
    }
  }

  // Test with actual PDF-like file
  static Future<String?> testPDFUpload() async {
    try {
      print('🧪 Testing PDF Upload...');

      // Create a test file that simulates a PDF
      final directory = await getTemporaryDirectory();
      final testPdfFile = File('${directory.path}/test_report.pdf');

      // Write some dummy content (not a real PDF, just for testing upload)
      await testPdfFile.writeAsString('%PDF-1.4\nTest PDF content');

      print('✅ Test PDF file created');

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final pdfRef = storageRef.child('bp_reports/test_user/report_${DateTime.now().millisecondsSinceEpoch}.pdf');

      print('📤 Uploading test PDF...');

      // Set metadata for PDF
      final metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'userId': 'test_user',
          'reportType': 'bp_report',
          'generatedAt': DateTime.now().toIso8601String(),
        },
      );

      await pdfRef.putFile(testPdfFile, metadata);

      print('✅ PDF upload complete!');

      // Get download URL
      final downloadURL = await pdfRef.getDownloadURL();

      print('🔗 PDF Download URL: $downloadURL');
      print('✅ PDF upload test successful!');

      // Clean up
      await testPdfFile.delete();

      return downloadURL;
    } catch (e) {
      print('❌ PDF upload test failed: $e');
      return null;
    }
  }

  // Delete test files from Firebase Storage
  static Future<void> cleanupTestFiles() async {
    try {
      print('🧹 Cleaning up test files...');

      final storageRef = FirebaseStorage.instance.ref();
      final testUploadsRef = storageRef.child('test_uploads');

      final listResult = await testUploadsRef.listAll();

      for (var item in listResult.items) {
        await item.delete();
        print('🗑️ Deleted: ${item.name}');
      }

      print('✅ Cleanup complete!');
    } catch (e) {
      print('❌ Cleanup failed: $e');
    }
  }
}
