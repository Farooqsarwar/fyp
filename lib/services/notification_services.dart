import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// NOTE: This service only initializes and listens for notifications on the client.
/// Sending push notifications should be done securely from your backend using the OneSignal REST API.
/// You may call your backend endpoint from Flutter to trigger a notification, but do NOT expose your REST API key in your app.

class NotificationService {
  final SupabaseClient _supabase;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _bidChannel;
  bool _initialized = false;

  NotificationService({required SupabaseClient supabase}) : _supabase = supabase;

  Future<void> initialize(String userId) async {
    if (_initialized) return;

    // Initialize OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("54dc40d7-17f6-48cb-8cf7-d7398b65e95f");
    await OneSignal.Notifications.requestPermission(true);
    await OneSignal.User.pushSubscription.optIn();

    // Store player ID
    final playerId = await OneSignal.User.pushSubscription.id;
    if (playerId != null) {
      await _supabase.from('user_onesignal_ids').upsert({
        'user_id': userId,
        'player_id': playerId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,player_id');
    }

    // Set up notification listeners
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint("Notification received: ${event.notification.jsonRepresentation()}");
    });

    OneSignal.Notifications.addClickListener((event) {
      debugPrint("Notification clicked: ${event.notification.jsonRepresentation()}");
    });

    // Set up realtime channels
    _setupNotificationChannel(userId);
    _setupBidChannel(userId);

    _initialized = true;
  }

  void _setupNotificationChannel(String userId) {
    _notificationChannel = _supabase.channel('user_notifications_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          _handleLocalNotification(payload as Map<String, dynamic>);
        },
      ).subscribe();
  }

  void _setupBidChannel(String userId) {
    _bidChannel = _supabase.channel('bid_activity_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'bids',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          _handleBidNotification(payload as Map<String, dynamic>);
        },
      ).subscribe();
  }

  void _handleLocalNotification(Map<String, dynamic> payload) {
    try {
      debugPrint('Local notification received: $payload');
    } catch (e) {
      debugPrint('Error handling local notification: $e');
    }
  }

  void _handleBidNotification(Map<String, dynamic> payload) {
    try {
      debugPrint('Bid notification received: $payload');
    } catch (e) {
      debugPrint('Error handling bid notification: $e');
    }
  }

  Future<void> sendNotification({
    required List<String> playerIds,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Log the notification attempt
      debugPrint('Will request backend to send notification to player IDs: $playerIds');
      debugPrint('Title: $title');
      debugPrint('Body: $body');
      debugPrint('Data: $data');

      // EXAMPLE: Replace this with your actual backend endpoint and logic.
      // You might have a Supabase Edge Function, Firebase Cloud Function, or your own API.
      //
      // await http.post(
      //   Uri.parse('https://your-backend.example.com/send-notification'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'player_ids': playerIds,
      //     'title': title,
      //     'body': body,
      //     'data': data,
      //   }),
      // );

      // Optionally, you may log user tags locally for analytics
      await OneSignal.User.addTags({
        'last_notification_title': title,
        'last_notification_time': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> dispose() async {
    await _notificationChannel?.unsubscribe();
    await _bidChannel?.unsubscribe();
    _initialized = false;
  }

  Future<void> logout() async {
    await OneSignal.login(_supabase.auth.currentUser?.id ?? '');
    await dispose();
  }
}