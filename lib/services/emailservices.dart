import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;

  // Email Configuration
  late String _smtpUsername;
  late String _smtpPassword;
  late String _smtpServer;
  late int _smtpPort;
  late bool _smtpSsl;
  late String _fromEmail;
  late String _fromName;
  bool _isInitialized = false;

  EmailService._internal();

  /// Initialize email service with configuration
  void initialize({
    required String smtpUsername,
    required String smtpPassword,
    required String smtpServer,
    required int smtpPort,
    required bool smtpSsl,
    required String fromEmail,
    required String fromName,
  }) {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('EmailService already initialized');
      }
      return;
    }

    _smtpUsername = smtpUsername;
    _smtpPassword = smtpPassword;
    _smtpServer = smtpServer;
    _smtpPort = smtpPort;
    _smtpSsl = smtpSsl;
    _fromEmail = fromEmail;
    _fromName = fromName;
    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('EmailService initialized successfully');
    }
  }

  /// Send a winner notification email
  Future<void> sendWinnerEmail({
    required String winnerEmail,
    required String winnerName,
    required String itemTitle,
    required String amount,
    required String itemId,
    required String itemType,
  }) async {
    _checkInitialized();

    try {
      final smtpServer = _getSmtpServer();
      final message = _createWinnerMessage(
        winnerEmail: winnerEmail,
        winnerName: winnerName,
        itemTitle: itemTitle,
        amount: amount,
        itemId: itemId,
        itemType: itemType,
      );

      await _sendEmail(message, smtpServer);
    } catch (e) {
      _handleEmailError('winner email', e);
      rethrow;
    }
  }

  /// Send a generic email
  Future<void> sendEmail({
    required List<String> recipients,
    required String subject,
    required String textBody,
    String? htmlBody,
    List<Attachment>? attachments,
  }) async {
    _checkInitialized();

    try {
      final smtpServer = _getSmtpServer();
      final message = Message()
        ..from = Address(_fromEmail, _fromName)
        ..recipients.addAll(recipients)
        ..subject = subject
        ..text = textBody
        ..html = htmlBody
        ..attachments = attachments ?? [];

      await _sendEmail(message, smtpServer);
    } catch (e) {
      _handleEmailError('email', e);
      rethrow;
    }
  }

  // Private helper methods
  SmtpServer _getSmtpServer() {
    return SmtpServer(
      _smtpServer,
      username: _smtpUsername,
      password: _smtpPassword,
      port: _smtpPort,
      ssl: _smtpSsl,
    );
  }

  Message _createWinnerMessage({
    required String winnerEmail,
    required String winnerName,
    required String itemTitle,
    required String amount,
    required String itemId,
    required String itemType,
  }) {
    return Message()
      ..from = Address(_fromEmail, _fromName)
      ..recipients.add(winnerEmail)
      ..subject = 'Congratulations! You Won the Auction for $itemTitle'
      ..text = '''
Dear $winnerName,

Congratulations! You have won the auction for $itemTitle with a bid of $amount.

Item Details:
- Item ID: $itemId
- Item Type: $itemType

Please proceed to complete the payment and claim your item.

Best regards,
$_fromName
'''
      ..html = '''
<p>Dear $winnerName,</p>
<p>Congratulations! You have won the auction for <strong>$itemTitle</strong> with a bid of <strong>$amount</strong>.</p>
<p><strong>Item Details:</strong></p>
<ul>
  <li>Item ID: $itemId</li>
  <li>Item Type: $itemType</li>
</ul>
<p>Please proceed to complete the payment and claim your item.</p>
<p>Best regards,<br>$_fromName</p>
''';
  }

  Future<void> _sendEmail(Message message, SmtpServer smtpServer) async {
    final sendReport = await send(message, smtpServer);
    if (kDebugMode) {
      debugPrint('Email sent: ${sendReport.toString()}');
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw Exception('EmailService not initialized. Call initialize() first.');
    }
  }

  void _handleEmailError(String emailType, dynamic error) {
    if (kDebugMode) {
      debugPrint('Error sending $emailType: $error');
      // Generic error logging since SmtpClientCommunicationError isn't available
      debugPrint('Error details: ${error.toString()}');
    }
  }
}