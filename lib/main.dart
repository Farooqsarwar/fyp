import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'chat/controller/chat_controller.dart';
import 'chat/controller/user_controller.dart';
import 'services/notification_services.dart';
import 'services/auction_services.dart';
import 'view/splashscreen.dart';
import 'view/Homescreen.dart';
import 'view/Cars_Bid_detial_and placing.dart';
import 'view/Art_Furniture_detials_screen.dart';
import 'view/Live_Biding.dart';
import 'view/bidwinscreen.dart';
import 'view/Uploading_Bid.dart';
import 'view/All_cars_screen.dart';
import 'view/all_art_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final supabase = Supabase.instance.client;

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: "https://ejqogqnyskhakdlziesp.supabase.co",
      anonKey:
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqcW9ncW55c2toYWtkbHppZXNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcwMzQ3OTIsImV4cCI6MjA2MjYxMDc5Mn0.BzQpXwZuVBouTQB3bGZVg77SbKhtkrbeowN8ksiDn0k",
    );
    debugPrint("✅ Supabase initialized");
    Get.put(ChatController(), permanent: true);
    Get.put(UserController(), permanent: true);

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("54dc40d7-17f6-48cb-8cf7-d7398b65e95f");
    await OneSignal.Notifications.requestPermission(true);
    debugPrint("✅ OneSignal initialized");

    final notificationService = NotificationService();
    notificationService.initializeWithSupabase(supabase);
    final auctionService = AuctionService(supabase: supabase);
    auctionService.initialize();

    // Handle auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (userId != null) {
        notificationService.initialize(userId);
        debugPrint('Initialized notifications for user $userId');
      }
    });

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await notificationService.initialize(userId);
      debugPrint("✅ NotificationService initialized for user $userId");
    }

    // Start monitoring auctions
    await auctionService.monitorAllAuctions(notificationService);
    startAuctionMonitoring(notificationService, auctionService);

    // Notification click handler
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint('Notification clicked: $data');
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('❌ Navigator context is null');
        return;
      }

      if (data != null) {
        if (data['type'] == 'auction_won') {
          Navigator.pushNamed(context, '/bidWin', arguments: {
            'itemTitle': data['item_title'] as String? ?? 'Auction Won',
            'imageUrl': data['image_url'] as String? ?? '',
            'itemId': data['item_id'] as String? ?? '',
            'itemType': data['item_type'] as String? ?? '',
          });
          debugPrint('Navigated to /bidWin for itemId: ${data['item_id']}');
        } else if (data['type'] == 'new_bid') {
          Navigator.pushNamed(context, '/liveBidding', arguments: {
            'itemId': data['item_id'] as String? ?? '',
            'itemType': data['item_type'] as String? ?? '',
            'title': data['item_title'] as String? ?? 'Live Bidding',
            'imageUrl': data['image_url'] as String? ?? '',
          });
          debugPrint('Navigated to /liveBidding for itemId: ${data['item_id']}');
        } else if (data['type'] == 'auction_start' || data['type'] == 'auction_end') {
          Navigator.pushNamed(context, '/artFurnitureDetails', arguments: {
            'itemId': data['item_id'] as String? ?? '',
            'itemType': data['item_type'] as String? ?? '',
            'title': data['item_title'] as String? ?? 'Auction Details',
            'imageUrl': data['image_url'] as String? ?? '',
            'isArt': data['item_type'] == 'art',
            'itemData': {
              'id': data['item_id'],
              'bid_name': data['item_title'],
            },
          });
          debugPrint('Navigated to /artFurnitureDetails for itemId: ${data['item_id']}');
        }
      } else {
        debugPrint('❌ Notification data is null');
      }
    });

    runApp(MyApp(
      auctionService: auctionService,
      notificationService: notificationService,
    ));
  } catch (e, stack) {
    debugPrint("❌ Initialization failed: $e\n$stack");
  }
}

void startAuctionMonitoring(NotificationService notificationService, AuctionService auctionService) {
  Timer.periodic(Duration(minutes: 1), (timer) async {
    if (kDebugMode) {
      debugPrint('Checking auction statuses at ${DateTime.now().toIso8601String()}');
    }
    try {
      await auctionService.monitorAllAuctions(notificationService);
      debugPrint('Successfully monitored all auctions');
    } catch (e) {
      debugPrint('Error monitoring auctions: $e');
    }
  });
}
class MyApp extends StatelessWidget {
  final AuctionService auctionService;
  final NotificationService notificationService;
  const MyApp({
    super.key,
    required this.auctionService,
    required this.notificationService,
  });
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const Homescreen(),
        '/carDetails': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CarBidDetailsScreen(
            imageUrl: args?['imageUrl'] ?? '',
            title: args?['title'] ?? '',
            itemData: args?['itemData'] ?? {},
          );
        },
        '/artFurnitureDetails': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ArtFurnitureDetailsScreen(
            imageUrl: args?['imageUrl'] ?? '',
            title: args?['title'] ?? '',
            isArt: args?['isArt'] ?? true,
            itemData: args?['itemData'] ?? {},
          );
        },
        '/liveBidding': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LiveBidscreen(
            itemId: args?['itemId'] ?? '',
            itemType: args?['itemType'] ?? '',
            itemTitle: args?['title'] ?? 'Live Bidding',
            imageUrl: args?['imageUrl'] ?? '',
          );
        },
        '/uploadBid': (context) => const UploadingBidScreen(),
        '/allCars': (context) => const AllCarsScreen(),
        '/allArt': (context) => const AllArtScreen(),
        '/bidWin': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return BidWinScreen(
            itemTitle: args?['itemTitle'] ?? 'Auction Won',
            imageUrl: args?['imageUrl'] ?? '',
            itemId: args?['itemId'] ?? '',
            itemType: args?['itemType'] ?? '',
            supabase: supabase,
            auctionService: auctionService,
            notificationService: notificationService,
          );
        },
      },
    );
  }
}