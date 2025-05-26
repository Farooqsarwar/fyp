// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
//
// import 'auction_services.dart';
// import 'notification_services.dart';
//
// abstract class BaseAuctionScreen<T extends StatefulWidget> extends State<T> {
//   final AuctionService _auctionService = AuctionService(
//     supabase: Supabase.instance.client,
//   );
//   final NotificationService _notificationService = NotificationService(
//     supabase: Supabase.instance.client,
//   );
//   final TextEditingController _bidController = TextEditingController();
//   double _currentBid = 0;
//   bool _isPlacingBid = false;
//   bool _auctionEnded = false;
//   String? _highestBidderId;
//   late String itemType; // To be set by concrete classes
//
//   @override
//   void initState() {
//     super.initState();
//     _currentBid = double.tryParse(widget.itemData?['price']?.toString() ?? '0') ?? 0;
//     _setupRealTimeUpdates();
//   }
//
//   void _setupRealTimeUpdates() {
//     _auctionService.getBidsForAuction(widget.itemData?['id'], itemType).listen((bids) {
//       if (bids.isNotEmpty) {
//         setState(() {
//           _currentBid = (bids.first['amount'] as num).toDouble();
//           _highestBidderId = bids.first['user_id'] as String?;
//         });
//       }
//     });
//
//     _auctionService.getAuctionById(widget.itemData?['id'], itemType).listen((auction) {
//       if (auction != null && auction['is_active'] == false) {
//         setState(() => _auctionEnded = true);
//       }
//     });
//   }
//
//   Future<void> _placeBid() async {
//     final bidAmount = double.tryParse(_bidController.text);
//     if (bidAmount == null || bidAmount <= _currentBid) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Bid must be higher than ${_currentBid.toStringAsFixed(0)} PKR'),
//           backgroundColor: Colors.red,red
//         ),
//       );
//       return;
//     }
//
//     setState(() => _isPlacingBid = true);
//     try {
//       await _auctionService.placeBid(
//         itemId: widget.itemData?['id'],
//         itemType: itemType,
//         amount: bidAmount,
//       );
//       _bidController.clear();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Bid placed successfully!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error placing bid: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => _isPlacingBid = false);
//     }
//   }
//
//   @override
//   void dispose() {
//     _bidController.dispose();
//     super.dispose();
//   }
// }