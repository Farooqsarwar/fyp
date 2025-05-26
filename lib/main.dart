import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'services/notification_services.dart';
import 'services/auction_services.dart'; // Import AuctionService
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

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize("54dc40d7-17f6-48cb-8cf7-d7398b65e95f");
    await OneSignal.Notifications.requestPermission(true);

    final notificationService = NotificationService(supabase: supabase);
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
    }
    debugPrint("✅ OneSignal initialized");

    // Notification click handler
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint('Notification clicked: $data');
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('❌ Navigator context is null');
        return;
      }

      // Check if data is not null
      if (data != null) {
        if (data['type'] == 'auction_won') {
          Navigator.pushNamed(context, '/bidWin', arguments: {
            'itemTitle': data['item_title'] as String? ?? 'Auction Won',
            'imageUrl': data['image_url'] as String? ?? '',
            'itemId': data['item_id'] as String? ?? '',
            'itemType': data['item_type'] as String? ?? '',
          });
        } else if (data['type'] == 'new_bid') {
          Navigator.pushNamed(context, '/liveBidding', arguments: {
            'itemId': data['item_id'] as String? ?? '',
            'itemType': data['item_type'] as String? ?? '',
            'title': data['item_title'] as String? ?? 'Live Bidding',
            'imageUrl': data['image_url'] as String? ?? '',
          });
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
    return MaterialApp(
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