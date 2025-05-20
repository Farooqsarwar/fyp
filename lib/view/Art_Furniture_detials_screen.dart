import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auction_services.dart';
import '../services/notification_services.dart';
import 'bidwinscreen.dart';
import 'Live_Biding.dart';

class Art_Furniture_Detials_Screen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final bool isArt;
  final Map<String, dynamic>? itemData;

  const Art_Furniture_Detials_Screen({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.isArt,
    this.itemData,
  });

  @override
  State<Art_Furniture_Detials_Screen> createState() => _Art_Furniture_Detials_ScreenState();
}

class _Art_Furniture_Detials_ScreenState extends State<Art_Furniture_Detials_Screen> {
  final AuctionService _auctionService = AuctionService(
    supabase: Supabase.instance.client,
  );
  final NotificationService _notificationService = NotificationService(
    supabase: Supabase.instance.client,
  );
  final TextEditingController _bidController = TextEditingController();
  double _currentBid = 0;
  bool _isPlacingBid = false;
  bool _auctionEnded = false;
  String? _highestBidderId;

  @override
  void initState() {
    super.initState();
    _currentBid = double.tryParse(widget.itemData?['price']?.toString() ?? '0') ?? 0;
    _setupRealTimeUpdates();
  }

  void _setupRealTimeUpdates() {
    // Listen for new bids
    _auctionService.getBidsForAuction(widget.itemData?['id'], widget.isArt ? 'art' : 'furniture').listen((bids) {
      if (bids.isNotEmpty) {
        setState(() {
          _currentBid = (bids.first['amount'] as num).toDouble();
          _highestBidderId = bids.first['user_id'] as String?;
        });
      }
    });

    // Listen for auction status changes
    _auctionService.getAuctionById(widget.itemData?['id'], widget.isArt ? 'art' : 'furniture').listen((auction) {
      if (auction != null && auction['is_active'] == false) {
        setState(() {
          _auctionEnded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract item details from itemData
    final description = widget.itemData?['description'] ??
        (widget.isArt
            ? 'Beautiful handcrafted art piece by a local artist.'
            : 'High-quality furniture piece, perfect for any home.');

    // Art-specific details
    final artist = widget.isArt ? (widget.itemData?['artist'] ?? 'Unknown Artist') : null;
    final medium = widget.isArt ? (widget.itemData?['medium'] ?? 'Mixed Media') : null;
    final dimensions = widget.isArt ? (widget.itemData?['dimensions'] ?? 'N/A') : null;

    // Furniture-specific details
    final material = !widget.isArt ? (widget.itemData?['material'] ?? 'Wood') : null;
    final condition = !widget.isArt ? (widget.itemData?['condition'] ?? 'New') : null;

    // Common details
    final startTime = widget.itemData?['start_time'] ?? 'N/A';
    final endTime = widget.itemData?['end_time'] ?? 'N/A';

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
            // Main Image
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

            // Title and Price Section
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

            // Description Section
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

            // Details Section
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

            // Auction Timing Section
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
                  _buildDetailRow('Starts:', startTime.toString()),
                  _buildDetailRow('Ends:', endTime.toString()),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Action Buttons
            if (!_auctionEnded) ...[
              // Place Bid Section
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFECD801),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isPlacingBid ? null : _placeBid,
                child: _isPlacingBid
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                  "PLACE BID",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Live Bidding & Bid Results buttons
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
                      onPressed: () => _navigateToLiveBidding(),
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
                      onPressed: () {
                        // When navigating to BidWinScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BidWinScreen(
                              imageUrl: widget.imageUrl,
                              itemTitle: widget.title,
                              isBidFinished: _auctionEnded,
                              winningAmount: _auctionEnded ? 'PKR ${_currentBid.toStringAsFixed(0)}' : '',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ] else
            // Auction Ended
              Column(
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
                  )
                ],
              ),
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
            width: 100,
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

  void _navigateToLiveBidding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveBidscreen(
          itemId: widget.itemData?['id'] ?? '',
          itemType: widget.isArt ? 'art' : 'furniture',
          itemTitle: widget.title,
          imageUrl: widget.imageUrl, // Pass the original image URL
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
      print('Error placing bid: ${e.toString()}');
    } finally {
      setState(() => _isPlacingBid = false);
    }
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }
}