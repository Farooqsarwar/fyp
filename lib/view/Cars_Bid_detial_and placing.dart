import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/auction_services.dart';
import '../services/auction_notification_services.dart';
import 'Live_Biding.dart';
import 'Predict_price_screen.dart';
import 'bidwinscreen.dart';

class CarBidDetailsScreen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final Map<String, dynamic>? itemData;

  const CarBidDetailsScreen({
    super.key,
    required this.imageUrl,
    required this.title,
    this.itemData,
  });

  @override
  State<CarBidDetailsScreen> createState() => _CarBidDetailsScreenState();
}

class _CarBidDetailsScreenState extends State<CarBidDetailsScreen> {
  final supabase = Supabase.instance.client;
  late final AuctionService auctionService;
  final AuctionNotificationServices _notificationService = AuctionNotificationServices();
  double _currentBid = 0;
  bool _auctionEnded = false;
  bool _auctionNotStarted = false;
  bool isRegistered = false;
  int _registeredUsersCount = 0;
  String? _highestBidderId;
  String _timeRemaining = "00:00:00";
  StreamSubscription<int>? _registrationCountSub;
  StreamSubscription<List<Map<String, dynamic>>>? _bidsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _auctionSubscription;

  @override
  void initState() {
    super.initState();
    auctionService = AuctionService(supabase: supabase);
    auctionService.initialize();
    _currentBid = double.tryParse(widget.itemData?['price']?.toString() ?? '0') ?? 0;
    _setupRealTimeUpdates();
    _checkRegistration();
  }

  void _setupRealTimeUpdates() {
    // Real-time bids updates
    _bidsSubscription = auctionService
        .getBidsForAuction(widget.itemData?['id'], 'cars')
        .listen((bids) {
      if (bids.isNotEmpty && mounted) {
        final newBid = (bids.first['amount'] as num).toDouble();
        if (newBid != _currentBid) {
          setState(() {
            _currentBid = newBid;
            _highestBidderId = bids.first['user_id'] as String?;
          });
        }
      }
    });

    // Real-time auction status updates
    _auctionSubscription = auctionService
        .getAuctionById(widget.itemData?['id'], 'cars')
        .listen((auction) {
      if (auction != null && mounted) {
        final startTime = DateTime.tryParse(auction['start_time'] ?? '');
        final endTime = DateTime.tryParse(auction['end_time'] ?? '');
        final now = DateTime.now();

        final auctionNotStarted = startTime != null && now.isBefore(startTime);
        final auctionEnded = endTime != null && now.isAfter(endTime) ||
            !(auction['is_active'] ?? false);

        if (mounted) {
          setState(() {
            _auctionNotStarted = auctionNotStarted;
            _auctionEnded = auctionEnded;
            widget.itemData?['is_active'] = auction['is_active'];
            widget.itemData?['start_time'] = auction['start_time'];
            widget.itemData?['end_time'] = auction['end_time'];
          });
        }
      }
    });

    // Real-time registration count updates
    if (widget.itemData?['id'] != null) {
      _registrationCountSub = auctionService
          .getRegistrationCount(widget.itemData!['id'], 'cars')
          .listen((count) {
        if (mounted && count != _registeredUsersCount) {
          setState(() => _registeredUsersCount = count);
        }
      });
    }
  }

  Future<void> _checkRegistration() async {
    if (widget.itemData?['id'] == null) return;

    try {
      final currentRegistration = await auctionService.isUserRegistered(
        itemId: widget.itemData!['id'],
        itemType: 'cars',
      );

      if (mounted && currentRegistration != isRegistered) {
        setState(() => isRegistered = currentRegistration);
      }
    } catch (e) {
      debugPrint('Error checking registration: $e');
    }
  }

