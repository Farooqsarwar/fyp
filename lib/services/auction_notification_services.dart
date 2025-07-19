import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class AuctionNotificationServices {
  static final AuctionNotificationServices _instance = AuctionNotificationServices._internal();
  factory AuctionNotificationServices() => _instance;

  SupabaseClient? _supabase;
  final String _oneSignalAppId = '948ea4ee-8e9f-417c-acce-871c020d315a';
  final String _oneSignalRestApiKey = 'os_v2_app_sshkj3uot5axzlgoq4oaedjrljm2mlzmk64uyavcaao534vkzibq37i6cxmvrzr27mxko2w6p7os7yi4ojbr3eml2z55rd7nvijrojq';
  RealtimeChannel? _notificationChannel;
  bool _isInitialized = false;

  AuctionNotificationServices._internal();

  SupabaseClient get supabase {
    if (_supabase == null) {
      throw Exception('AuctionNotificationServices not initialized with Supabase client');
    }
    return _supabase!;
  }

  void initializeWithSupabase(SupabaseClient supabase) {
    if (_supabase == null) {
      _supabase = supabase;
      if (kDebugMode) print('AuctionNotificationServices initialized with Supabase client');
    }
  }

  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      if (kDebugMode) print('AuctionNotificationServices already initialized for user $userId');
      return;
    }

    try {
      if (kDebugMode) print('Initializing AuctionNotificationServices for user $userId');

      // Link OneSignal user with your app's user ID
      await OneSignal.login(userId);
      if (kDebugMode) print('OneSignal user logged in with ID: $userId');

      // Store Player ID with retries and better error handling
      await _storePlayerId(userId);

      // Realtime Channel Setup
      _setupNotificationChannel(userId);

      _isInitialized = true;
      if (kDebugMode) print('AuctionNotificationServices initialized successfully for user $userId');
    } catch (e) {
      if (kDebugMode) print('Initialization error for user $userId: $e');
      rethrow; // Re-throw to handle in calling code
    }
  }

  Future<void> _storePlayerId(String userId) async {
    try {
      if (kDebugMode) print('Storing player ID for user $userId');
      String? playerId;
      int retries = 5; // Increased retries

      // Wait for OneSignal to be fully ready
      while (retries > 0 && (playerId == null || playerId.isEmpty)) {
        // Check if user is subscribed first
        final isSubscribed = await OneSignal.User.pushSubscription.optedIn;
        if (!isSubscribed!) {
          if (kDebugMode) print('User not subscribed to push notifications');
          await OneSignal.Notifications.requestPermission(true);
        }

        playerId = OneSignal.User.pushSubscription.id;
        if (playerId == null || playerId.isEmpty) {
          if (kDebugMode) print('Player ID not available for user $userId, retrying... ($retries)');
          await Future.delayed(Duration(seconds: 2)); // Increased delay
          retries--;
        } else {
          if (kDebugMode) print('Player ID retrieved: $playerId');
        }
      }

      if (playerId != null && playerId.isNotEmpty) {
        await supabase.from('user_devices').upsert({
          'user_id': userId,
          'player_id': playerId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (kDebugMode) print('✔ Player ID $playerId stored for user $userId');

        // Verify the storage
        final stored = await supabase
            .from('user_devices')
            .select('player_id')
            .eq('user_id', userId)
            .single();
        if (kDebugMode) print('✔ Verified stored player ID: ${stored['player_id']}');
      } else {
        throw Exception('Failed to retrieve player ID for user $userId after $retries retries');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error storing player ID for user $userId: $e');
      rethrow;
    }
  }

  void _setupNotificationChannel(String userId) {
    try {
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
      if (kDebugMode) print('✔ Subscribed to notification channel for user $userId');
    } catch (e) {
      if (kDebugMode) print('❌ Error setting up notification channel: $e');
    }
  }

  // Test method to send a simple notification to all users
  Future<void> sendTestNotification() async {
    try {
      if (kDebugMode) print('Sending test notification to all users');

      // Get all player IDs
      final allUsers = await supabase.from('user_devices').select('player_id');
      final playerIds = allUsers.map((e) => e['player_id'] as String).toList();

      if (playerIds.isEmpty) {
        if (kDebugMode) print('❌ No player IDs found for test notification');
        return;
      }

      if (kDebugMode) print('📱 Sending to ${playerIds.length} devices: $playerIds');

      await _sendBatchNotifications(
        playerIds: playerIds,
        heading: 'Test Notification',
        content: 'This is a test notification from your auction app!',
        additionalData: {'type': 'test'},
      );

      if (kDebugMode) print('✔ Test notification sent successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Error sending test notification: $e');
    }
  }

  Future<void> sendAuctionStartNotification({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required DateTime startTime,
  }) async {
    if (kDebugMode) print('🔥 Triggering auction start notification for $itemId ($itemType)');
    await _sendAuctionNotificationToRegisteredUsers(
      itemId: itemId,
      itemType: itemType,
      title: 'Auction Started! 🔥',
      body: 'Bidding is now open for $itemTitle. Don\'t miss out!',
      type: 'auction_start',
      itemTitle: itemTitle,
    );
  }

  Future<void> sendAuctionEndNotification({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required DateTime endTime,
  }) async {
    if (kDebugMode) print('⏰ Triggering auction end notification for $itemId ($itemType)');
    await _sendAuctionNotificationToRegisteredUsers(
      itemId: itemId,
      itemType: itemType,
      title: 'Auction Ended ⏰',
      body: 'Bidding is now closed for $itemTitle. Check if you won!',
      type: 'auction_end',
      itemTitle: itemTitle,
    );
  }

  Future<void> sendNewBidNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String amount,
  }) async {
    if (kDebugMode) print('💰 Triggering new bid notification for user $userId on $itemId ($itemType)');
    await _sendNotification(
      userId: userId,
      title: 'New Bid Alert! 💰',
      body: 'Someone bid $amount PKR on $itemTitle. Will you bid higher?',
      data: {
        'item_id': itemId,
        'item_type': itemType,
        'item_title': itemTitle,
        'type': 'new_bid',
        'amount': amount,
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
    if (kDebugMode) print('🏆 Triggering winner notification for user $userId on $itemId ($itemType)');
    await _sendNotification(
      userId: userId,
      title: 'Congratulations! You Won! 🏆',
      body: 'You won $itemTitle for $amount PKR! Contact seller for pickup details.',
      data: {
        'item_id': itemId,
        'item_type': itemType,
        'item_title': itemTitle,
        'type': 'auction_won',
        'winner_name': winnerName,
        'amount': amount,
      },
    );
  }

  Future<void> _sendAuctionNotificationToRegisteredUsers({
    required String itemId,
    required String itemType,
    required String title,
    required String body,
    required String type,
    required String itemTitle,
  }) async {
    try {
      if (kDebugMode) print('📢 Sending auction notification for $itemId ($itemType): $title');

      final registrations = await supabase
          .from('auction_registrations')
          .select('user_id')
          .eq('item_id', itemId)
          .eq('item_type', itemType);

      if (kDebugMode) print('👥 Found ${registrations.length} registered users for $itemId ($itemType)');

      if (registrations.isEmpty) {
        if (kDebugMode) print('⚠️ No registered users for $itemId ($itemType), skipping notification');
        return;
      }

      final userIds = registrations.map((r) => r['user_id'] as String).toList();
      final playerIds = await _getPlayerIds(userIds);

      if (kDebugMode) print('📱 Retrieved ${playerIds.length} player IDs for $itemId ($itemType): $playerIds');

      if (playerIds.isEmpty) {
        if (kDebugMode) print('⚠️ No valid player IDs found for registered users');
        return;
      }

      await _sendBatchNotifications(
        playerIds: playerIds,
        heading: title,
        content: body,
        additionalData: {
          'item_id': itemId,
          'item_type': itemType,
          'item_title': itemTitle,
          'type': type,
        },
      );

      // Store notifications in database for history
      final notificationData = userIds.map((userId) => {
        'user_id': userId,
        'title': title,
        'body': body,
        'data': {
          'item_id': itemId,
          'item_type': itemType,
          'item_title': itemTitle,
          'type': type,
        },
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await supabase.from('notifications').insert(notificationData);
      if (kDebugMode) print('✔ Inserted ${notificationData.length} notifications into database');
    } catch (e) {
      if (kDebugMode) print('❌ Error sending auction notification for $itemId ($itemType): $e');
      rethrow;
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (kDebugMode) print('📨 Sending notification to user $userId: $title');

      final playerIds = await _getPlayerIds([userId]);
      if (kDebugMode) print('📱 Retrieved ${playerIds.length} player IDs for user $userId: $playerIds');

      if (playerIds.isEmpty) {
        if (kDebugMode) print('⚠️ No player IDs found for user $userId, skipping notification');
        return;
      }

      await _sendBatchNotifications(
        playerIds: playerIds,
        heading: title,
        content: body,
        additionalData: data,
      );

      // Store in database
      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) print('✔ Notification sent and stored for user $userId');
    } catch (e) {
      if (kDebugMode) print('❌ Error sending notification to user $userId: $e');
      rethrow;
    }
  }

  Future<List<String>> _getPlayerIds(List<String> userIds) async {
    try {
      if (kDebugMode) print('🔍 Fetching player IDs for users: $userIds');

      final response = await supabase
          .from('user_devices')
          .select('player_id, user_id')
          .inFilter('user_id', userIds)
          .not('player_id', 'is', null);

      if (kDebugMode) print('📱 Found ${response.length} device records: $response');

      final playerIds = response
          .map((e) => e['player_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (kDebugMode) print('✔ Valid player IDs: $playerIds');
      return playerIds;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting player IDs for users $userIds: $e');
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
      if (kDebugMode) print('⚠️ No player IDs provided, skipping batch notification');
      return;
    }

    try {
      if (kDebugMode) print('🚀 Sending batch notification to ${playerIds.length} devices: $heading');

      final payload = {
        'app_id': _oneSignalAppId,
        'include_player_ids': playerIds,
        'headings': {'en': heading},
        'contents': {'en': content},
        'data': additionalData,
        'android_accent_color': 'FF9C27B0',
        'small_icon': 'ic_notification',
        'large_icon': 'ic_launcher',
        'priority': 10, // High priority
        'ttl': 259200, // 3 days
      };

      if (kDebugMode) print('📤 Payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalRestApiKey',
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      if (kDebugMode) print('📥 OneSignal response (${response.statusCode}): $responseBody');

      if (response.statusCode == 200) {
        if (kDebugMode) print('✔ Batch notification sent successfully to ${playerIds.length} devices');
        if (kDebugMode) print('📊 Recipients: ${responseBody['recipients'] ?? 'unknown'}');
      } else {
        throw Exception('OneSignal API error (${response.statusCode}): ${responseBody['errors'] ?? responseBody}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sending batch notifications: $e');
      rethrow;
    }
  }

  void _handleNotification(Map<String, dynamic> payload) {
    final notification = payload['new'] as Map<String, dynamic>?;
    if (notification == null) {
      if (kDebugMode) print('⚠️ No new notification data in payload');
      return;
    }
    if (kDebugMode) print('🔔 Handling in-app notification: $notification');
    // Handle in-app notification display here
  }

  void dispose() {
    if (kDebugMode) print('🧹 Disposing AuctionNotificationServices');
    _notificationChannel?.unsubscribe();
    _isInitialized = false;
  }
}