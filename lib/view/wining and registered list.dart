import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auction_services.dart';

class WonAuctionsList extends StatefulWidget {
  final AuctionService auctionService;
  final bool showAppBar;

  const WonAuctionsList({
    super.key,
    required this.auctionService,
    this.showAppBar = true,
  });

  @override
  State<WonAuctionsList> createState() => _WonAuctionsListState();
}

class _WonAuctionsListState extends State<WonAuctionsList> {
  List<Map<String, dynamic>> _wonAuctions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWonAuctions();
  }

  Future<void> _loadWonAuctions() async {
    try {
      setState(() => _isLoading = true);
      final wonAuctions = await widget.auctionService.getAuctionsWonByUser();
      setState(() {
        _wonAuctions = wonAuctions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load won auctions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
        title: const Text("Won Auctions", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadWonAuctions,
        child: _wonAuctions.isEmpty
            ? Center(
          child: Text(
            'No auctions won yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _wonAuctions.length,
          itemBuilder: (context, index) {
            final auction = _wonAuctions[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              color: const Color(0xFF1C1C1C),
              child: ListTile(
                leading: auction['item_image'] != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    auction['item_image'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white),
                  ),
                )
                    : const Icon(Icons.image, color: Colors.white),
                title: Text(
                  auction['item_name'] ?? 'Unnamed Item',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (auction['winning_amount'] != null)
                      Text(
                        'Won for: \$${auction['winning_amount']?.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    Text(
                      'Type: ${auction['item_type'] ?? "Unknown"}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class RegisteredAuctionsList extends StatefulWidget {
  final AuctionService auctionService;
  final bool showAppBar;

  const RegisteredAuctionsList({
    super.key,
    required this.auctionService,
    this.showAppBar = true,
  });

  @override
  State<RegisteredAuctionsList> createState() => _RegisteredAuctionsListState();
}

class _RegisteredAuctionsListState extends State<RegisteredAuctionsList> {
  List<Map<String, dynamic>> _registeredAuctions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegisteredAuctions();
  }

  Future<void> _loadRegisteredAuctions() async {
    try {
      setState(() => _isLoading = true);
      final registeredAuctions = await widget.auctionService.getAuctionsRegisteredByUser();
      setState(() {
        _registeredAuctions = registeredAuctions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load registered auctions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
        title: const Text("Registered Auctions", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadRegisteredAuctions,
        child: _registeredAuctions.isEmpty
            ? Center(
          child: Text(
            'No registered auctions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _registeredAuctions.length,
          itemBuilder: (context, index) {
            final auction = _registeredAuctions[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1C1C1C),
              child: ListTile(
                tileColor: const Color(0xFF1C1C1C),
                leading: auction['item_image'] != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    auction['item_image'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
                )
                    : const Icon(Icons.image, size: 40, color: Colors.grey),
                title: Text(
                  auction['item_name'] ?? 'Unnamed Item',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Type: ${auction['item_type'] ?? "Unknown"}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
