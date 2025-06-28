import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_services.dart';

class AuctionService {
  final SupabaseClient supabase;
  late final RealtimeChannel _auctionChannel;
  final Map<String, StreamController> _activeControllers = {};
  final Map<String, RealtimeChannel> _activeChannels = {};
  final Set<String> _notifiedAuctionsStart = {};
  final Set<String> _notifiedAuctionsEnd = {};

  AuctionService({required this.supabase}) {
    if (kDebugMode) {
      debugPrint('AuctionService initialized with Supabase client');
    }
  }

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
            debugPrint('Bids table updated: ${payload.oldRecord} → ${payload.newRecord}');
            debugPrint('Change type: ${payload.eventType}');
          }
        },
      )
      ..subscribe();

    if (kDebugMode) {
      debugPrint('Subscribed to public:auctions channel');
    }
  }

  /// Monitors auction status and triggers start/end notifications
  Future<void> monitorAuctionStatus({
    required String itemId,
    required String itemType,
    required NotificationService notificationService,
  }) async {
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
        debugPrint('Auction $itemId: start=$startTime, end=$endTime, active=$isActive');
      }

      // Check if auction has started
      if (startTime != null && DateTime.now().isAfter(startTime) && !isActive && !_notifiedAuctionsStart.contains(auctionKey)) {
        await supabase.from(itemType).update({'is_active': true}).eq('id', itemId);
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
      if (endTime != null && DateTime.now().isAfter(endTime) && isActive && !_notifiedAuctionsEnd.contains(auctionKey)) {
        await supabase.from(itemType).update({'is_active': false}).eq('id', itemId);
        await notificationService.sendAuctionEndNotification(
          itemId: itemId,
          itemType: itemType,
          itemTitle: itemTitle,
          endTime: endTime,
        );
        await checkAndDeclareWinner(
          itemId: itemId,
          itemType: itemType,
          notificationService: notificationService,
        );
        _notifiedAuctionsEnd.add(auctionKey);
        if (kDebugMode) {
          debugPrint('Auction $itemId ended, notification sent');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error monitoring auction status for $itemId ($itemType): $e');
      }
    }
  }

  /// Monitors all auctions periodically
  Future<void> monitorAllAuctions(NotificationService notificationService) async {
    try {
      if (kDebugMode) {
        debugPrint('Monitoring all auctions');
      }
      final auctionTypes = ['art', 'furniture'];
      for (final itemType in auctionTypes) {
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

  Future<Map<String, dynamic>?> checkAndDeclareWinner({
    required String itemId,
    required String itemType,
    required NotificationService notificationService,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Checking and declaring winner for item $itemId ($itemType)');
      }

      final auction = await supabase
          .from(itemType)
          .select('bid_name, images, is_active, end_time')
          .eq('id', itemId)
          .maybeSingle();

      if (auction == null) {
        if (kDebugMode) {
          debugPrint('No auction found for itemId: $itemId, itemType: $itemType');
        }
        return null;
      }

      if (auction['is_active'] ?? false) {
        if (kDebugMode) {
          debugPrint('Auction is still active for itemId: $itemId');
        }
        return null;
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

  Future<Map<String, dynamic>?> getHighestBidWithBidder(String itemId, String itemType) async {
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

  Future<void> displayHighestBidderStatus(String itemId, String itemType) async {
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

  Stream<List<Map<String, dynamic>>> getBidsForAuction(String itemId, String itemType) {
    final channelKey = 'bids:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream as Stream<List<Map<String, dynamic>>>;
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
    }).catchError((e) {
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

  Stream<Map<String, dynamic>?> getAuctionById(String itemId, String itemType) {
    final channelKey = 'auction:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream as Stream<Map<String, dynamic>?>;
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

  Future<void> placeBid({
    required String itemId,
    required String itemType,
    required double amount,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Attempting to place bid for item $itemId ($itemType) with amount $amount');
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

  Stream<int> getRegistrationCount(String itemId, String itemType) {
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

  Future<void> registerForAuction({
    required String itemId,
    required String itemType,
  }) async {
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

  Stream<Map<String, dynamic>?> getWinnerStream({
    required String itemId,
    required String itemType,
  }) {
    final channelKey = 'winner:$itemId:$itemType';

    if (_activeControllers.containsKey(channelKey)) {
      if (kDebugMode) {
        debugPrint('Reusing existing stream for $channelKey');
      }
      return _activeControllers[channelKey]!.stream as Stream<Map<String, dynamic>?>;
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

  Future<bool> isUserRegistered({
    required String itemId,
    required String itemType,
  }) async {
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