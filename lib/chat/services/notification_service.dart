import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/chat_controller.dart';
import '../views/chat_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final String oneSignalAppId = '112d7536-cde8-4008-9993-7ba95f93f600';
  final String oneSignalRestApiKey =
      'os_v2_app_cewxknwn5baargmtpouv7e7wabgq6cv7uqsers4mzalyhyo5o542yn2iaxnseuil3tp66totozg7tpk74aaw773z74v7fck52ihvbqa';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.verbose : OSLogLevel.none,
      );

       OneSignal.initialize(oneSignalAppId);

      bool permission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('OneSignal permission granted: $permission');

      _setupNotificationClickHandler();
      _isInitialized = true;
      debugPrint('OneSignal initialized successfully');
    } catch (e) {
      debugPrint('Error initializing OneSignal: $e');
      rethrow;
    }
  }

  void _setupNotificationClickHandler() {
    OneSignal.Notifications.addClickListener((event) {
      try {
        final data = event.notification.additionalData;
        if (data == null) {
          debugPrint('No additional data in notification');
          Get.offAll(() => ChatScreen());
          return;
        }

        final senderId = data['senderId']?.toString();
        final senderName = data['receiverName']?.toString() ?? 'Unknown';

        if (senderId == null || senderId.isEmpty) {
          debugPrint('Missing senderId in notification data');
          Get.offAll(() => ChatScreen());
          return;
        }

        Get.to(() => ChatDetailScreen(
          receiverId: senderId,
          receiverName: senderName,
        ));
      } catch (e) {
        debugPrint('Error handling notification click: $e');
        Get.offAll(() => ChatScreen());
      }
    });
  }

  Future<void> storePlayerId(String userId) async {
    try {
      if (!_isInitialized) await init();

      // Wait for OneSignal to be ready (add delay)
      await Future.delayed(const Duration(seconds: 2));

      // Get player ID with retry logic
      String? playerId;
      int retries = 3;

      while (retries > 0 && (playerId == null || playerId.isEmpty)) {
        playerId = OneSignal.User.pushSubscription.id;
        if (playerId == null) {
          await Future.delayed(const Duration(seconds: 1));
          retries--;
        }
      }

      if (playerId == null) {
        debugPrint('⚠️ Failed to fetch player ID after retries');
        return;
      }

      debugPrint('✔ Storing player ID: $playerId for user: $userId');

      // Upsert to Supabase
      final supabase = Supabase.instance.client;
      await supabase.from('user_devices').upsert({
        'user_id': userId,
        'player_id': playerId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('✔ Player ID stored successfully');
    } catch (e) {
      debugPrint('❌ Error storing player ID: $e');
    }
  }
  Future<void> sendChatNotification({
    required String receiverId,
    required String receiverName,
    required String senderName,
    required String message,
    String? imageUrl,
  }) async {
    debugPrint('[Notification] Attempting to send notification to user: $receiverId');
    debugPrint('[Notification] Sender: $senderName, Receiver: $receiverName');
    debugPrint('[Notification] Message: ${imageUrl != null ? 'Image message' : message}');

    try {
      if (!_isInitialized) {
        debugPrint('[Notification] Initializing OneSignal...');
        await init();
      }

      debugPrint('[Notification] Looking up player ID for receiver: $receiverId');
      final receiverPlayerId = await _getPlayerIdForUser(receiverId);
      debugPrint('[Notification] Found player ID: $receiverPlayerId');

      if (receiverPlayerId == null || receiverPlayerId.isEmpty) {
        debugPrint('[Notification] No player ID found for user $receiverId');
        return;
      }

      final content = imageUrl != null ? '$senderName sent an image' : message;
      final heading = 'New message from $senderName';

      final additionalData = {
        'receiverId': receiverId,
        'receiverName': receiverName,
        'senderId': Get.find<ChatController>().senderId.value,
        'senderName': senderName,
        'type': 'chat_message',
        'imageUrl': imageUrl,
      };

      await _sendNotificationViaRest(
        playerIds: [receiverPlayerId],
        heading: heading,
        content: content,
        additionalData: additionalData,
      );

      debugPrint('[Notification] Successfully sent notification to $receiverName ($receiverId)');
    } catch (e, stackTrace) {
      debugPrint('[Notification] Error sending chat notification: $e');
      debugPrint('[Notification] Stack trace: $stackTrace');
      if (kDebugMode) rethrow;
    }
  }

  Future<void> _sendNotificationViaRest({
    required List<String> playerIds,
    required String heading,
    required String content,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      final body = {
        'app_id': oneSignalAppId,
        'include_player_ids': playerIds,
        'headings': {'en': heading},
        'contents': {'en': content},
        'data': additionalData ?? {},
        'small_icon': 'ic_notification',
        'ios_badgeType': 'Increase',
        'ios_badgeCount': 1,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $oneSignalRestApiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Notification sent successfully');
      } else {
        debugPrint(
          'Failed to send notification. Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error in _sendNotificationViaRest: $e');
      rethrow;
    }
  }

  Future<String?> _getPlayerIdForUser(String userId) async {
    try {
      debugPrint('Looking up player ID for user: $userId');
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('user_devices')
          .select('player_id')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['player_id'] as String?;
    } catch (e) {
      debugPrint('Error fetching player ID: $e');
      return null;
    }
  }
}