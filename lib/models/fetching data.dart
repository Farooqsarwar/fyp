import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BidsService {
  static final BidsService _instance = BidsService._internal();
  final SupabaseClient supabase = Supabase.instance.client;
  late final RealtimeChannel _bidsChannel;
  bool _isSubscribed = false;

  // Singleton factory constructor
  factory BidsService() {
    return _instance;
  }

  // Private constructor
  BidsService._internal() {
    _setupRealtimeUpdates();
  }

  void _setupRealtimeUpdates() {
    if (_isSubscribed) return;

    _bidsChannel = supabase.channel('public:bids')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'car',
        callback: (payload) => notifyListeners(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'furniture',
        callback: (payload) => notifyListeners(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'art',
        callback: (payload) => notifyListeners(),
      );

    _bidsChannel.subscribe();
    _isSubscribed = true;
  }

  // List of listeners to be notified of data changes
  final List<Function> _listeners = [];

  // Add a listener
  void addListener(Function callback) {
    if (!_listeners.contains(callback)) {
      _listeners.add(callback);
    }
  }

  // Remove a listener
  void removeListener(Function callback) {
    _listeners.remove(callback);
  }

  // Notify all listeners
  void notifyListeners() {
    for (var callback in _listeners) {
      callback();
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    if (_isSubscribed) {
      _bidsChannel.unsubscribe();
      _isSubscribed = false;
    }
  }

  // Fetch all bids (cars, furniture, art)
  Future<Map<String, dynamic>> fetchAllBids() async {
    try {
      // Fetch data from each category table
      final carResponse = await supabase.from('car').select('*');
      final furnitureResponse = await supabase.from('furniture').select('*');
      final artResponse = await supabase.from('art').select('*');

      // Process responses with proper type casting
      final carBids = (carResponse as List<dynamic>).map<Map<String, dynamic>>((b) =>
      {...b as Map<String, dynamic>, 'category': 'Car'}).toList();

      final furnitureBids = (furnitureResponse as List<dynamic>).map<Map<String, dynamic>>((b) =>
      {...b as Map<String, dynamic>, 'category': 'Furniture'}).toList();

      final artBids = (artResponse as List<dynamic>).map<Map<String, dynamic>>((b) =>
      {...b as Map<String, dynamic>, 'category': 'Art'}).toList();

      // Combine all bids for carousel (active bids first)
      final allBids = [...carBids, ...furnitureBids, ...artBids]
        ..sort((a, b) {
          final aActive = a['is_active'] == true;
          final bActive = b['is_active'] == true;
          if (aActive && !bActive) return -1;
          if (!aActive && bActive) return 1;
          return 0;
        });

      return {
        'allBids': allBids,
        'carBids': carBids,
        'furnitureBids': furnitureBids,
        'artBids': artBids,
      };
    } catch (e) {
      debugPrint("Error fetching bids: $e");
      rethrow;
    }
  }

  // Fetch car bids only
  Future<List<Map<String, dynamic>>> fetchCarBids() async {
    try {
      // Simplify the query to match how we retrieve cars in fetchAllBids
      final response = await supabase.from('car').select('*');

      // Debug information
      debugPrint("Car response length: ${(response as List).length}");
      if (response.isNotEmpty) {
        debugPrint("First car data: ${response[0]}");
      }

      // Process cars same as in fetchAllBids
      final carBids = response.map<Map<String, dynamic>>((b) =>
      {...b, 'category': 'Car'}).toList();

      return carBids;
    } catch (e) {
      debugPrint("Error fetching cars: $e");
      rethrow;
    }
  }
  // Fetch furniture bids only
  Future<List<Map<String, dynamic>>> fetchFurnitureBids() async {
    try {
      final response = await supabase.from('furniture').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching furniture: $e");
      rethrow;
    }
  }

  // Fetch art bids only
  Future<List<Map<String, dynamic>>> fetchArtBids() async {
    try {
      final response = await supabase.from('art').select('*');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching art: $e");
      rethrow;
    }
  }

  // Helper methods
  String getFirstImageUrl(dynamic item) {
    if (item['images'] == null) return '';

    if (item['images'] is List) {
      return item['images'].isNotEmpty ? item['images'][0] : '';
    } else if (item['images'] is String) {
      return item['images'];
    }
    return '';
  }

  String formatTitle(Map<String, dynamic> car) {
    return [
      car['make'],
      car['model'],
      car['year']
    ].where((part) => part != null).join(' ');
  }

  String formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    final dt = DateTime.parse(dateTime.toString());
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}