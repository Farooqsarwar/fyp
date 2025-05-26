import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/auction_services.dart';
import '../services/notification_services.dart';
import 'bidwinscreen.dart';
import 'Live_Biding.dart';

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
  State<ArtFurnitureDetailsScreen> createState() => _ArtFurnitureDetailsScreenState();
}

class _ArtFurnitureDetailsScreenState extends State<ArtFurnitureDetailsScreen> {
  final NotificationService _notificationService = NotificationService(
    supabase: Supabase.instance.client,
  );
  late final AuctionService _auctionService;
  final TextEditingController _bidController = TextEditingController();

  // State variables
  double _currentBid = 0;
  bool _isPlacingBid = false;
  bool _auctionEnded = false;
  bool _auctionNotStarted = false;
  bool _isRegistered = false;
  int _registeredUsersCount = 0;
  String? _highestBidderId;
  Map<String, dynamic>? _auctionWinner;
  bool _isCheckingWinner = false;
  bool _hasCheckedForWinner = false;

  // Stream subscriptions
  StreamSubscription<int>? _registrationCountSub;
  StreamSubscription<Map<String, dynamic>?>? _winnerSub;
  Timer? _auctionTimer;

  @override
  void initState() {
    super.initState();
    _auctionService = AuctionService(supabase: Supabase.instance.client);
    _auctionService.initialize();

    _currentBid = double.tryParse(widget.itemData?['price']?.toString() ?? '0') ?? 0;
    _updateAuctionStatus();
    _setupRealTimeUpdates();
    _checkRegistrationStatus();
    _setupRegistrationListener();
    _setupWinnerListener();
    _startAuctionTimer();
  }

  void _updateAuctionStatus() {
    final startTime = DateTime.tryParse(widget.itemData?['start_time'] ?? '');
    final endTime = DateTime.tryParse(widget.itemData?['end_time'] ?? '');
    final now = DateTime.now();

    final auctionNotStarted = startTime != null && now.isBefore(startTime);
    final auctionEnded = endTime != null && now.isAfter(endTime) ||
        (widget.itemData?['is_active'] == false);

    if (auctionNotStarted != _auctionNotStarted || auctionEnded != _auctionEnded) {
      setState(() {
        _auctionNotStarted = auctionNotStarted;
        _auctionEnded = auctionEnded;
      });

      if (_auctionEnded && !_hasCheckedForWinner) {
        _checkForWinner();
      }
    }
  }