  Future<void> _register() async {
    if (widget.itemData?['id'] == null) return;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('auction_registrations').insert({
        'user_id': userId,
        'item_id': widget.itemData!['id'],
        'item_type': 'cars',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => isRegistered = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully registered for auction!')),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) {
          setState(() => isRegistered = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Already registered for this auction!')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering: ${e.message}')),
        );
      }
      debugPrint('Error registering: ${e.toString()}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering: ${e.toString()}')),
        );
      }
      debugPrint('Error registering: ${e.toString()}');
    }
  }

  void _navigateToLiveBidding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveBidscreen(
          itemId: widget.itemData?['id'] ?? '',
          itemType: 'cars',
          itemTitle: widget.title,
          imageUrl: widget.imageUrl,
        ),
      ),
    );
  }

  void _navigateToPredictScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PredictScreen(
          imageurl: widget.imageUrl,
          carData: widget.itemData,
        ),
      ),
    );
  }

  Future<void> _navigateToWinnerScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BidWinScreen(
          imageUrl: widget.imageUrl,
          itemTitle: widget.title,
          itemId: widget.itemData!['id'],
          itemType: 'cars',
          supabase: Supabase.instance.client,
          auctionService: auctionService,
          notificationService: _notificationService,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionNotStartedUI() {
    final startTime = widget.itemData?['start_time'] != null
        ? DateFormat.yMd().add_jm().format(DateTime.parse(widget.itemData!['start_time']))
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            "Auction starts on $startTime",
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isRegistered ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: isRegistered ? Colors.grey : Colors.yellow,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              isRegistered ? 'Registered' : 'Register for Auction',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationRequiredUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'You must register before you can bid',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Register Now',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAuctionUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.live_tv, color: Colors.black),
                label: const Text(
                  "GO TO LIVE BIDDING",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _navigateToLiveBidding,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuctionEndedUI() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              "Auction has ended",
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _navigateToWinnerScreen,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'View Results',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _registrationCountSub?.cancel();
    _bidsSubscription?.cancel();
    _auctionSubscription?.cancel();
    auctionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Details')),
        body: const Center(child: Text('No item data available')),
      );
    }

    final description = widget.itemData?['description'] ??
        'Premium vehicle in excellent condition with complete service history';
    final make = widget.itemData?['make'] ?? 'Unknown';
    final model = widget.itemData?['model'] ?? 'Unknown';
    final year = widget.itemData?['year']?.toString() ?? 'N/A';
    final distance = widget.itemData?['distance']?.toString() ?? 'N/A';
    final transmission = widget.itemData?['transmission'] ?? 'Automatic';
    final fuel = widget.itemData?['fuel'] ?? 'Petrol';
    final horsePower = widget.itemData?['horse_power']?.toString() ?? 'N/A';
    final registrationCity = widget.itemData?['registration_city'] ?? 'N/A';
    final startTime = widget.itemData?['start_time'] != null
        ? DateFormat.yMd().add_jm().format(DateTime.parse(widget.itemData!['start_time']))
        : 'N/A';
    final endTime = widget.itemData?['end_time'] != null
        ? DateFormat.yMd().add_jm().format(DateTime.parse(widget.itemData!['end_time']))
        : 'N/A';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Car Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(widget.imageUrl.isNotEmpty
                      ? widget.imageUrl
                      : 'https://via.placeholder.com/300x200?text=No+Image'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.yellow)),
                  child: Text(
                    'PKR ${_currentBid.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.yellow, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_registeredUsersCount users registered',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    _timeRemaining,
                    style: TextStyle(
                      color: _auctionEnded ? Colors.red : Colors.yellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vehicle Specifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Make:', make),
                  _buildDetailRow('Model:', model),
                  _buildDetailRow('Year:', year),
                  _buildDetailRow('Distance:', '$distance km'),
                  _buildDetailRow('Transmission:', transmission),
                  _buildDetailRow('Fuel:', fuel),
                  _buildDetailRow('Horse Power:', horsePower),
                  _buildDetailRow('Registration City:', registrationCity),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Auction Timing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Starts:', startTime),
                  _buildDetailRow('Ends:', endTime),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                description,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.calculate, color: Colors.black),
              label: const Text(
                "PREDICT MARKET PRICE",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _navigateToPredictScreen,
            ),
            const SizedBox(height: 10),
            if (_auctionNotStarted)
              _buildAuctionNotStartedUI()
            else if (!_auctionEnded)
              if (!isRegistered)
                _buildRegistrationRequiredUI()
              else
                _buildActiveAuctionUI()
            else
              _buildAuctionEndedUI(),
          ],
        ),
      ),
    );
  }
}