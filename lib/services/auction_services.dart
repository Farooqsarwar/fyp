import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auction_notification_services.dart';

class AuctionService {
  final SupabaseClient supabase;
  late final RealtimeChannel _auctionChannel;
  final Map<String, StreamController> _activeControllers = {};
  final Map<String, RealtimeChannel> _activeChannels = {};
  final Set<String> _notifiedAuctionsStart = {};
  final Set<String> _notifiedAuctionsEnd = {};
  static const _validItemTypes = {'art', 'furniture', 'cars'};

  AuctionService({required this.supabase}) {
    if (kDebugMode) {
      debugPrint('AuctionService initialized with Supabase client');
    }
  }

  /// Initializes real-time subscriptions for auctions.
  void initialize() {
    if (kDebugMode) {
      debugPrint('Initializing AuctionService realtime channels');
    }

    _auctionChannel = supabase.channel('public:auctions')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bids',
        callback: (payload) {
          if (kDebugMode) {
            debugPrint(
                'Bids table updated: ${payload.oldRecord} → ${payload.newRecord}');
            debugPrint('Change type: ${payload.eventType}');
          }
        },
      )
      ..subscribe();

    if (kDebugMode) {
      debugPrint('Subscribed to public:auctions channel');
    }
  }

  /// Monitors auction status and triggers start/end notifications.
  Future<void> monitorAuctionStatus({
    required String itemId,
    required String itemType,
    required AuctionNotificationServices notificationService,
  }) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      final auctionKey = '$itemType:$itemId';
      if (kDebugMode) {
        debugPrint('Monitoring auction status for $itemId ($itemType)');
      }

      final auction = await supabase
          .from(itemType)
          .select('id, bid_name, start_time, end_time, is_active')
          .eq('id', itemId)
          .maybeSingle();

      if (auction == null) {
        if (kDebugMode) {
          debugPrint('No auction found for $itemId ($itemType)');
        }
        return;
      }

      final startTime = DateTime.tryParse(auction['start_time'] ?? '');
      final endTime = DateTime.tryParse(auction['end_time'] ?? '');
      final isActive = auction['is_active'] ?? false;
      final itemTitle = auction['bid_name'] ?? 'Item';

      if (kDebugMode) {
        debugPrint(
            'Auction $itemId: start=$startTime, end=$endTime, active=$isActive');
      }

// Check if auction has started
      if (startTime != null &&
          DateTime.now().isAfter(startTime) &&
          !isActive &&
          !_notifiedAuctionsStart.contains(auctionKey)) {
        await supabase
            .from(itemType)
            .update({'is_active': true}).eq('id', itemId);
        await notificationService.sendAuctionStartNotification(
          itemId: itemId,
          itemType: itemType,
          itemTitle: itemTitle,
          startTime: startTime,
        );
        _notifiedAuctionsStart.add(auctionKey);
        if (kDebugMode) {
          debugPrint('Auction $itemId started, notification sent');
        }
      }