  void _startAuctionTimer() {
    _auctionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateAuctionStatus();
      }
    });
  }

  void _setupRealTimeUpdates() {
    if (widget.itemData?['id'] == null) return;

    _auctionService
        .getBidsForAuction(
      widget.itemData!['id'],
      widget.isArt ? 'art' : 'furniture',
    )
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

    _auctionService
        .getAuctionById(
      widget.itemData!['id'],
      widget.isArt ? 'art' : 'furniture',
    )
        .listen((auction) {
      if (auction != null && mounted) {
        final startTime = DateTime.tryParse(auction['start_time'] ?? '');
        final endTime = DateTime.tryParse(auction['end_time'] ?? '');
        final now = DateTime.now();

        final auctionNotStarted = startTime != null && now.isBefore(startTime);
        final auctionEnded = endTime != null && now.isAfter(endTime) ||
            !(auction['is_active'] ?? false);

        if (auctionNotStarted != _auctionNotStarted || auctionEnded != _auctionEnded) {
          setState(() {
            _auctionNotStarted = auctionNotStarted;
            _auctionEnded = auctionEnded;
          });

          if (_auctionEnded && !_hasCheckedForWinner) {
            _checkForWinner();
          }
        }
      }
    });
  }

  void _setupWinnerListener() {
    if (widget.itemData?['id'] == null) return;

    _winnerSub = _auctionService
        .getWinnerStream(
      itemId: widget.itemData!['id'],
      itemType: widget.isArt ? 'art' : 'furniture',
    )
        .listen((winner) {
      if (mounted && winner != null && winner != _auctionWinner) {
        setState(() {
          _auctionWinner = winner;
          _hasCheckedForWinner = true;
        });
      }
    });
  }

  Future<void> _checkForWinner() async {
    if (_isCheckingWinner || widget.itemData?['id'] == null || _hasCheckedForWinner) return;

    setState(() {
      _isCheckingWinner = true;
      _hasCheckedForWinner = true;
    });

    try {
      final winner = await _auctionService.checkAndDeclareWinner(
        itemId: widget.itemData!['id'],
        itemType: widget.isArt ? 'art' : 'furniture',
        notificationService: _notificationService,
      );

      if (mounted && winner != null) {
        setState(() {
          _auctionWinner = winner;
        });
      }
    } catch (e) {
      debugPrint('Error checking for winner: $e');
      if (mounted) {
        setState(() {
          _hasCheckedForWinner = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingWinner = false);
      }
    }
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
  Future<void> _placeBid() async {
    final bidAmount = double.tryParse(_bidController.text);
    if (bidAmount == null || bidAmount <= _currentBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bid must be higher than ${_currentBid.toStringAsFixed(0)} PKR',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isPlacingBid = true);
    try {
      await _auctionService.placeBid(
        itemId: widget.itemData?['id'],
        itemType: widget.isArt ? 'art' : 'furniture',
        amount: bidAmount,
      );

      final registrations = await Supabase.instance.client
          .from('auction_registrations')
          .select('user_id')
          .eq('item_id', widget.itemData?['id'])
          .neq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '');

      for (final reg in registrations) {
        await _notificationService.sendNewBidNotification(
          userId: reg['user_id'],
          itemId: widget.itemData?['id'] ?? '',
          itemType: widget.isArt ? 'art' : 'furniture',
          itemTitle: widget.title,
          imageUrl: widget.imageUrl,
          amount: bidAmount.toStringAsFixed(0),
        );
      }

      _bidController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bid placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing bid: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Error placing bid: ${e.toString()}');
    } finally {
      setState(() => _isPlacingBid = false);
    }
  }

  void _navigateToLiveBidding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveBidscreen(
          itemId: widget.itemData?['id'] ?? '',
          itemType: widget.isArt ? 'art' : 'furniture',
          itemTitle: widget.title,
          imageUrl: widget.imageUrl,
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
          title: const Text('Item Details', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text('No item data available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final description = widget.itemData?['description'] ??
        (widget.isArt
            ? 'Beautiful handcrafted art piece by a local artist.'
            : 'High-quality furniture piece, perfect for any home.');

    final artist = widget.isArt ? (widget.itemData?['artist'] ?? 'Unknown Artist') : null;
    final medium = widget.isArt ? (widget.itemData?['medium'] ?? 'Mixed Media') : null;
    final dimensions = widget.isArt ? (widget.itemData?['dimensions'] ?? 'N/A') : null;

    final material = !widget.isArt ? (widget.itemData?['material'] ?? 'Wood') : null;
    final condition = !widget.isArt ? (widget.itemData?['condition'] ?? 'New') : null;

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
                    child: Icon(Icons.image_not_supported, size: 80, color: Colors.white),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.yellow),
                  ),
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
            if (_auctionEnded && _auctionWinner != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.yellow, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Auction Winner!',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Winning Bid: PKR ${_auctionWinner!['winning_amount']}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _navigateToWinnerScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'View Winner Details',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                children: widget.isArt
                    ? [
                  _buildDetailRow('Artist:', artist ?? 'Unknown'),
                  _buildDetailRow('Medium:', medium ?? 'N/A'),
                  _buildDetailRow('Dimensions:', dimensions ?? 'N/A'),
                ]
                    : [
                  _buildDetailRow('Material:', material ?? 'N/A'),
                  _buildDetailRow('Condition:', condition ?? 'N/A'),
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
            const SizedBox(height: 30),
            if (_auctionNotStarted) ...[
              _buildAuctionNotStartedUI()
            ] else if (!_auctionEnded) ...[
              if (!_isRegistered) ...[
                _buildRegistrationRequiredUI()
              ] else ...[
                _buildBiddingUI()
              ]
            ] else ...[
              _buildAuctionEndedUI()
            ],
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

  Widget _buildBiddingUI() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bidController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  hintText: "Enter bid amount",
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixText: "PKR ",
                  prefixStyle: const TextStyle(color: Colors.yellow),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.yellow),
              onPressed: () {
                final current = double.tryParse(_bidController.text) ?? 0;
                _bidController.text = (current + 1000).toStringAsFixed(0);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isPlacingBid ? null : _placeBid,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isPlacingBid
              ? const CircularProgressIndicator(color: Colors.black)
              : const Text(
            'Place Bid',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.live_tv, color: Colors.black),
                label: const Text(
                  "LIVE BIDDING",
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
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.analytics, color: Colors.white),
                label: const Text(
                  "BID RESULTS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _navigateToWinnerScreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuctionEndedUI() {
    final winnerName = _auctionWinner?['user']?['name'] ??
        _auctionWinner?['user']?['email']?.split('@').first ??
        'Anonymous';
    final winningAmount = _auctionWinner?['winning_amount']?.toString() ?? '0';

    return Column(
      children: [
        if (_auctionWinner == null && !_isCheckingWinner) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                children: [
                  Text(
                    "Auction has ended",
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
        ] else if (_isCheckingWinner) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(color: Colors.yellow),
                SizedBox(height: 16),
                Text(
                  "Determining winner...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, color: Colors.yellow, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Auction Winner!',
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Winner: $winnerName',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  'Winning Bid: PKR $winningAmount',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _navigateToWinnerScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'View Winner Details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _bidController.dispose();
    _registrationCountSub?.cancel();
    _winnerSub?.cancel();
    _auctionTimer?.cancel();
    _auctionService.dispose();
    super.dispose();
  }
}