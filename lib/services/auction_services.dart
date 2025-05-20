import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AuctionService {
  final SupabaseClient _supabase;
  RealtimeChannel? _bidChannel;
  bool _initialized = false;

  AuctionService({required SupabaseClient supabase}) : _supabase = supabase;

  void initialize() {
    if (_initialized) return;

    _bidChannel = _supabase.channel('auction_bids_${_supabase.auth.currentUser?.id ?? 'anon'}_${DateTime.now().millisecondsSinceEpoch}');
    _bidChannel?.subscribe((status, error) {
      if (kDebugMode) {
        print('Bid subscription status: $status');
        if (error != null) print('Bid subscription error: $error');
      }
    });

    _initialized = true;
  }

  Stream<Map<String, dynamic>?> getAuctionById(String itemId, String itemType) {
    if (!_initialized) initialize();

    return _supabase
        .from(itemType)
        .stream(primaryKey: ['id'])
        .eq('id', itemId)
        .limit(1)
        .map((list) => list.isEmpty ? null : list.first);
  }

  Stream<List<Map<String, dynamic>>> getBidsForAuction(String itemId, String itemType) {
    if (!_initialized) initialize();

    _bidChannel?.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'bids',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'item_id',
        value: itemId,
      ),
      callback: (payload) {
        if (kDebugMode) print('New bid placed: $payload');
      },
    );

    return _supabase
        .from('bids')
        .stream(primaryKey: ['id'])
        .eq('item_id', itemId)
        .order('amount', ascending: false);
  }

  Future<void> placeBid({
    required String itemId,
    required String itemType,
    required double amount,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      await _supabase.rpc('place_bid', params: {
        'item_id': itemId,
        'item_type': itemType,
        'amount': amount,
      });
    } catch (e) {
      if (kDebugMode) print('RPC failed, trying direct operation: $e');

      final currentBid = await _supabase
          .from('bids')
          .select()
          .eq('item_id', itemId)
          .order('amount', ascending: false)
          .limit(1)
          .maybeSingle();

      if (currentBid != null && amount <= (currentBid['amount'] as num).toDouble()) {
        throw Exception('Bid must be higher than current bid');
      }

      await _supabase.from('bids').insert({
        'item_id': itemId,
        'item_type': itemType,
        'user_id': userId,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> declareWinner({
    required String itemId,
    required String itemType,
  }) async {
    try {
      final result = await _supabase.rpc('declare_winner', params: {
        'item_id': itemId,
        'item_type': itemType,
      });

      if (result.error != null) throw Exception(result.error!.message);

      final winningBid = await _supabase
          .from('bids')
          .select()
          .eq('item_id', itemId)
          .order('amount', ascending: false)
          .limit(1)
          .single();

      await _notifyAuctionParticipants(itemId, itemType, winningBid['user_id']);
    } catch (e) {
      if (kDebugMode) print('Error declaring winner: $e');
      rethrow;
    }
  }

  Future<void> _notifyAuctionParticipants(
      String itemId,
      String itemType,
      String winnerId,
      ) async {
    try {
      // Get all participants except winner
      final participants = await _supabase
          .from('bids')
          .select('user_id')
          .eq('item_id', itemId)
          .neq('user_id', winnerId);

      // Get winner's player ID
      final winnerPlayerId = await _supabase
          .from('user_onesignal_ids')
          .select('player_id')
          .eq('user_id', winnerId)
          .maybeSingle();

      // Get item details
      final item = await _supabase
          .from(itemType)
          .select('title, price')
          .eq('id', itemId)
          .single();

      // Notify winner
      if (winnerPlayerId != null && winnerPlayerId['player_id'] != null) {
        await _supabase.functions.invoke('send-notification', body: {
          'player_id': winnerPlayerId['player_id'],
          'title': '🎉 Auction Winner!',
          'content': 'You won ${item['title']} for ${item['price']} PKR!',
          'data': {
            'item_id': itemId,
            'item_type': itemType,
            'event': 'auction_won',
          },
        });
      }

      // Notify other participants
      for (final participant in participants) {
        final playerId = await _supabase
            .from('user_onesignal_ids')
            .select('player_id')
            .eq('user_id', participant['user_id'])
            .maybeSingle();

        if (playerId != null && playerId['player_id'] != null) {
          await _supabase.functions.invoke('send-notification', body: {
            'player_id': playerId['player_id'],
            'title': 'Auction Completed',
            'content': 'The auction for ${item['title']} has ended',
            'data': {
              'item_id': itemId,
              'item_type': itemType,
              'event': 'auction_ended',
            },
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error notifying participants: $e');
    }
  }
  // Helper method to send notifications via a server-side solution
  void _sendServerSideNotification({
    required String playerId,
    required String title,
    required String content,
    required Map<String, dynamic> data,
  }) {
    try {
      if (kDebugMode) {
        print('Would send notification to player ID: $playerId');
        print('Title: $title');
        print('Content: $content');
        print('Data: $data');
      }

      // In a production environment, you would call your backend API here
      // to send the notification using OneSignal's REST API
      // Example: await _supabase.functions.invoke('send-notification', {
      //   'player_id': playerId,
      //   'title': title,
      //   'content': content,
      //   'data': data
      // });
    } catch (e) {
      if (kDebugMode) print('Error sending server-side notification: $e');
    }
  }

  void dispose() {
    _bidChannel?.unsubscribe();
    _initialized = false;
  }
}