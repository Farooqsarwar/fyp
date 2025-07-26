import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import 'emailservices.dart';

class AuctionNotificationServices {
  static final AuctionNotificationServices _instance = AuctionNotificationServices._internal();
  factory AuctionNotificationServices() => _instance;

  // OneSignal Configuration
  static const String _oneSignalAppId = '404425ef-e1e2-45ca-afd1-a6374737c863';
  static const String _oneSignalRestApiKey = 'os_v2_app_ibccl37b4jc4vl6ruy3uon6imm5t2c2gqwkumkm2mavefb4gbaqkucjlj7edged7cudg46tnsdrqxymramgtp5j55tunztb3tla7qga';

  SupabaseClient? _supabaseClient;
  RealtimeChannel? _notificationChannel;
  bool _isInitialized = false;

  AuctionNotificationServices._internal();

  SupabaseClient get supabase {
    if (_supabaseClient == null) {
      throw Exception('NotificationService not initialized with Supabase client');
    }
    return _supabaseClient!;
  }

  void initializeWithSupabase(SupabaseClient supabaseClient) {
    if (_supabaseClient != null) {
      if (kDebugMode) {
        debugPrint('NotificationService already initialized with Supabase client');
      }
      return;
    }
    _supabaseClient = supabaseClient;
    if (kDebugMode) {
      debugPrint('NotificationService initialized with Supabase client');
    }
  }

  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('NotificationService already initialized for user $userId');
      }
      return;
    }

    if (_supabaseClient == null) {
      throw Exception('Supabase client not initialized. Call initializeWithSupabase first.');
    }

    try {
      if (kDebugMode) {
        debugPrint('Initializing NotificationService for user $userId');
      }

      // OneSignal Setup
      OneSignal.Debug.setLogLevel(kDebugMode ? OSLogLevel.verbose : OSLogLevel.none);
      OneSignal.initialize(_oneSignalAppId);
      await OneSignal.Notifications.requestPermission(true).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('OneSignal initialization timed out'),
      );

      // Store Player ID with user validation
      await _storePlayerId(userId);

      // Realtime Channel Setup
      _setupNotificationChannel(userId);

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('NotificationService initialized successfully for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Initialization error for user $userId: $e');
      }
      // Don't rethrow - let the app continue running
      // Just log the error for debugging
      debugPrint('NotificationService initialization failed but app will continue: $e');
    }
  }

  Future<bool> _verifyUserExists(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error verifying user existence: $e');
      }
      return false;
    }
  }

  Future<void> _ensureUserExists(String userId) async {
    try {
      final userExists = await _verifyUserExists(userId);
      if (!userExists) {
        if (kDebugMode) {
          debugPrint('User $userId does not exist in users table. Creating user record...');
        }

        // Get current authenticated user data
        final currentUser = supabase.auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user found');
        }

        // Create user record with available data
        await supabase.from('users').insert({
          'id': userId,
          'email': currentUser.email ?? '',
          'full_name': currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['name'] ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          debugPrint('Successfully created user record for $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error ensuring user exists: $e');
      }
      rethrow;
    }
  }

  Future<void> _storePlayerId(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('Storing player ID for user $userId');
      }

      // First ensure the user exists in the users table
      await _ensureUserExists(userId);

      String? playerId;
      const maxRetries = 5;
      const retryDelay = Duration(seconds: 2);
      int retries = maxRetries;

      // Try to get player ID with retries
      while (retries > 0 && (playerId == null || playerId.isEmpty)) {
        playerId = OneSignal.User.pushSubscription.id;
        if (playerId == null || playerId.isEmpty) {
          if (kDebugMode) {
            debugPrint('Player ID not available yet, retrying in ${retryDelay.inSeconds} seconds... ($retries retries left)');
          }
          await Future.delayed(retryDelay);
          retries--;
        }
      }

      if (playerId != null && playerId.isNotEmpty) {
        // Use upsert to handle existing records gracefully
        await supabase.from('user_devices').upsert({
          'user_id': userId,
          'player_id': playerId,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (kDebugMode) {
          debugPrint('Successfully stored player ID for user $userId');
        }
      } else {
        // Don't throw exception, just log the warning
        if (kDebugMode) {
          debugPrint('Warning: Failed to retrieve valid player ID for user $userId after $maxRetries attempts');
        }
        // Store a placeholder that can be updated later
        await supabase.from('user_devices').upsert({
          'user_id': userId,
          'player_id': 'pending_${DateTime.now().millisecondsSinceEpoch}',
          'device_type': 'mobile',
          'platform': defaultTargetPlatform.name.toLowerCase(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error storing player ID for user $userId: $e');
      }

      // Handle specific foreign key constraint error
      if (e is PostgrestException && e.code == '23503') {
        if (kDebugMode) {
          debugPrint('Foreign key constraint violation - this usually means the user does not exist in the users table');
        }
        // Try one more time to create the user
        try {
          await _ensureUserExists(userId);
          // Recursive call - but only once to avoid infinite loop
          if (kDebugMode) {
            debugPrint('Retrying player ID storage after creating user record...');
          }
          return; // Don't retry storing player ID to avoid infinite recursion
        } catch (retryError) {
          if (kDebugMode) {
            debugPrint('Failed to create user and store player ID: $retryError');
          }
        }
      }

      // Don't rethrow - allow app to continue functioning
      if (kDebugMode) {
        debugPrint('Player ID storage failed but app will continue: $e');
      }
    }
  }

  // Add method to retry storing player ID later
  Future<void> retryStorePlayerId(String userId) async {
    try {
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) {
        await supabase.from('user_devices').upsert({
          'user_id': userId,
          'player_id': playerId,
          'device_type': 'mobile',
          'platform': defaultTargetPlatform.name.toLowerCase(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');

        if (kDebugMode) {
          debugPrint('Successfully updated player ID for user $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Retry store player ID failed: $e');
      }
    }
  }

  void _setupNotificationChannel(String userId) {
    if (_notificationChannel != null) return;

    try {
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
            final data = payload.newRecord;
            if (data is Map<String, dynamic>) {
              _handleNotification(data);
            }
          },
        )
        ..subscribe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error setting up notification channel: $e');
      }
    }
  }

  Future<void> sendAuctionStartNotification({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required DateTime startTime,
  }) async {
    try {
      await _sendAuctionNotificationToRegisteredUsers(
        itemId: itemId,
        itemType: itemType,
        title: 'Auction Started',
        body: 'Bidding is now open for $itemTitle',
        type: 'auction_start',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending auction start notification: $e');
      }
      // Don't rethrow for non-critical notifications
    }
  }

  Future<void> sendAuctionEndNotification({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required DateTime endTime,
  }) async {
    try {
      await _sendAuctionNotificationToRegisteredUsers(
        itemId: itemId,
        itemType: itemType,
        title: 'Auction Ended',
        body: 'Bidding is now closed for $itemTitle',
        type: 'auction_end',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending auction end notification: $e');
      }
      // Don't rethrow for non-critical notifications
    }
  }

  Future<void> sendNewBidNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String amount,
  }) async {
    try {
      await _sendNotification(
        userId: userId,
        title: 'New Bid Placed',
        body: 'A new bid of $amount has been placed on $itemTitle',
        data: {
          'item_id': itemId,
          'item_type': itemType,
          'type': 'new_bid',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending new bid notification: $e');
      }
      // Don't rethrow for non-critical notifications
    }
  }

  Future<void> sendWinnerNotification({
    required String userId,
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String amount,
    required String winnerName,
  }) async {
    try {
      // First send push notification
      await _sendNotification(
        userId: userId,
        title: 'Auction Won!',
        body: 'Congratulations! You won $itemTitle for $amount',
        data: {
          'item_id': itemId,
          'item_type': itemType,
          'type': 'auction_won',
          'winner_name': winnerName,
        },
      );

      // Then fetch email and send email notification
      await _fetchAndSendWinnerEmail(
        userId: userId,
        winnerName: winnerName,
        itemTitle: itemTitle,
        amount: amount,
        itemId: itemId,
        itemType: itemType,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending winner notification: $e');
      }
      // Don't rethrow for critical notifications like winner notifications
    }
  }

  Future<void> _fetchAndSendWinnerEmail({
    required String userId,
    required String winnerName,
    required String itemTitle,
    required String amount,
    required String itemId,
    required String itemType,
  }) async {
    try {
      final response = await supabase
          .from('users')
          .select('email')
          .eq('id', userId)
          .maybeSingle(); // Use maybeSingle instead of single

      if (response == null) {
        if (kDebugMode) {
          debugPrint('User $userId not found in users table');
        }
        return;
      }

      final winnerEmail = response['email'] as String?;

      if (winnerEmail == null || winnerEmail.isEmpty) {
        if (kDebugMode) {
          debugPrint('No email found for user $userId, skipping email notification');
        }
        return;
      }

      await EmailService().sendWinnerEmail(
        winnerEmail: winnerEmail,
        winnerName: winnerName,
        itemTitle: itemTitle,
        amount: amount,
        itemId: itemId,
        itemType: itemType,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching user email or sending winner email: $e');
      }
      // Don't rethrow - email is not critical for app functionality
    }
  }

  Future<void> _sendAuctionNotificationToRegisteredUsers({
    required String itemId,
    required String itemType,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final registrations = await supabase
          .from('auction_registrations')
          .select('user_id')
          .eq('item_id', itemId)
          .eq('item_type', itemType);

      if (registrations.isEmpty) return;

      final userIds = registrations.map((r) => r['user_id'] as String).toList();
      final playerIds = await _getPlayerIds(userIds);

      if (playerIds.isNotEmpty) {
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
      }

      final notificationData = userIds.map((userId) => {
        'user_id': userId,
        'title': title,
        'body': body,
        'data': {
          'item_id': itemId,
          'item_type': itemType,
          'type': type,
        },
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await supabase.from('notifications').insert(notificationData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending auction notifications: $e');
      }
      // Don't rethrow for notification errors
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final playerIds = await _getPlayerIds([userId]);
      if (playerIds.isNotEmpty) {
        await _sendBatchNotifications(
          playerIds: playerIds,
          heading: title,
          content: body,
          additionalData: data,
        );
      }

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending notification: $e');
      }
      // Don't rethrow for notification errors
    }
  }

  Future<List<String>> _getPlayerIds(List<String> userIds) async {
    try {
      final response = await supabase
          .from('user_devices')
          .select('player_id')
          .inFilter('user_id', userIds)
          .neq('player_id', '') // Exclude empty player_ids
          .not('player_id', 'like', 'pending_%'); // Exclude pending player_ids

      return response
          .map((e) => e['player_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting player IDs: $e');
      }
      return [];
    }
  }

  Future<void> _sendBatchNotifications({
    required List<String> playerIds,
    required String heading,
    required String content,
    required Map<String, dynamic> additionalData,
  }) async {
    if (playerIds.isEmpty) return;

    try {
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
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending batch notifications: $e');
      }
      // Don't rethrow for notification errors
    }
  }

  void _handleNotification(Map<String, dynamic> payload) {
    if (kDebugMode) {
      debugPrint('Received notification: $payload');
    }
    // Implement your in-app notification display logic here
  }

  void dispose() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
    _isInitialized = false;
    _supabaseClient = null;
  }
}