import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_services.dart';
import '../utils/customlisttile.dart';
import '../utils/customtextfield.dart';

class LiveBidscreen extends StatefulWidget {
  final String itemId;
  final String itemType;
  final String itemTitle;
  final String imageUrl;

  const LiveBidscreen({
    super.key,
    required this.itemId,
    required this.itemType,
    required this.itemTitle,
    required this.imageUrl,
  });

  @override
  State<LiveBidscreen> createState() => _LiveBidscreenState();
}

class _LiveBidscreenState extends State<LiveBidscreen> {
  final TextEditingController _bidController = TextEditingController();
  final _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService(
    supabase: Supabase.instance.client,
  );

  bool _isPlacingBid = false;
  bool _auctionEnded = false;
  bool _auctionNotStarted = false;
  double _currentBid = 0;
  List<Map<String, dynamic>> _bids = [];
  DateTime? _endTime;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _fetchAuctionDetails();
    _setupRealtimeUpdates();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _notificationService.initialize(userId);
    }
  }

  Future<void> _fetchAuctionDetails() async {
    try {
      final auctionResponse = await _supabase
          .from(widget.itemType)
          .select()
          .eq('id', widget.itemId)
          .single();

      setState(() {
        _currentBid = (auctionResponse['price'] as num).toDouble();
        _endTime = DateTime.tryParse(auctionResponse['end_time'] ?? '');
        _startTime = DateTime.tryParse(auctionResponse['start_time'] ?? '');
        _auctionEnded = auctionResponse['is_active'] == false;
        _auctionNotStarted = _startTime != null && DateTime.now().isBefore(_startTime!);
      });

      await _fetchBids();
    } catch (e) {
      _showErrorSnackbar('Error fetching auction details: ${e.toString()}');
    }
  }

  Future<void> _fetchBids() async {
    try {
      final bidsResponse = await _supabase
          .from('bids')
          .select('id, user_id, amount')
          .eq('item_id', widget.itemId)
          .order('amount', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> bids = List<Map<String, dynamic>>.from(bidsResponse);
      final List<Map<String, dynamic>> updatedBids = [];

      for (final bid in bids) {
        final userId = bid['user_id'];
        String userName = 'Anonymous';

        if (userId != null) {
          try {
            final userResponse = await _supabase
                .from('users')
                .select('name')
                .eq('id', userId)
                .single();
            userName = userResponse['name'] ?? 'Anonymous';
          } catch (e) {
            debugPrint("Error fetching user name: $e");
          }
        }

        updatedBids.add({
          ...bid,
          'user_name': userName,
        });
      }

      setState(() => _bids = updatedBids);
    } catch (e) {
      _showErrorSnackbar('Error fetching bids: ${e.toString()}');
    }
  }

  void _setupRealtimeUpdates() {
    _supabase
        .from('bids')
        .stream(primaryKey: ['id'])
        .eq('item_id', widget.itemId)
        .order('amount', ascending: false)
        .limit(10)
        .listen((updatedBids) {
      if (updatedBids.isNotEmpty) {
        setState(() {
          _bids = updatedBids;
          _currentBid = (updatedBids.first['amount'] as num).toDouble();
        });
      }
    });

    _supabase
        .from(widget.itemType)
        .stream(primaryKey: ['id'])
        .eq('id', widget.itemId)
        .listen((updatedAuctions) {
      if (updatedAuctions.isNotEmpty) {
        final auction = updatedAuctions.first;
        setState(() {
          _auctionEnded = !auction['is_active'];
        });
        if (_auctionEnded) {
          _showAuctionEndedDialog();
        }
      }
    });
  }

  Future<void> _placeBid() async {
    final bidAmount = double.tryParse(_bidController.text);
    if (bidAmount == null || bidAmount <= _currentBid) {
      _showErrorSnackbar('Bid must be higher than ${_currentBid.toStringAsFixed(0)} PKR');
      return;
    }

    setState(() => _isPlacingBid = true);
    try {
      await _supabase.from('bids').insert({
        'item_id': widget.itemId,
        'item_type': widget.itemType,
        'amount': bidAmount,
        'user_id': _supabase.auth.currentUser?.id,
      });

      await _supabase
          .from(widget.itemType)
          .update({'price': bidAmount})
          .eq('id', widget.itemId);

      _bidController.clear();
      _showSuccessSnackbar('Bid placed successfully!');
    } catch (e) {
      _showErrorSnackbar('Error placing bid: ${e.toString()}');
    } finally {
      setState(() => _isPlacingBid = false);
    }
  }

  void _showAuctionEndedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Auction Ended",
          style: TextStyle(color: Colors.yellow),
        ),
        content: const Text(
          "This auction has ended. The winner will be notified shortly.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "VIEW RESULTS",
              style: TextStyle(color: Colors.yellow),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTimeRemaining() {
    if (_endTime == null) return "00:00:00";
    final remaining = _endTime!.difference(DateTime.now());
    if (remaining.isNegative) return "00:00:00";

    return "${remaining.inHours.remainder(24).toString().padLeft(2, '0')}:"
        "${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
        "${remaining.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  height: 250,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 250,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 80, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Ends In: ${_formatTimeRemaining()}",
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    Text(
                      "Highest Bid: ${_currentBid.toStringAsFixed(0)} PKR",
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _bids.isEmpty
                    ? const Center(
                  child: Text(
                    "No bids placed yet",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                )
                    : Column(
                  children: _bids.map((bid) {
                    final username = bid['user_name'] ?? 'Anonymous';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: CustomListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          child: Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        titleText: username,
                        trailingText:
                        "${(bid['amount'] as num).toStringAsFixed(0)} PKR",
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Your Bid",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        text: "Enter your bid",
                        controller: _bidController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.yellow),
                      onPressed: () {
                        _bidController.text =
                            (_currentBid + 1000).toStringAsFixed(0);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow),
                  onPressed: _isPlacingBid ? null : _placeBid,
                  child: _isPlacingBid
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("Place Bid"),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.black,
      ),
    );
  }

  @override
  void dispose() {
    _bidController.dispose();
    _notificationService.dispose();
    super.dispose();
  }
}