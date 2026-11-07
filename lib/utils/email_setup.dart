import 'package:vitals_10/services/email_service.dart';

/// Helper class to set up email configuration in Firebase
/// Run this once to configure your email settings
class EmailSetup {
  /// Set up email configuration in Firebase
  /// Call this method once with your Gmail credentials
  static Future<void> configureEmailSettings({
    required String gmailAddress,
    required String appPassword,
  }) async {
    try {
      print('Setting up email configuration in Firebase...');

      await EmailService.setupEmailConfiguration(
        emailUsername: gmailAddress,
        emailPassword: appPassword,
      );

      print('✅ Email configuration saved successfully!');
      print('📧 Gmail Address: $gmailAddress');
      print(
          '🔐 App Password: ${appPassword.replaceRange(4, appPassword.length - 4, '****')}');
      print('🚀 You can now use the email functionality in your app!');
    } catch (e) {
      print('❌ Error setting up email configuration: $e');
      rethrow;
    }
  }

  /// Test email configuration
  static Future<void> testEmailConfiguration() async {
    try {
      print('Testing email configuration...');

      // Test with a dummy email (this will fail but will test the configuration)
      final result = await EmailService.sendEmail(
        recipientEmail: 'test@example.com',
        subject: 'Test Email Configuration',
        htmlContent:
            '<h1>Test Email</h1><p>This is a test email to verify configuration.</p>',
      );

      if (result) {
        print('✅ Email configuration test successful!');
      } else {
        print('❌ Email configuration test failed!');
      }
    } catch (e) {
      print('❌ Error testing email configuration: $e');
    }
  }
}

/// Example usage:
/// 
/// void main() async {
///   // Set up email configuration (run this once)
///   await EmailSetup.configureEmailSettings(
///     gmailAddress: 'your-email@gmail.com',
///     appPassword: 'your-16-character-app-password',
///   );
///   
///   // Test the configuration
///   await EmailSetup.testEmailConfiguration();
/// }
