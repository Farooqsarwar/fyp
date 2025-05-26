import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BidsService extends ChangeNotifier {
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
        table: 'cars',
        callback: (payload) {
          if (kDebugMode) debugPrint('Cars table updated: $payload');
          notifyListeners();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'furniture',
        callback: (payload) {
          if (kDebugMode) debugPrint('Furniture table updated: $payload');
          notifyListeners();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'art',
        callback: (payload) {
          if (kDebugMode) debugPrint('Art table updated: $payload');
          notifyListeners();
        },
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
  @override
  void notifyListeners() {
    for (var callback in _listeners) {
      callback();
    }
    super.notifyListeners();
  }

  // Dispose method to clean up resources
  void dispose() {
    if (_isSubscribed) {
      _bidsChannel.unsubscribe();
      _isSubscribed = false;
    }
    super.dispose();
  }

  // Fetch all bids (cars, furniture, art)
  Future<Map<String, List<Map<String, dynamic>>>> fetchAllBids() async {
    try {
      final carResponse = await supabase.from('cars').select();
      final furnitureResponse = await supabase.from('furniture').select();
      final artResponse = await supabase.from('art').select();

      final carBids = (carResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((b) => {...b, 'item_type': 'cars'})
          .toList();

      final furnitureBids = (furnitureResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((b) => {...b, 'item_type': 'furniture'})
          .toList();

      final artBids = (artResponse as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((b) => {...b, 'item_type': 'art'})
          .toList();

      final allBids = [...carBids, ...furnitureBids, ...artBids]
        ..sort((a, b) {
          final aActive = a['is_active'] == true;
          final bActive = b['is_active'] == true;
          if (aActive && !bActive) return -1;
          if (!aActive && bActive) return 1;
          return 0;
        });

      if (kDebugMode) {
        debugPrint('Fetched ${carBids.length} car bids, ${furnitureBids.length} furniture bids, ${artBids.length} art bids');
      }

      return {
        'allBids': allBids,
        'carBids': carBids,
        'furnitureBids': furnitureBids,
        'artBids': artBids,
      };
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Error fetching bids: $e\n$stack');
      rethrow;
    }
  }

  // Fetch car bids only
  Future<List<Map<String, dynamic>>> fetchCarBids() async {
    try {
      final response = await supabase.from('cars').select();
      final carBids = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((b) => {...b, 'item_type': 'cars'})
          .toList();
      if (kDebugMode) {
        debugPrint('Car bids fetched: ${carBids.length}');
        if (carBids.isNotEmpty) debugPrint('First car: ${carBids[0]}');
      }
      return carBids;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Error fetching car bids: $e\n$stack');
      rethrow;
    }
  }

  // Fetch furniture bids only
  Future<List<Map<String, dynamic>>> fetchFurnitureBids() async {
    try {
      final response = await supabase.from('furniture').select();
      final furnitureBids = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((b) => {...b, 'item_type': 'furniture'})
          .toList();
      if (kDebugMode) debugPrint('Furniture bids fetched: ${furnitureBids.length}');
      return furnitureBids;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Error fetching furniture bids: $e\n$stack');
      rethrow;
    }
  }

  // Fetch art bids only
  Future<List<Map<String, dynamic>>> fetchArtBids() async {
    try {
      final response = await supabase.from('art').select();
      final artBids = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((b) => {...b, 'item_type': 'art'})
          .toList();
      if (kDebugMode) debugPrint('Art bids fetched: ${artBids.length}');
      return artBids;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Error fetching art bids: $e\n$stack');
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

  String formatTitle(Map<String, dynamic> cars) {
    return [
      cars['make'],
      cars['model'],
      cars['year']
    ].where((part) => part != null).join(' ');
  }

  String formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    final dt = DateTime.parse(dateTime.toString());
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final amPm = dt.hour >= 12 ? 'pm' : 'am';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day}/${dt.year} - $hour:$minute $amPm';
  }
}