// Check if auction has ended
      if (endTime != null &&
          DateTime.now().isAfter(endTime) &&
          isActive &&
          !_notifiedAuctionsEnd.contains(auctionKey)) {
        await supabase
            .from(itemType)
            .update({'is_active': false}).eq('id', itemId);

        await checkAndDeclareWinner(
          itemId: itemId,
          itemType: itemType,
          notificationService: notificationService,
        );

        await notificationService.sendAuctionEndNotification(
          itemId: itemId,
          itemType: itemType,
          itemTitle: itemTitle,
          endTime: endTime,
        );

        _notifiedAuctionsEnd.add(auctionKey);
        if (kDebugMode) {
          debugPrint('Auction $itemId ended, notification sent');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'Error monitoring auction status for $itemId ($itemType): $e');
      }
    }
  }

  /// Declares the winner for an auction if it has ended and no winner exists.
  Future<Map<String, dynamic>?> checkAndDeclareWinner({
    required String itemId,
    required String itemType,
    required AuctionNotificationServices notificationService,
  }) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      if (kDebugMode) {
        debugPrint(
            'Checking and declaring winner for item $itemId ($itemType)');
      }

      final auction = await supabase
          .from(itemType)
          .select('bid_name, is_active, end_time')
          .eq('id', itemId)
          .maybeSingle();

      if (auction == null) {
        if (kDebugMode) {
          debugPrint(
              'No auction found for itemId: $itemId, itemType: $itemType');
        }
        return null;
      }

      final endTime = DateTime.tryParse(auction['end_time'] ?? '');
      if (endTime != null && DateTime.now().isBefore(endTime)) {
        if (kDebugMode) {
          debugPrint('Auction has not ended yet for itemId: $itemId');
        }
        return null;
      }

      if (auction['is_active'] == true && endTime != null) {
        await supabase
            .from(itemType)
            .update({'is_active': false}).eq('id', itemId);
        if (kDebugMode) {
          debugPrint('Marked auction as inactive for itemId: $itemId');
        }
      }

      final existingWinner = await supabase
          .from('auction_winners')
          .select('*, users!user_id(name, email)')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .maybeSingle();

      if (existingWinner != null) {
        if (kDebugMode) {
          debugPrint('Winner already declared for itemId: $itemId');
        }
        return _formatWinnerData(existingWinner);
      }

      final highestBid = await supabase
          .from('bids')
          .select('*, users!user_id(name, email)')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .order('amount', ascending: false)
          .limit(1)
          .maybeSingle();

      if (highestBid == null) {
        if (kDebugMode) {
          debugPrint('No bids found for itemId: $itemId, itemType: $itemType');
        }
        return null;
      }

      final winnerData = {
        'item_id': itemId,
        'item_type': itemType,
        'user_id': highestBid['user_id'],
        'winning_amount': highestBid['amount'],
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('auction_winners').insert(winnerData);

      final winnerName = highestBid['users']?['name'] ??
          highestBid['users']?['email']?.split('@').first ??
          'Anonymous';

      await notificationService.sendWinnerNotification(
        userId: highestBid['user_id'],
        itemId: itemId,
        itemType: itemType,
        itemTitle: auction['bid_name'] ?? 'Item',
        amount: highestBid['amount'].toString(),
        winnerName: winnerName,
      );

      if (kDebugMode) {
        debugPrint('Winner declared and notification sent successfully');
      }

      return _formatWinnerData({
        ...winnerData,
        'users': highestBid['users'],
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error declaring winner: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Manually declares winner for an ended auction.
  Future<Map<String, dynamic>?> declareWinnerForEndedAuction({
    required String itemId,
    required String itemType,
    required AuctionNotificationServices notificationService,
  }) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      if (kDebugMode) {
        debugPrint('Manually declaring winner for item $itemId ($itemType)');
      }

      final auction = await supabase
          .from(itemType)
          .select('bid_name, is_active, end_time')
          .eq('id', itemId)
          .maybeSingle();

      if (auction == null) {
        if (kDebugMode) {
          debugPrint(
              'No auction found for itemId: $itemId, itemType: $itemType');
        }
        return null;
      }

      final endTime = DateTime.tryParse(auction['end_time'] ?? '');
      if (endTime == null || DateTime.now().isBefore(endTime)) {
        if (kDebugMode) {
          debugPrint('Auction has not ended yet for itemId: $itemId');
        }
        return null;
      }

      if (auction['is_active'] == true) {
        await supabase
            .from(itemType)
            .update({'is_active': false}).eq('id', itemId);
        if (kDebugMode) {
          debugPrint('Marked auction as inactive for itemId: $itemId');
        }
      }

      final existingWinner = await supabase
          .from('auction_winners')
          .select('*, users!user_id(name, email)')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .maybeSingle();

      if (existingWinner != null) {
        if (kDebugMode) {
          debugPrint('Winner already declared for itemId: $itemId');
        }
        return _formatWinnerData(existingWinner);
      }

      final highestBid = await supabase
          .from('bids')
          .select('*, users!user_id(name, email)')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .order('amount', ascending: false)
          .limit(1)
          .maybeSingle();

      if (highestBid == null) {
        if (kDebugMode) {
          debugPrint('No bids found for itemId: $itemId, itemType: $itemType');
        }
        return null;
      }

      final winnerData = {
        'item_id': itemId,
        'item_type': itemType,
        'user_id': highestBid['user_id'],
        'winning_amount': highestBid['amount'],
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('auction_winners').insert(winnerData);

      final winnerName = highestBid['users']?['name'] ??
          highestBid['users']?['email']?.split('@').first ??
          'Anonymous';

      await notificationService.sendWinnerNotification(
        userId: highestBid['user_id'],
        itemId: itemId,
        itemType: itemType,
        itemTitle: auction['bid_name'] ?? 'Item',
        amount: highestBid['amount'].toString(),
        winnerName: winnerName,
      );

      if (kDebugMode) {
        debugPrint('Winner declared successfully for itemId: $itemId');
      }

      return _formatWinnerData({
        ...winnerData,
        'users': highestBid['users'],
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error declaring winner for ended auction: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Declares winners for all ended auctions without winners.
  Future<List<Map<String, dynamic>>> declareWinnersForAllEndedAuctions(
      AuctionNotificationServices notificationService) async {
    try {
      if (kDebugMode) {
        debugPrint('Checking for ended auctions without winners');
      }

      final List<Map<String, dynamic>> declaredWinners = [];
      for (final itemType in _validItemTypes) {
        final endedAuctions = await supabase
            .from(itemType)
            .select('id, bid_name, end_time, is_active')
            .lt('end_time', DateTime.now().toIso8601String());

        for (final auction in endedAuctions) {
          final itemId = auction['id'];

          final existingWinner = await supabase
              .from('auction_winners')
              .select('id')
              .eq('item_id', itemId)
              .eq('item_type', itemType)
              .maybeSingle();

          if (existingWinner == null) {
            final winner = await declareWinnerForEndedAuction(
              itemId: itemId,
              itemType: itemType,
              notificationService: notificationService,
            );

            if (winner != null) {
              declaredWinners.add(winner);
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            'Declared ${declaredWinners.length} winners for ended auctions');
      }

      return declaredWinners;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error declaring winners for ended auctions: $e');
      }
      rethrow;
    }
  }

  /// Monitors all auctions periodically.
  Future<void> monitorAllAuctions(
      AuctionNotificationServices notificationService) async {
    try {
      if (kDebugMode) {
        debugPrint('Monitoring all auctions');
      }
      for (final itemType in _validItemTypes) {
        final auctions = await supabase
            .from(itemType)
            .select('id, bid_name, start_time, end_time, is_active');
        for (final auction in auctions) {
          await monitorAuctionStatus(
            itemId: auction['id'],
            itemType: itemType,
            notificationService: notificationService,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error monitoring all auctions: $e');
      }
    }
  }

  /// Gets auction status with winner information.
  Future<Map<String, dynamic>?> getAuctionStatusWithWinner(
      String itemId, String itemType) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      final auction = await supabase
          .from(itemType)
          .select('*')
          .eq('id', itemId)
          .maybeSingle();

      if (auction == null) return null;

      final winner = await supabase
          .from('auction_winners')
          .select('*, users!user_id(name, email)')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .maybeSingle();

      final highestBid = await getHighestBidWithBidder(itemId, itemType);

      return {
        'auction': auction,
        'winner': winner != null ? _formatWinnerData(winner) : null,
        'highest_bid': highestBid,
        'has_ended': DateTime.tryParse(auction['end_time'] ?? '')
            ?.isBefore(DateTime.now()) ??
            false,
        'is_active': auction['is_active'] ?? false,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting auction status with winner: $e');
      }
      rethrow;
    }
  }

  /// Debug method to diagnose winner declaration issues.
  Future<Map<String, dynamic>> debugWinnerDeclaration(
      String itemId, String itemType) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      final auction = await supabase
          .from(itemType)
          .select('*')
          .eq('id', itemId)
          .maybeSingle();

      final winner = await supabase
          .from('auction_winners')
          .select('*')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .maybeSingle();

      final bids = await supabase
          .from('bids')
          .select('*')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .order('amount', ascending: false);

      final now = DateTime.now();
      final endTime = DateTime.tryParse(auction?['end_time'] ?? '');

      return {
        'auction_exists': auction != null,
        'auction_is_active': auction?['is_active'] ?? false,
        'auction_end_time': auction?['end_time'],
        'current_time': now.toIso8601String(),
        'auction_has_ended': endTime?.isBefore(now) ?? false,
        'winner_exists': winner != null,
        'total_bids': bids.length,
        'highest_bid_amount': bids.isNotEmpty ? bids.first['amount'] : null,
        'debug_info': {
          'auction_data': auction,
          'winner_data': winner,
          'bids_data': bids,
        }
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'debug_info': 'Failed to fetch debug information'
      };
    }
  }

  /// Formats winner data for consistent output.
  Map<String, dynamic> _formatWinnerData(Map<String, dynamic> winnerData) {
    return {
      'item_id': winnerData['item_id'],
      'item_type': winnerData['item_type'],
      'user_id': winnerData['user_id'],
      'winning_amount': winnerData['winning_amount'],
      'created_at': winnerData['created_at'],
      'user': {
        'name': winnerData['users']?['name'] ??
            winnerData['users']?['email']?.split('@').first ??
            'Anonymous',
        'email': winnerData['users']?['email'] ?? '',
        'avatar_url': null,
      },
    };
  }

  /// Gets the highest bid with bidder information.
  Future<Map<String, dynamic>?> getHighestBidWithBidder(
      String itemId, String itemType) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      if (kDebugMode) {
        debugPrint('Fetching highest bid for item $itemId ($itemType)');
      }

      final response = await supabase
          .from('bids')
          .select('''
            id, 
            amount, 
            created_at,
            user_id,
            users!user_id(
              id,
              email,
              name
            )
          ''')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .order('amount', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (kDebugMode) {
          debugPrint('No bids found for item $itemId ($itemType)');
        }
        return null;
      }

      final userData = response['users'] ?? {};
      final bidderName = userData['name'] ??
          userData['email']?.split('@').first ??
          'Anonymous';

      return {
        'bid_id': response['id'],
        'amount': response['amount'],
        'created_at': response['created_at'],
        'bidder_id': response['user_id'],
        'bidder_name': bidderName,
        'bidder_avatar': null,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching highest bid: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Displays the highest bidder status.
  Future<void> displayHighestBidderStatus(
      String itemId, String itemType) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      final highestBid = await getHighestBidWithBidder(itemId, itemType);

      if (highestBid == null) {
        debugPrint('No bids found for this item.');
        return;
      }

      final bidderName = highestBid['bidder_name'] ?? 'Anonymous';
      final bidderId = highestBid['bidder_id'];
      final currentUserId = supabase.auth.currentUser?.id;

      debugPrint('Highest bidder: $bidderName');

      if (bidderId == currentUserId) {
        debugPrint('You have won the bid!');
      } else {
        debugPrint('$bidderName is currently the highest bidder.');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  /// Streams bids for an auction.
  Stream<List<Map<String, dynamic>>> getBidsForAuction(
      String itemId, String itemType) {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    final channelKey = 'bids:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream
      as Stream<List<Map<String, dynamic>>>;
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final channel = supabase.channel(channelKey);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bids',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'item_id',
        value: itemId,
      ),
      callback: (payload) async {
        if (kDebugMode) {
          debugPrint('Bid change detected for $itemId ($itemType)');
        }
        try {
          final data = await supabase
              .from('bids')
              .select('''
                id, 
                amount, 
                created_at,
                user_id,
                users!user_id(
                  id,
                  email,
                  name
                )
              ''')
              .eq('item_id', itemId)
              .eq('item_type', itemType)
              .order('amount', ascending: false);

          final formattedBids = (data as List).map<Map<String, dynamic>>((bid) {
            final userData = bid['users'] ?? {};
            final bidderName = userData['name'] ??
                userData['email']?.split('@').first ??
                'Anonymous';
            return {
              ...Map<String, dynamic>.from(bid as Map),
              'bidder_name': bidderName,
              'bidder_avatar': null,
            };
          }).toList();
          controller.add(formattedBids);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error fetching bids: $e');
            debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
          }
        }
      },
    );
    channel.subscribe();
    _activeControllers[channelKey] = controller;
    _activeChannels[channelKey] = channel;

    supabase
        .from('bids')
        .select('''
          id, 
          amount, 
          created_at,
          user_id,
          users!user_id(
            id,
            email,
            name
          )
        ''')
        .eq('item_id', itemId)
        .eq('item_type', itemType)
        .order('amount', ascending: false)
        .then((data) {
      final formattedBids = (data as List).map<Map<String, dynamic>>((bid) {
        final userData = bid['users'] ?? {};
        final bidderName = userData['name'] ??
            userData['email']?.split('@').first ??
            'Anonymous';
        return {
          ...Map<String, dynamic>.from(bid as Map),
          'bidder_name': bidderName,
          'bidder_avatar': null,
        };
      }).toList();
      controller.add(formattedBids);
    })
        .catchError((e) {
      if (kDebugMode) {
        debugPrint('Initial bid fetch error: $e');
      }
      controller.addError(e);
    });

    controller.onCancel = () {
      if (kDebugMode) {
        debugPrint('Closing stream for $channelKey');
      }
      supabase.removeChannel(channel);
      _activeControllers.remove(channelKey);
      _activeChannels.remove(channelKey);
      controller.close();
    };

    return controller.stream;
  }

  /// Streams auction data by ID.
  Stream<Map<String, dynamic>?> getAuctionById(String itemId, String itemType) {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    final channelKey = 'auction:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream
      as Stream<Map<String, dynamic>?>;
    }

    final controller = StreamController<Map<String, dynamic>?>.broadcast();
    final channel = supabase.channel(channelKey);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: itemType,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: itemId,
      ),
      callback: (payload) async {
        if (kDebugMode) {
          debugPrint('Auction change detected for $itemId ($itemType)');
        }
        try {
          final data = await supabase
              .from(itemType)
              .select()
              .eq('id', itemId)
              .maybeSingle();
          controller.add(data);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error fetching auction: $e');
            debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
          }
        }
      },
    );
    channel.subscribe();
    _activeControllers[channelKey] = controller;
    _activeChannels[channelKey] = channel;

    supabase
        .from(itemType)
        .select()
        .eq('id', itemId)
        .maybeSingle()
        .then((data) => controller.add(data))
        .catchError((e) {
      if (kDebugMode) {
        debugPrint('Initial auction fetch error: $e');
      }
      controller.addError(e);
    });

    controller.onCancel = () {
      if (kDebugMode) {
        debugPrint('Closing stream for $channelKey');
      }
      supabase.removeChannel(channel);
      _activeControllers.remove(channelKey);
      _activeChannels.remove(channelKey);
      controller.close();
    };

    return controller.stream;
  }

  /// Places a bid on an auction.
  Future<void> placeBid({
    required String itemId,
    required String itemType,
    required double amount,
  }) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      if (kDebugMode) {
        debugPrint(
            'Attempting to place bid for item $itemId ($itemType) with amount $amount');
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('User not authenticated - cannot place bid');
        }
        throw Exception('User not authenticated');
      }

      final highestBid = await getHighestBidWithBidder(itemId, itemType);
      if (highestBid != null && amount <= (highestBid['amount'] as num)) {
        throw Exception('Bid amount must be higher than current highest bid');
      }

      await supabase.from('bids').insert({
        'item_id': itemId,
        'item_type': itemType,
        'user_id': userId,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('Bid placed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error placing bid: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Streams the number of registrations for an auction.
  Stream<int> getRegistrationCount(String itemId, String itemType) {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    final channelKey = 'registrations:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream as Stream<int>;
    }

    final controller = StreamController<int>.broadcast();
    final channel = supabase.channel(channelKey);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'auction_registrations',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'item_id',
        value: itemId,
      ),
      callback: (payload) async {
        if (kDebugMode) {
          debugPrint('Registration change detected for $itemId ($itemType)');
        }
        try {
          final data = await supabase
              .from('auction_registrations')
              .select()
              .eq('item_id', itemId)
              .eq('item_type', itemType);
          controller.add(data.length);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error fetching registration count: $e');
            debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
          }
        }
      },
    );
    channel.subscribe();
    _activeControllers[channelKey] = controller;
    _activeChannels[channelKey] = channel;

    supabase
        .from('auction_registrations')
        .select()
        .eq('item_id', itemId)
        .eq('item_type', itemType)
        .then((data) => controller.add(data.length))
        .catchError((e) {
      if (kDebugMode) {
        debugPrint('Initial registration count fetch error: $e');
      }
      controller.addError(e);
    });

    controller.onCancel = () {
      if (kDebugMode) {
        debugPrint('Closing stream for $channelKey');
      }
      supabase.removeChannel(channel);
      _activeControllers.remove(channelKey);
      _activeChannels.remove(channelKey);
      controller.close();
    };

    return controller.stream;
  }

  /// Registers a user for an auction.
  Future<void> registerForAuction({
    required String itemId,
    required String itemType,
  }) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final existingRegistration = await supabase
          .from('auction_registrations')
          .select()
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingRegistration != null) {
        throw Exception('User already registered for this auction');
      }

      await supabase.from('auction_registrations').insert({
        'user_id': userId,
        'item_id': itemId,
        'item_type': itemType,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('User $userId registered for auction $itemId ($itemType)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error registering for auction: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Streams winner data for an auction.
  Stream<Map<String, dynamic>?> getWinnerStream({
    required String itemId,
    required String itemType,
  }) {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    final channelKey = 'winner:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream
      as Stream<Map<String, dynamic>?>;
    }

    final controller = StreamController<Map<String, dynamic>?>.broadcast();
    final channel = supabase.channel(channelKey);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'auction_winners',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'item_id',
        value: itemId,
      ),
      callback: (payload) async {
        if (kDebugMode) {
          debugPrint('Winner change detected for $itemId ($itemType)');
        }
        try {
          final data = await supabase
              .from('auction_winners')
              .select('*, users!user_id(name, email)')
              .eq('item_id', itemId)
              .eq('item_type', itemType)
              .maybeSingle();
          controller.add(data);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error fetching winner: $e');
            debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
          }
        }
      },
    );
    channel.subscribe();
    _activeControllers[channelKey] = controller;
    _activeChannels[channelKey] = channel;

    supabase
        .from('auction_winners')
        .select('*, users!user_id(name, email)')
        .eq('item_id', itemId)
        .eq('item_type', itemType)
        .maybeSingle()
        .then((data) => controller.add(data))
        .catchError((e) {
      if (kDebugMode) {
        debugPrint('Initial winner fetch error: $e');
      }
      controller.addError(e);
    });

    controller.onCancel = () {
      if (kDebugMode) {
        debugPrint('Closing stream for $channelKey');
      }
      supabase.removeChannel(channel);
      _activeControllers.remove(channelKey);
      _activeChannels.remove(channelKey);
      controller.close();
    };

    return controller.stream;
  }

  /// Checks if the user is registered for an auction.
  Future<bool> isUserRegistered({
    required String itemId,
    required String itemType,
  }) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase
          .from('auction_registrations')
          .select()
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .eq('user_id', userId);

      return response.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking registration status: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Gets auctions registered by the current user.
  Future<List<Map<String, dynamic>>> getAuctionsRegisteredByUser() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('auction_registrations')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final registrations = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> enrichedRegistrations = [];

      for (var reg in registrations) {
        final itemType = reg['item_type'];
        final itemId = reg['item_id'];

        Map<String, dynamic>? itemData;
        if (itemType != null &&
            itemId != null &&
            _validItemTypes.contains(itemType)) {
          try {
            final itemResponse = await supabase
                .from(itemType)
                .select('*')
                .eq('id', itemId)
                .single();

            itemData = Map<String, dynamic>.from(itemResponse);
          } catch (e) {
            debugPrint('Error fetching item from $itemType table: $e');
          }
        }

        enrichedRegistrations.add({
          ...reg,
          'item_name': itemData?['bid_name'] ?? 'Unknown Item',
          'item_image': (itemData?['images'] as List?)?.firstOrNull,
          'end_time': itemData?['end_time'],
          'is_active': itemData?['is_active'],
          'item_data': itemData ?? {},
        });
      }

      return enrichedRegistrations;
    } catch (e) {
      debugPrint('Error fetching registered auctions: $e');
      rethrow;
    }
  }

  /// Gets auctions won by the current user.
  Future<List<Map<String, dynamic>>> getAuctionsWonByUser() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('auction_winners')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final winners = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> enrichedWinners = [];

      for (var winner in winners) {
        final itemType = winner['item_type'];
        final itemId = winner['item_id'];

        Map<String, dynamic>? itemData;
        if (itemType != null &&
            itemId != null &&
            _validItemTypes.contains(itemType)) {
          try {
            final itemResponse = await supabase
                .from(itemType)
                .select('*')
                .eq('id', itemId)
                .single();

            itemData = Map<String, dynamic>.from(itemResponse);
          } catch (e) {
            debugPrint('Error fetching item from $itemType table: $e');
          }
        }

        enrichedWinners.add({
          ...winner,
          'item_name': itemData?['bid_name'] ?? 'Unknown Item',
          'item_image': (itemData?['images'] as List?)?.firstOrNull,
          'item_data': itemData ?? {},
        });
      }

      return enrichedWinners;
    } catch (e) {
      debugPrint('Error fetching auctions won by user: $e');
      rethrow;
    }
  }

  /// Gets the number of reports for a bid.
  Future<int> getReportCount(String bidId) async {
    try {
      final response =
      await supabase.from('bid_reports').select('id').eq('bid_id', bidId);

      return response.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching report count for bid $bidId: $e');
      }
      rethrow;
    }
  }

  /// Reports a bid and checks if the report threshold is met.
  Future<void> reportBid(String bidId, String itemId, String itemType) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    try {
      if (kDebugMode) {
        debugPrint('=== STARTING BID REPORT PROCESS ===');
        debugPrint('Reporting bid: $bidId for item: $itemId ($itemType)');
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('❌ User not authenticated');
        }
        throw Exception('Authentication required');
      }

      if (kDebugMode) {
        debugPrint('User ID: $userId');
      }

      final bid = await supabase
          .from('bids')
          .select('user_id, item_id, item_type, amount')
          .eq('id', bidId)
          .maybeSingle();

      if (bid == null) {
        if (kDebugMode) {
          debugPrint('❌ Bid $bidId not found');
        }
        throw Exception('Bid not found');
      }

      if (kDebugMode) {
        debugPrint('Bid details: $bid');
      }

      if (bid['user_id'] == userId) {
        if (kDebugMode) {
          debugPrint('❌ User trying to report their own bid');
        }
        throw Exception('Cannot report your own bid');
      }

      if (bid['item_id'] != itemId || bid['item_type'] != itemType) {
        if (kDebugMode) {
          debugPrint('❌ Bid verification failed:');
          debugPrint('   Expected: $itemId ($itemType)');
          debugPrint('   Found: ${bid['item_id']} (${bid['item_type']})');
        }
        throw Exception('Bid does not belong to this auction');
      }

      final existingReport = await supabase
          .from('bid_reports')
          .select('id, created_at')
          .eq('bid_id', bidId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingReport != null) {
        if (kDebugMode) {
          debugPrint('❌ User already reported this bid: $existingReport');
        }
        throw Exception('You have already reported this bid');
      }

      final reportData = {
        'bid_id': bidId,
        'user_id': userId,
        'item_id': itemId,
        'item_type': itemType,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        debugPrint('Inserting report: $reportData');
      }

      final insertResult =
      await supabase.from('bid_reports').insert(reportData).select();

      if (kDebugMode) {
        debugPrint('Report insert result: $insertResult');
        debugPrint('✅ Bid report submitted successfully');
      }

      await handleReportThreshold(bidId, itemId, itemType);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error reporting bid: $e');
      }
      rethrow;
    }
  }

  /// Handles bid report threshold and deletes bid and auction item if necessary.
  /// Ensure the following database policies are set in Supabase:
  /// - Allow delete on bids: `create policy "Allow delete on bids" on public.bids for delete to authenticated using (true);`
  /// - Allow delete on art: `create policy "Allow delete on art" on public.art for delete to authenticated using (true);`
  /// - Allow delete on furniture: `create policy "Allow delete on furniture" on public.furniture for delete to authenticated using (true);`
  /// - Allow delete on car: `create policy "Allow delete on car" on public.car for delete to authenticated using (true);`
  /// - Allow delete on auction_winners: `create policy "Allow delete on auction_winners" on public.auction_winners for delete to authenticated using (true);`
  /// - Allow delete on auction_registrations: `create policy "Allow delete on auction_registrations" on public.auction_registrations for delete to authenticated using (true);`
  /// Alternatively, set up foreign key constraints with ON DELETE CASCADE:
  /// ```sql
  /// ALTER TABLE public.auction_winners
  /// ADD CONSTRAINT fk_auction_winners_item
  /// FOREIGN KEY (item_id, item_type)
  /// REFERENCES public.art (id, 'art') ON DELETE CASCADE;
  /// ```
  Future<void> handleReportThreshold(
      String bidId, String itemId, String itemType) async {
    if (!_validItemTypes.contains(itemType)) {
      throw Exception('Invalid item type: $itemType');
    }

    const threshold = 1; // Adjust threshold as needed (e.g., 3 for production)

    try {
      if (kDebugMode) {
        debugPrint('=== STARTING REPORT THRESHOLD CHECK ===');
        debugPrint('BidId: $bidId, ItemId: $itemId, ItemType: $itemType');
      }

      final reportCountResult =
      await supabase.from('bid_reports').select().eq('bid_id', bidId);

      final reportCount = reportCountResult.length;

      if (kDebugMode) {
        debugPrint(
            'Report count for bid $bidId: $reportCount (threshold: $threshold)');
        debugPrint('Reports found: $reportCountResult');
      }

      if (reportCount >= threshold) {
        if (kDebugMode) {
          debugPrint(
              '🚨 Report threshold reached! Starting deletion process...');
        }

        final bidBeforeDeletion = await supabase
            .from('bids')
            .select('*')
            .eq('id', bidId)
            .maybeSingle();

        if (bidBeforeDeletion == null) {
          if (kDebugMode) {
            debugPrint('❌ Bid $bidId not found in database');
          }
          return;
        }

        if (kDebugMode) {
          debugPrint('✅ Bid found before deletion: $bidBeforeDeletion');
        }

        if (bidBeforeDeletion['item_id'] != itemId ||
            bidBeforeDeletion['item_type'] != itemType) {
          if (kDebugMode) {
            debugPrint('❌ Bid verification failed:');
            debugPrint(
                '   Bid item_id: ${bidBeforeDeletion['item_id']} vs Expected: $itemId');
            debugPrint(
                '   Bid item_type: ${bidBeforeDeletion['item_type']} vs Expected: $itemType');
          }
          return;
        }

// Log existing data before deletion
        final existingBids = await supabase
            .from('bids')
            .select('*')
            .eq('item_id', itemId)
            .eq('item_type', itemType);
        final existingItem = await supabase
            .from(itemType)
            .select('*')
            .eq('id', itemId)
            .maybeSingle();
        final existingWinners = await supabase
            .from('auction_winners')
            .select('*')
            .eq('item_id', itemId)
            .eq('item_type', itemType);
        final existingRegistrations = await supabase
            .from('auction_registrations')
            .select('*')
            .eq('item_id', itemId)
            .eq('item_type', itemType);

        if (kDebugMode) {
          debugPrint('Before deletion:');
          debugPrint('  Existing bids: ${existingBids.length}');
          debugPrint('  Existing item exists: ${existingItem != null}');
          debugPrint('  Existing winners: ${existingWinners.length}');
          debugPrint(
              '  Existing registrations: ${existingRegistrations.length}');
        }

// Delete related data
        if (kDebugMode) {
          debugPrint(
              '🗑️ Deleting related auction_winners for item $itemId ($itemType)...');
        }
        final winnersDeleteResult = await supabase
            .from('auction_winners')
            .delete()
            .eq('item_id', itemId)
            .eq('item_type', itemType)
            .select();
        if (kDebugMode) {
          debugPrint('Winners deletion result: $winnersDeleteResult');
          debugPrint(
              'Number of winners deleted: ${winnersDeleteResult.length}');
        }

        if (kDebugMode) {
          debugPrint(
              '🗑️ Deleting related auction_registrations for item $itemId ($itemType)...');
        }
        final registrationsDeleteResult = await supabase
            .from('auction_registrations')
            .delete()
            .eq('item_id', itemId)
            .eq('item_type', itemType)
            .select();
        if (kDebugMode) {
          debugPrint(
              'Registrations deletion result: $registrationsDeleteResult');
          debugPrint(
              'Number of registrations deleted: ${registrationsDeleteResult.length}');
        }

// Delete all bids for this item
        if (kDebugMode) {
          debugPrint(
              '🗑️ Deleting all bids for item $itemId from bids table...');
        }
        final bidsDeleteResult = await supabase
            .from('bids')
            .delete()
            .eq('item_id', itemId)
            .eq('item_type', itemType)
            .select();
        if (kDebugMode) {
          debugPrint('Bids deletion result: $bidsDeleteResult');
          debugPrint('Number of bids deleted: ${bidsDeleteResult.length}');
        }

// Delete the auction item
        if (kDebugMode) {
          debugPrint(
              '🗑️ Deleting auction item $itemId from $itemType table...');
        }
        final itemDeleteResult =
        await supabase.from(itemType).delete().eq('id', itemId).select();
        if (kDebugMode) {
          debugPrint('Item deletion result: $itemDeleteResult');
          debugPrint('Number of items deleted: ${itemDeleteResult.length}');
        }

// Delete reports for the bid
        if (kDebugMode) {
          debugPrint('🗑️ Deleting reports for bid $bidId...');
        }
        final reportsDeleteResult = await supabase
            .from('bid_reports')
            .delete()
            .eq('bid_id', bidId)
            .select();
        if (kDebugMode) {
          debugPrint('Reports deletion result: $reportsDeleteResult');
          debugPrint(
              'Number of reports deleted: ${reportsDeleteResult.length}');
        }

// Verify deletions
        final remainingBids = await supabase
            .from('bids')
            .select('*')
            .eq('item_id', itemId)
            .eq('item_type', itemType);

        final remainingItem = await supabase
            .from(itemType)
            .select('*')
            .eq('id', itemId)
            .maybeSingle();

        final remainingReports =
        await supabase.from('bid_reports').select('*').eq('bid_id', bidId);

        final remainingWinners = await supabase
            .from('auction_winners')
            .select('*')
            .eq('item_id', itemId)
            .eq('item_type', itemType);

        final remainingRegistrations = await supabase
            .from('auction_registrations')
            .select('*')
            .eq('item_id', itemId)
            .eq('item_type', itemType);

        if (remainingBids.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('❌ ERROR: Bids still exist after deletion attempt!');
            debugPrint('Remaining bids: $remainingBids');
          }
          throw Exception('Failed to delete bids from database');
        }

        if (remainingItem != null) {
          if (kDebugMode) {
            debugPrint(
                '❌ ERROR: Auction item still exists after deletion attempt!');
            debugPrint('Remaining item data: $remainingItem');
          }
          throw Exception('Failed to delete auction item from database');
        }

        if (remainingReports.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('❌ ERROR: Reports still exist after deletion attempt!');
            debugPrint('Remaining reports: $remainingReports');
          }
          throw Exception('Failed to delete reports from database');
        }

        if (remainingWinners.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
                '❌ ERROR: Auction winners still exist after deletion attempt!');
            debugPrint('Remaining winners: $remainingWinners');
          }
          throw Exception('Failed to delete auction winners from database');
        }

        if (remainingRegistrations.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
                '❌ ERROR: Auction registrations still exist after deletion attempt!');
            debugPrint('Remaining registrations: $remainingRegistrations');
          }
          throw Exception(
              'Failed to delete auction registrations from database');
        }

        await _performFinalVerification(bidId, itemId, itemType);

        if (kDebugMode) {
          debugPrint(
              '✅ Fraudulent bid and auction item deletion process completed successfully');
          debugPrint('=== END REPORT THRESHOLD CHECK ===');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              'ℹ️ Report threshold not reached. Current: $reportCount, Required: $threshold');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ERROR in handleReportThreshold: $e');
        debugPrint('Stack trace: ${e is Error ? e.stackTrace : ''}');
      }
      rethrow;
    }
  }

  /// Verifies that all data related to a reported bid has been deleted.
  Future<void> _performFinalVerification(
      String bidId, String itemId, String itemType) async {
    try {
      if (kDebugMode) {
        debugPrint('=== PERFORMING FINAL VERIFICATION ===');
      }

      final remainingBid =
      await supabase.from('bids').select('*').eq('id', bidId).maybeSingle();

      final remainingItem = await supabase
          .from(itemType)
          .select('*')
          .eq('id', itemId)
          .maybeSingle();

      final remainingReports =
      await supabase.from('bid_reports').select('*').eq('bid_id', bidId);

      final remainingBidsForAuction = await supabase
          .from('bids')
          .select('id, amount, user_id')
          .eq('item_id', itemId)
          .eq('item_type', itemType)
          .order('amount', ascending: false);

      final remainingWinners = await supabase
          .from('auction_winners')
          .select('*')
          .eq('item_id', itemId)
          .eq('item_type', itemType);

      final remainingRegistrations = await supabase
          .from('auction_registrations')
          .select('*')
          .eq('item_id', itemId)
          .eq('item_type', itemType);

      if (kDebugMode) {
        debugPrint('Final verification results:');
        debugPrint('  Deleted bid still exists: ${remainingBid != null}');
        debugPrint(
            '  Deleted auction item still exists: ${remainingItem != null}');
        debugPrint(
            '  Deleted reports still exist: ${remainingReports.isNotEmpty}');
        debugPrint(
            '  Deleted winners still exist: ${remainingWinners.isNotEmpty}');
        debugPrint(
            '  Deleted registrations still exist: ${remainingRegistrations.isNotEmpty}');
        debugPrint(
            '  Remaining bids for auction: ${remainingBidsForAuction.length}');
        debugPrint('  Remaining bids details: $remainingBidsForAuction');

        if (remainingBid != null) {
          debugPrint('  ❌ CRITICAL: Bid $bidId still exists: $remainingBid');
        }
        if (remainingItem != null) {
          debugPrint(
              '  ❌ CRITICAL: Auction item $itemId still exists: $remainingItem');
        }
        if (remainingReports.isNotEmpty) {
          debugPrint('  ❌ CRITICAL: Reports still exist: $remainingReports');
        }
        if (remainingWinners.isNotEmpty) {
          debugPrint('  ❌ CRITICAL: Winners still exist: $remainingWinners');
        }
        if (remainingRegistrations.isNotEmpty) {
          debugPrint(
              '  ❌ CRITICAL: Registrations still exist: $remainingRegistrations');
        }
      }

      if (remainingBidsForAuction.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              '  ❌ CRITICAL: Bids still exist for deleted auction: $remainingBidsForAuction');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in final verification: $e');
      }
    }
  }

  /// Updates auction status after bid deletion (currently a no-op as auction is deleted).
  Future<void> _updateAuctionAfterBidDeletion(
      String itemId, String itemType) async {
    try {
      if (kDebugMode) {
        debugPrint(
            'No auction price update needed as auction item $itemId ($itemType) was deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in updateAuctionAfterBidDeletion: $e');
      }
    }
  }

  /// Disposes of all resources and closes streams.
  void dispose() {
    if (kDebugMode) {
      debugPrint('Disposing AuctionService and closing all channels');
    }
    supabase.removeChannel(_auctionChannel);
    for (final channel in _activeChannels.values) {
      supabase.removeChannel(channel);
    }
    for (final controller in _activeControllers.values) {
      controller.close();
    }
    _activeChannels.clear();
    _activeControllers.clear();
    _notifiedAuctionsStart.clear();
    _notifiedAuctionsEnd.clear();
  }
}
