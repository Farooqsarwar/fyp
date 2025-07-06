import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/views/chat_screen.dart';
import '../services/auction_services.dart';
import '../services/notification_services.dart';

class BidWinScreen extends StatefulWidget {
  final String imageUrl;
  final String itemTitle;
  final String itemId;
  final String itemType;
  final SupabaseClient supabase;
  final AuctionService auctionService;
  final NotificationService notificationService;

  const BidWinScreen({
    super.key,
    required this.imageUrl,
    required this.itemTitle,
    required this.itemId,
    required this.itemType,
    required this.supabase,
    required this.auctionService,
    required this.notificationService,
  });

  @override
  _BidWinScreenState createState() => _BidWinScreenState();
}

class _BidWinScreenState extends State<BidWinScreen> {
  Map<String, dynamic>? _winner;
  List<Map<String, dynamic>> _bids = [];
  bool _isLoading = true;
  bool _isBidFinished = false;
  bool _isCheckingWinner = false;
  bool _hasCheckedForWinner = false;
  String? _uploaderId;
  String? _uploaderName;
  String? _uploaderAvatar;
  StreamSubscription<Map<String, dynamic>?>? _winnerSub;

  @override
  void initState() {
    super.initState();
    _fetchUploaderDetails().then((_) {
      _fetchData();
      _setupWinnerListener();
    });
  }

