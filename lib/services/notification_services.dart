import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  SupabaseClient? _supabase;
  final String _oneSignalAppId = '54dc40d7-17f6-48cb-8cf7-d7398b65e95f';
  final String _oneSignalRestApiKey = 'os_v2_app_ktoebvyx6zemxdhx244ywzpjl4zrqlfmv2ou3mev5zkcu2ps45c5cyq4eblplgbhx3mqde3oqqxvtisnpthl3l2rmeqvd6bzk5v63ca';
  RealtimeChannel? _notificationChannel;
  bool _isInitialized = false;

  NotificationService._internal();

  SupabaseClient get supabase {
    if (_supabase == null) {
      throw Exception('NotificationService not initialized with Supabase client');
    }
    return _supabase!;
  }

  void initializeWithSupabase(SupabaseClient supabase) {
    if (_supabase == null) {
      _supabase = supabase;
      if (kDebugMode) print('NotificationService initialized with Supabase client');
    }
  }

  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      if (kDebugMode) print('NotificationService already initialized for user $userId');
      return;
    }

    try {
      if (kDebugMode) print('Initializing NotificationService for user $userId');
      // OneSignal Setup
      OneSignal.Debug.setLogLevel(kDebugMode ? OSLogLevel.verbose : OSLogLevel.none);
      OneSignal.initialize(_oneSignalAppId);
      await OneSignal.Notifications.requestPermission(true);
      if (kDebugMode) print('OneSignal initialized and permission requested for user $userId');

      // Store Player ID
      await _storePlayerId(userId);

      // Realtime Channel Setup
      _setupNotificationChannel(userId);

      _isInitialized = true;
      if (kDebugMode) print('NotificationService initialized successfully for user $userId');
    } catch (e) {
      if (kDebugMode) print('Initialization error for user $userId: $e');
    }
  }

  Future<void> _storePlayerId(String userId) async {
    try {
      if (kDebugMode) print('Storing player ID for user $userId');
      String? playerId;
      int retries = 3;

      while (retries > 0 && (playerId == null || playerId.isEmpty)) {
        playerId = OneSignal.User.pushSubscription.id;
        if (playerId == null) {
          if (kDebugMode) print('Player ID not available for user $userId, retrying... ($retries)');
          await Future.delayed(const Duration(seconds: 1));
          retries--;
        }
      }

      if (playerId != null) {
        await supabase.from('user_devices').upsert({
          'user_id': userId,
          'player_id': playerId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
        if (kDebugMode) print('Player ID $playerId stored for user $userId');
      } else {
        if (kDebugMode) print('Failed to retrieve player ID for user $userId after retries');
      }
    } catch (e) {
      if (kDebugMode) print('Error storing player ID for user $userId: $e');
    }
  }

  void _setupNotificationChannel(String userId) {
    if (kDebugMode) print('Setting up notification channel for user $userId');
    _notificationChannel = supabase.channel('user_notifications_$userId')
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
          if (kDebugMode) print('Received notification for user $userId: $payload');
          _handleNotification(payload as Map<String, dynamic>);
        },
      ).subscribe();
    if (kDebugMode) print('Subscribed to notification channel for user $userId');
  }

  Future<void> sendAuctionStartNotification({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required DateTime startTime,
  }) async {
    if (kDebugMode) print('Triggering auction start notification for $itemId ($itemType)');
    await _sendAuctionNotificationToRegisteredUsers(
      itemId: itemId,
      itemType: itemType,
      title: 'Auction Started',
      body: 'Bidding is now open for $itemTitle',
      type: 'auction_start',
    );
  }

  Future<void> sendAuctionEndNotification({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required DateTime endTime,
  }) async {
    if (kDebugMode) print('Triggering auction end notification for $itemId ($itemType)');
    await _sendAuctionNotificationToRegisteredUsers(
      itemId: itemId,
      itemType: itemType,
      title: 'Auction Ended',
      body: 'Bidding is now closed for $itemTitle',
      type: 'auction_end',
    );
  }

  Future<void> sendNewBidNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String amount,
  }) async {
    if (kDebugMode) print('Triggering new bid notification for user $userId on $itemId ($itemType)');
    await _sendNotification(
      userId: userId,
      title: 'New Bid Placed',
      body: 'A new bid of $amount PKR has been placed on $itemTitle',
      data: {
        'item_id': itemId,
        'item_type': itemType,
        'type': 'new_bid',
      },
    );
  }

  Future<void> sendWinnerNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String amount,
    required String winnerName,
  }) async {
    if (kDebugMode) print('Triggering winner notification for user $userId on $itemId ($itemType)');
    await _sendNotification(
      userId: userId,
      title: 'Auction Won!',
      body: 'Congratulations! You won $itemTitle for $amount PKR',
      data: {
        'item_id': itemId,
        'item_type': itemType,
        'type': 'auction_won',
        'winner_name': winnerName,
      },
    );
  }

  Future<void> _sendAuctionNotificationToRegisteredUsers({
    required String itemId,
    required String itemType,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      if (kDebugMode) print('Sending auction notification for $itemId ($itemType): $title');
      final registrations = await supabase
          .from('auction_registrations')
          .select('user_id')
          .eq('item_id', itemId)
          .eq('item_type', itemType);
      if (kDebugMode) print('Found ${registrations.length} registered users for $itemId ($itemType)');
      if (registrations.isEmpty) {
        if (kDebugMode) print('No registered users for $itemId ($itemType), skipping notification');
        return;
      }

      final playerIds = await _getPlayerIds(
          registrations.map((r) => r['user_id'] as String).toList());
      if (kDebugMode) print('Retrieved ${playerIds.length} player IDs for $itemId ($itemType): $playerIds');

      await _sendBatchNotifications(
        playerIds: playerIds,
        heading: title,
        content: body,
        additionalData: {
          'item_id': itemId,
          'item_type': itemType,
          'type': type,
        },
      );

      final notificationData = registrations.map((reg) => {
        'user_id': reg['user_id'],
        'title': title,
        'body': body,
        'data': {
          'item_id': itemId,
          'item_type': itemType,
          'type': type,
        },
      }).toList();

      await supabase.from('notifications').insert(notificationData);
      if (kDebugMode) print('Inserted ${notificationData.length} notifications into table for $itemId ($itemType)');
    } catch (e) {
      if (kDebugMode) print('Error sending auction notification for $itemId ($itemType): $e');
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (kDebugMode) print('Sending notification to user $userId: $title');
      final playerIds = await _getPlayerIds([userId]);
      if (kDebugMode) print('Retrieved ${playerIds.length} player IDs for user $userId: $playerIds');
      if (playerIds.isEmpty) {
        if (kDebugMode) print('No player IDs found for user $userId, skipping notification');
        return;
      }

      await _sendBatchNotifications(
        playerIds: playerIds,
        heading: title,
        content: body,
        additionalData: data,
      );

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
      });
      if (kDebugMode) print('Inserted notification for user $userId');
    } catch (e) {
      if (kDebugMode) print('Error sending notification to user $userId: $e');
    }
  }

  Future<List<String>> _getPlayerIds(List<String> userIds) async {
    try {
      if (kDebugMode) print('Fetching player IDs for users: $userIds');
      final response = await supabase
          .from('user_devices')
          .select('player_id')
          .inFilter('user_id', userIds);
      final playerIds = response.map((e) => e['player_id'] as String).toList();
      if (kDebugMode) print('Retrieved player IDs: $playerIds');
      return playerIds;
    } catch (e) {
      if (kDebugMode) print('Error getting player IDs for users $userIds: $e');
      return [];
    }
  }

  Future<void> _sendBatchNotifications({
    required List<String> playerIds,
    required String heading,
    required String content,
    required Map<String, dynamic> additionalData,
  }) async {
    if (playerIds.isEmpty) {
      if (kDebugMode) print('No player IDs provided, skipping batch notification');
      return;
    }

    try {
      if (kDebugMode) print('Sending batch notification to $playerIds: $heading');
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalRestApiKey',
        },
        body: jsonEncode({
          'app_id': _oneSignalAppId,
          'include_player_ids': playerIds,
          'headings': {'en': heading},
          'contents': {'en': content},
          'data': additionalData,
          'small_icon': 'ic_notification',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Notification failed: ${response.body}');
      }
      if (kDebugMode) print('Batch notification sent successfully to $playerIds');
    } catch (e) {
      if (kDebugMode) print('Error sending batch notifications to $playerIds: $e');
    }
  }

  void _handleNotification(Map<String, dynamic> payload) {
    final notification = payload['new'] as Map<String, dynamic>?;
    if (notification == null) {
      if (kDebugMode) print('No new notification data in payload');
      return;
    }
    if (kDebugMode) print('Handling in-app notification: $notification');
    // Handle in-app notification display
  }

  void dispose() {
    if (kDebugMode) print('Disposing NotificationService');
    _notificationChannel?.unsubscribe();
    _isInitialized = false;
  }
}