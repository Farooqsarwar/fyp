import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/auction_services.dart';
import '../services/auction_notification_services.dart';
import 'bidwinscreen.dart';
import 'Live_Biding.dart';
import 'gemini sug.dart';

class ArtFurnitureDetailsScreen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final bool isArt;
  final Map<String, dynamic>? itemData;

  const ArtFurnitureDetailsScreen({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.isArt,
    this.itemData,
  });

  @override
  State<ArtFurnitureDetailsScreen> createState() =>
      _ArtFurnitureDetailsScreenState();
}

class _ArtFurnitureDetailsScreenState extends State<ArtFurnitureDetailsScreen> {
  final AuctionNotificationServices _notificationService =
      AuctionNotificationServices();
  late final AuctionService _auctionService;
  double _currentBid = 0;
  bool _auctionEnded = false;
  bool _auctionNotStarted = false;
  bool _isRegistered = false;
  int _registeredUsersCount = 0;
  String? _highestBidderId;
  String? _currentBidId;

  // Stream subscriptions
  StreamSubscription<int>? _registrationCountSub;
  Timer? _auctionTimer;

  @override
  void initState() {
    super.initState();
    _auctionService = AuctionService(supabase: Supabase.instance.client);
    _auctionService.initialize();
    _notificationService.initializeWithSupabase(Supabase.instance.client);

    _currentBid =
        double.tryParse(widget.itemData?['price']?.toString() ?? '0') ?? 0;
    _updateAuctionStatus();
    _setupRealTimeUpdates();
    _checkRegistrationStatus();
    _setupRegistrationListener();
  }

  void _updateAuctionStatus() {
    final startTime = DateTime.tryParse(widget.itemData?['start_time'] ?? '');
    final endTime = DateTime.tryParse(widget.itemData?['end_time'] ?? '');
    final now = DateTime.now();

    final auctionNotStarted = startTime != null && now.isBefore(startTime);
    final auctionEnded = endTime != null && now.isAfter(endTime) ||
        (widget.itemData?['is_active'] == false);

    if (auctionNotStarted != _auctionNotStarted ||
        auctionEnded != _auctionEnded) {
      setState(() {
        _auctionNotStarted = auctionNotStarted;
        _auctionEnded = auctionEnded;
      });
    }
  }