  Future<void> _fetchUploaderDetails() async {
    try {
      // Get the item details including the owner's user_id
      final itemResponse = await widget.supabase
          .from(widget.itemType)  // 'art', 'cars', or 'furniture'
          .select('user_id, users!user_id(*)')
          .eq('id', widget.itemId)
          .single();

      // Extract user information
      final userData = itemResponse['users'] ?? {};
      final rawData = userData['raw_user_meta_data'] as Map<String, dynamic>? ?? {};

      setState(() {
        _uploaderId = itemResponse['user_id']?.toString();
        _uploaderName = rawData['name'] ??
            userData['email']?.toString().split('@').first ??
            'Item Owner';
        _uploaderAvatar = rawData['avatar_url'];
      });

      debugPrint('Uploader details loaded: $_uploaderId, $_uploaderName');
    } catch (e) {
      debugPrint('Error fetching uploader details: $e');
      _showErrorSnackbar('Could not load item owner information');
    }
  }
  Future<void> _fetchData() async {
    try {
      final auctionResponse = await widget.supabase
          .from(widget.itemType)
          .select()
          .eq('id', widget.itemId)
          .single();

      setState(() {
        _isBidFinished = auctionResponse['is_active'] == false ||
            (DateTime.tryParse(auctionResponse['end_time'] ?? '')
                    ?.isBefore(DateTime.now()) ??
                false);
      });

      if (_isBidFinished) {
        await _checkForWinner();
        if (_winner == null) {
          await _fetchBids();
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error fetching data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupWinnerListener() {
    _winnerSub = widget.auctionService
        .getWinnerStream(
      itemId: widget.itemId,
      itemType: widget.itemType,
    )
        .listen((winner) {
      if (mounted && winner != null && winner != _winner) {
        setState(() {
          _winner = winner;
          _hasCheckedForWinner = true;
        });
      }
    });
  }

  Future<void> _checkForWinner() async {
    if (_isCheckingWinner || _hasCheckedForWinner) return;

    setState(() {
      _isCheckingWinner = true;
      _hasCheckedForWinner = true;
    });

    try {
      final winner = await widget.auctionService.checkAndDeclareWinner(
        itemId: widget.itemId,
        itemType: widget.itemType,
        notificationService: widget.notificationService,
      );

      if (mounted && winner != null) {
        setState(() => _winner = winner);
      }
    } catch (e) {
      debugPrint('Error checking for winner: $e');
      if (mounted) {
        setState(() => _hasCheckedForWinner = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingWinner = false);
      }
    }
  }

  Future<void> _fetchBids() async {
    try {
      final bidsResponse = await widget.supabase
          .from('bids')
          .select('id, user_id, amount, created_at, users!user_id(*)')
          .eq('item_id', widget.itemId)
          .eq('item_type', widget.itemType)
          .order('amount', ascending: false)
          .limit(10);

      final List<Map<String, dynamic>> bids =
          List<Map<String, dynamic>>.from(bidsResponse);
      final updatedBids = bids.map((bid) {
        final userData = bid['users'] ?? {};
        final rawData =
            userData['raw_user_meta_data'] as Map<String, dynamic>? ?? {};
        return {
          ...bid,
          'user_name': rawData['name'] ??
              userData['email']?.split('@').first ??
              'Anonymous',
          'avatar_url': rawData['avatar_url'],
        };
      }).toList();

      setState(() => _bids = updatedBids);
    } catch (e) {
      _showErrorSnackbar('Error fetching bids: ${e.toString()}');
    }
  }

  Future<void> _contactUploader() async {
    if (_uploaderId == null || _uploaderId!.isEmpty) {
      _showErrorSnackbar('Item owner information not available');
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Navigate to chat screen with uploader details
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              receiverId: _uploaderId!,
              receiverName: _uploaderName ?? 'Item Owner',
              itemId: widget.itemId,
              itemType: widget.itemType,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackbar('Error contacting item owner: ${e.toString()}');
      debugPrint('Error in contactUploader: $e');
    }
  }
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final winnerName = _winner?['user']?['name'] ??
        _winner?['user']?['email']?.split('@').first ??
        (_bids.isNotEmpty ? _bids.first['user_name'] : 'Anonymous');
    final winningAmount = _winner?['winning_amount']?.toString() ??
        (_bids.isNotEmpty ? 'PKR ${_bids.first['amount'].toString()}' : '');
    final winnerAvatar = _winner?['user']?['avatar_url'] ??
        (_bids.isNotEmpty ? _bids.first['avatar_url'] : null);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 27, 27, 27).withOpacity(0.7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.yellow),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Auction Results',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Item Image Section
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.imageUrl,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: 250,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color.fromRGBO(0, 0, 0, 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isBidFinished && winningAmount.isNotEmpty) ...[
                      Positioned(
                        bottom: -30,
                        left: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.yellow,
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: winnerAvatar != null
                                ? NetworkImage(winnerAvatar)
                                : null,
                            child: winnerAvatar == null
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(
                    height:
                        _isBidFinished && winningAmount.isNotEmpty ? 50 : 20),

                // Results Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isBidFinished && winningAmount.isNotEmpty
                          ? Colors.yellow
                          : Colors.grey[700]!,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_isLoading || _isCheckingWinner) ...[
                        const CircularProgressIndicator(color: Colors.yellow),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading auction results...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ] else if (_isBidFinished) ...[
                        if (winningAmount.isNotEmpty) ...[
                          // Winner Section
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.yellow,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "🎉 Congratulations! 🎉",
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            winnerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "Winner of",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.itemTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(color: Colors.yellow),
                                  ),
                                  child: Text(
                                    "Winning Bid: $winningAmount",
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Contact Uploader Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.chat),
                            label: const Text(
                              "Contact Item Owner",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: _contactUploader,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.share),
                            label: const Text(
                              "Share Result",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Share feature coming soon!'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          // No bids scenario
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[400],
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No Winning Bids",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No bids were placed for",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.itemTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Text(
                              "This auction ended without any bids. The item may be relisted in future auctions.",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ]
                      ] else ...[
                        // Ongoing Bid Section
                        const Icon(
                          Icons.access_time,
                          color: Colors.yellow,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Auction in Progress",
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "The bidding for ${widget.itemTitle} is still ongoing!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: const Text(
                            "Please check back later for the final results. You will be notified when the auction ends.",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Back Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Back to Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _winnerSub?.cancel();
    super.dispose();
  }
}
