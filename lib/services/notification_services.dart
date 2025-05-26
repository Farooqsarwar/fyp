import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final SupabaseClient _supabase;
  RealtimeChannel? _notificationChannel;
  bool _initialized = false;

  NotificationService({required SupabaseClient supabase}) : _supabase = supabase;

  Future<void> initialize(String userId) async {
    if (_initialized) return;
    try {
      OneSignal.initialize('54dc40d7-17f6-48cb-8cf7-d7398b65e95f');
      await OneSignal.login(userId);
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null) {
        await _supabase.from('user_onesignal_ids').upsert({
          'user_id': userId,
          'player_id': playerId,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      _setupNotificationChannel(userId);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) print('Error initializing NotificationService: $e');
    }
  }

  void _setupNotificationChannel(String userId) {
    try {
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
            if (kDebugMode) print('Realtime notification: $payload');
            _handleLocalNotification(payload as Map<String, dynamic>);
          },
        ).subscribe((status, error) {
          if (kDebugMode) {
            print('Notification subscription status: $status');
            if (error != null) print('Subscription error: $error');
          }
        });
    } catch (e) {
      if (kDebugMode) print('Error setting up notification channel: $e');
    }
  }

  Future<void> sendNewBidNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    String? imageUrl,
    required String amount,
  }) async {
    try {
      final playerIds = await _supabase
          .from('user_onesignal_ids')
          .select('player_id')
          .eq('user_id', userId);
      if (playerIds.isEmpty) return;

      final notificationData = {
        'item_id': itemId,
        'item_type': itemType,
      };

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'New Bid Placed',
        'body': 'A new bid of $amount PKR has been placed on $itemTitle',
        'data': notificationData,
      });

      for (final player in playerIds) {
        await _sendPushNotification(
          playerId: player['player_id'],
          title: 'New Bid',
          content: 'A new bid of $amount PKR on $itemTitle',
          data: notificationData,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error sending bid notification: $e');
    }
  }

  Future<void> sendWinnerNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String imageUrl,
    required String amount,
    required String winnerName, required Map<String, dynamic> additionalData,
  }) async {
    try {
      final playerIds = await _supabase
          .from('user_onesignal_ids')
          .select('player_id')
          .eq('user_id', userId);
      if (playerIds.isEmpty) return;

      final notificationData = {
        'item_id': itemId,
        'item_type': itemType,
        'type': 'auction_won',
        'item_title': itemTitle,
        'image_url': imageUrl,
        'amount': amount,
        'winner_name': winnerName,
      };

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Auction Won!',
        'body': 'Congratulations! You won $itemTitle for $amount PKR',
        'data': notificationData,
      });

      for (final player in playerIds) {
        await _sendPushNotification(
          playerId: player['player_id'],
          title: 'Auction Won!',
          content: 'Congratulations! $winnerName won $itemTitle for $amount PKR',
          data: notificationData,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error sending winner notification: $e');
    }
  }

  Future<void> _sendPushNotification({
    required String playerId,
    required String title,
    required String content,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${_supabase.rest.url}/functions/v1/send-notification'),
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'player_id': playerId,
          'title': title,
          'content': content,
          'data': data,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to send push notification: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Error sending push notification: $e');
    }
  }

  void _handleLocalNotification(Map<String, dynamic> payload) {
    final notification = payload['new'] as Map<String, dynamic>?;
    if (notification == null) return;
    // Handle local notification display if needed
  }

  void dispose() {
    _notificationChannel?.unsubscribe();
    _initialized = false;
  }
}