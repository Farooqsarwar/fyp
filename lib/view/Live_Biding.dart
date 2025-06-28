import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auction_services.dart';
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
  final SupabaseClient _supabase = Supabase.instance.client;
  late final AuctionService _auctionService;
  bool _isPlacingBid = false;
  bool _auctionEnded = false;
  double _currentBid = 0;
  List<Map<String, dynamic>> _bids = [];
  DateTime? _endTime;
  StreamSubscription? _bidsSubscription;
  StreamSubscription? _auctionSubscription;

  @override
  void initState() {
    super.initState();
    _auctionService = AuctionService(supabase: _supabase);
    _fetchInitialData();
    _setupRealtimeUpdates();
  }

  Future<void> _fetchInitialData() async {
    try {
      // Fetch auction details
      final auctionResponse = await _supabase
          .from(widget.itemType)
          .select()
          .eq('id', widget.itemId)
          .single();

      setState(() {
        _currentBid = (auctionResponse['price'] as num).toDouble();
        _endTime = DateTime.tryParse(auctionResponse['end_time'] ?? '');
        _auctionEnded = auctionResponse['is_active'] == false;
      });

      // Fetch initial bids
      await _fetchBids();
    } catch (e) {
      _showErrorSnackbar('Error fetching auction data: ${e.toString()}');
    }
  }

  Future<void> _fetchBids() async {
    try {
      final bidsResponse = await _supabase
          .from('bids')
          .select('id, user_id, amount, created_at, users!user_id(*)')
          .eq('item_id', widget.itemId)
          .eq('item_type', widget.itemType)
          .order('amount', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> bids = List<Map<String, dynamic>>.from(bidsResponse);
      final updatedBids = bids.map((bid) {
        final userData = bid['users'] ?? {};
        final rawData = userData['raw_user_meta_data'] as Map<String, dynamic>? ?? {};
        final userName = rawData['name'] ??
            userData['email']?.split('@').first ??
            'Anonymous';
        return {
          ...bid,
          'user_name': userName,
          'avatar_url': rawData['avatar_url']
        };
      }).toList();

      setState(() => _bids = updatedBids);
    } catch (e) {
      _showErrorSnackbar('Error fetching bids: ${e.toString()}');
    }
  }

  void _setupRealtimeUpdates() {
    // Listen for new bids
    _bidsSubscription = _auctionService.getBidsForAuction(widget.itemId, widget.itemType).listen((bids) {
      final updatedBids = bids.map((bid) {
        final userData = bid['users'] ?? {};
        final rawData = userData['raw_user_meta_data'] as Map<String, dynamic>? ?? {};
        final userName = rawData['name'] ??
            userData['email']?.split('@').first ??
            'Anonymous';
        return {
          ...bid,
          'user_name': userName,
          'avatar_url': rawData['avatar_url']
        };
      }).toList();

      setState(() {
        _bids = updatedBids;
        if (_bids.isNotEmpty) {
          _currentBid = (_bids.first['amount'] as num).toDouble();
        }
      });
    });

    // Listen for auction status changes
    _auctionSubscription = _auctionService.getAuctionById(widget.itemId, widget.itemType).listen((auction) {
      if (auction != null) {
        setState(() {
          _auctionEnded = !auction['is_active'];
          _endTime = DateTime.tryParse(auction['end_time'] ?? '');
          _currentBid = (auction['price'] as num).toDouble();
        });

        if (_auctionEnded) {
          _showAuctionEndedDialog();
        }
      }
    });
  }

  Future<void> _placeBid() async {
    if (_auctionEnded) {
      _showErrorSnackbar('Auction has ended');
      return;
    }

    final bidAmount = double.tryParse(_bidController.text);
    if (bidAmount == null || bidAmount <= _currentBid) {
      _showErrorSnackbar('Bid must be higher than ${_currentBid.toStringAsFixed(0)} PKR');
      return;
    }

    setState(() => _isPlacingBid = true);
    try {
      await _auctionService.placeBid(
        itemId: widget.itemId,
        itemType: widget.itemType,
        amount: bidAmount,
      );
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
          "This auction has ended. No more bids can be placed.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
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
    if (remaining.isNegative) return "Auction Ended";

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
                // Item Image
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

                // Auction Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _auctionEnded ? "Auction Ended" : "Ends In: ${_formatTimeRemaining()}",
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    Text(
                      "Highest Bid: ${_currentBid.toStringAsFixed(0)} PKR",
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Bids List
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
                          backgroundImage: bid['avatar_url'] != null
                              ? NetworkImage(bid['avatar_url'])
                              : null,
                          child: bid['avatar_url'] == null
                              ? Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          )
                              : null,
                        ),
                        titleText: username,
                        trailingText: "${(bid['amount'] as num).toStringAsFixed(0)} PKR",
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Bid Input
                if (!_auctionEnded) ...[
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
                          _bidController.text = (_currentBid + 1000).toStringAsFixed(0);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                    onPressed: _isPlacingBid ? null : _placeBid,
                    child: _isPlacingBid
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("Place Bid"),
                  ),
                ],
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
    _bidsSubscription?.cancel();
    _auctionSubscription?.cancel();
    _auctionService.dispose();
    super.dispose();
  }
}