  void _setupRealTimeUpdates() {
    if (widget.itemData?['id'] == null) return;

    // Fetch bids every second
    _auctionTimer?.cancel(); // Cancel previous timer if exists
    _auctionTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      // 1. Fetch latest bids
      final bids = await _auctionService
          .getBidsForAuction(
            widget.itemData!['id'],
            widget.isArt ? 'art' : 'furniture',
          )
          .first;

      if (bids.isNotEmpty) {
        final newBid = (bids.first['amount'] as num).toDouble();
        if (newBid != _currentBid) {
          setState(() {
            _currentBid = newBid;
            _highestBidderId = bids.first['user_id'] as String?;
            _currentBidId = bids.first['id'] as String?;
          });
        }
      }

      // 2. Fetch latest auction status
      final auction = await _auctionService
          .getAuctionById(
            widget.itemData!['id'],
            widget.isArt ? 'art' : 'furniture',
          )
          .first;

      if (auction != null) {
        final startTime = DateTime.tryParse(auction['start_time'] ?? '');
        final endTime = DateTime.tryParse(auction['end_time'] ?? '');
        final now = DateTime.now();

        final auctionNotStarted = startTime != null && now.isBefore(startTime);
        final auctionEnded = endTime != null && now.isAfter(endTime) ||
            !(auction['is_active'] ?? false);

        if (auctionNotStarted != _auctionNotStarted ||
            auctionEnded != _auctionEnded) {
          setState(() {
            _auctionNotStarted = auctionNotStarted;
            _auctionEnded = auctionEnded;
          });
        }
      }
    });
  }

  Future<void> _checkRegistrationStatus() async {
    if (widget.itemData?['id'] == null) return;

    final isRegistered = await _auctionService.isUserRegistered(
      itemId: widget.itemData!['id'],
      itemType: widget.isArt ? 'art' : 'furniture',
    );
    if (mounted && isRegistered != _isRegistered) {
      setState(() => _isRegistered = isRegistered);
    }
  }

  void _setupRegistrationListener() {
    if (widget.itemData?['id'] == null) return;
    _registrationCountSub = _auctionService
        .getRegistrationCount(
      widget.itemData!['id'],
      widget.isArt ? 'art' : 'furniture',
    )
        .listen((count) {
      if (mounted && count != _registeredUsersCount) {
        setState(() => _registeredUsersCount = count);
      }
    });
  }

  Future<void> _registerForAuction() async {
    if (widget.itemData?['id'] == null) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await Supabase.instance.client.from('auction_registrations').insert({
        'user_id': userId,
        'item_id': widget.itemData!['id'],
        'item_type': widget.isArt ? 'art' : 'furniture',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _isRegistered = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully registered for auction!')),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) {
          setState(() => _isRegistered = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Already registered for this auction!')),
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

// Add this to your UI after successful bid reporting
  Future<void> _reportCurrentBid() async {
    if (_currentBidId == null) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to report bids')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            backgroundColor: Colors.black,
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.yellow),
                SizedBox(width: 20),
                Text('Processing report...',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
      );

      await _auctionService.reportBid(
        _currentBidId!,
        widget.itemData!['id'],
        widget.isArt ? 'art' : 'furniture',
      );

      // Force refresh the data after reporting
      await _forceRefreshAuctionData();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bid reported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting bid: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error reporting bid: ${e.toString()}');
    }
  }

// Add this method to force refresh auction data
  Future<void> _forceRefreshAuctionData() async {
    try {
      // Cancel existing streams
      _registrationCountSub?.cancel();
      _auctionTimer?.cancel();

      // Wait a moment for the database to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch fresh auction data
      final freshAuction = await _auctionService
          .getAuctionById(
            widget.itemData!['id'],
            widget.isArt ? 'art' : 'furniture',
          )
          .first;

      if (freshAuction == null) {
        // Auction was deleted
        if (mounted) {
          Navigator.pop(context); // Navigate back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auction has been removed due to reported bid'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Fetch fresh bids
      final freshBids = await _auctionService
          .getBidsForAuction(
            widget.itemData!['id'],
            widget.isArt ? 'art' : 'furniture',
          )
          .first;

      if (mounted) {
        setState(() {
          // Update current bid
          if (freshBids.isNotEmpty) {
            _currentBid = (freshBids.first['amount'] as num).toDouble();
            _highestBidderId = freshBids.first['user_id'] as String?;
            _currentBidId = freshBids.first['id'] as String?;
          } else {
            // No bids remaining, reset to starting price
            _currentBid =
                double.tryParse(widget.itemData?['price']?.toString() ?? '0') ??
                    0;
            _highestBidderId = null;
            _currentBidId = null;
          }

          // Update auction status
          final startTime = DateTime.tryParse(freshAuction['start_time'] ?? '');
          final endTime = DateTime.tryParse(freshAuction['end_time'] ?? '');
          final now = DateTime.now();

          _auctionNotStarted = startTime != null && now.isBefore(startTime);
          _auctionEnded = endTime != null && now.isAfter(endTime) ||
              !(freshAuction['is_active'] ?? false);
        });
      }

      // Restart real-time updates
      _setupRealTimeUpdates();
      _setupRegistrationListener();

      debugPrint('Auction data refreshed successfully');
    } catch (e) {
      debugPrint('Error refreshing auction data: $e');
    }
  }

  Future<void> _navigateToWinnerScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BidWinScreen(
          imageUrl: widget.imageUrl,
          itemTitle: widget.title,
          itemId: widget.itemData!['id'],
          itemType: widget.isArt ? 'art' : 'furniture',
          supabase: Supabase.instance.client,
          auctionService: _auctionService,
          notificationService: _notificationService,
        ),
      ),
    );
  }

  void _navigateToLiveBidding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveBidscreen(
          itemId: widget.itemData?['id'] ?? '',
          itemType: widget.isArt ? 'art' : 'furniture',
          itemTitle: widget.title,
          imageUrl: widget.imageUrl, currentbid: _currentBid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemData == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title:
              const Text('Item Details', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text('No item data available',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final description = widget.itemData?['description'] ??
        (widget.isArt
            ? 'Beautiful handcrafted art piece by a local artist.'
            : 'High-quality furniture piece, perfect for any home.');

    final artist =
        widget.isArt ? (widget.itemData?['artist'] ?? 'Unknown Artist') : null;
    final material =
        !widget.isArt ? (widget.itemData?['material'] ?? 'Wood') : null;
    final condition =
        !widget.isArt ? (widget.itemData?['condition'] ?? 'New') : null;

    final startTime = widget.itemData?['start_time'] != null
        ? DateFormat.yMd()
            .add_jm()
            .format(DateTime.parse(widget.itemData!['start_time']))
        : 'N/A';
    final endTime = widget.itemData?['end_time'] != null
        ? DateFormat.yMd()
            .add_jm()
            .format(DateTime.parse(widget.itemData!['end_time']))
        : 'N/A';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isArt ? 'Art Details' : 'Furniture Details',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.image_not_supported,
                        size: 80, color: Colors.white),
                  ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.yellow),
                  ),
                  child: Text(
                    'PKR ${_formatSmart(_currentBid)}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (!_auctionEnded && _currentBid > 0)
              TextButton(
                onPressed: _reportCurrentBid,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.yellow.withOpacity(0.2),
                  foregroundColor: Colors.red,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.report, size: 16),
                    SizedBox(width: 4),
                    Text('Report this bid'),
                  ],
                ),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 20),
            const Text(
              'Details',
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
                  if (widget.isArt)
                    _buildDetailRow('Artist:', artist ?? 'Unknown'),
                  _buildDetailRow('Material:',
                      material ?? widget.itemData?['material'] ?? 'N/A'),
                  _buildDetailRow('Condition:',
                      condition ?? widget.itemData?['condition'] ?? 'N/A'),
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
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 250,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GeminiInsightsScreen(
                          imageUrl: widget.imageUrl,
                          title: widget.title,
                          isArt: widget.isArt,
                        ),
                      ),
                    );
                  },
                  icon:
                      const Icon(Icons.lightbulb_outline, color: Colors.black),
                  label: const Text(
                    'AI Suggestions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_auctionNotStarted)
              _buildAuctionNotStartedUI()
            else if (!_auctionEnded)
              if (!_isRegistered)
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
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            "Auction starts on ${widget.itemData?['start_time'] ?? 'N/A'}",
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isRegistered ? null : _registerForAuction,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRegistered ? Colors.grey : Colors.yellow,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              _isRegistered ? 'Registered' : 'Register for Auction',
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
            onPressed: _registerForAuction,
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
    _auctionTimer?.cancel();
    _auctionService.dispose();
    super.dispose();
  }

  String _formatSmart(double number) {
    // If number is >= 1 million, use shortened format (1m, 1b)
    if (number >= 1000000) {
      if (number >= 1000000000) {
        return '${(number / 1000000000).toStringAsFixed(1)}b';
      }
      return '${(number / 1000000).toStringAsFixed(1)}m';
    }
    // Else, use comma-separated format (e.g., 10,000)
    else {
      return number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
      );
    }
  }
}
