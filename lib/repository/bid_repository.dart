// lib/repositories/bid_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class BidRepository {
  final SupabaseClient _supabase;

  BidRepository({required SupabaseClient supabase}) : _supabase = supabase;

  Future<Map<String, dynamic>> placeBid({
    required String itemId,
    required String itemType,
    required double amount,
  }) async {
    final response = await _supabase.rpc('place_bid', params: {
      'item_id': itemId,
      'item_type': itemType,
      'amount': amount,
    });

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    return response.data;
  }

  Stream<List<Map<String, dynamic>>> watchBids(String itemId, String itemType) {
    return _supabase
        .from('bids')
        .stream(primaryKey: ['id'])
        .eq('item_id', itemId)
        .eq('item_type', itemType)
        .order('amount', ascending: false);
  }

  Future<Map<String, dynamic>> declareWinner({
    required String itemId,
    required String itemType,
  }) async {
    final response = await _supabase.rpc('declare_winner', params: {
      'item_id': itemId,
      'item_type': itemType,
    });

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    return response.data;
  }
}