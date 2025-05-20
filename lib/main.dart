import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fyp/view/Live_Biding.dart';
import 'package:fyp/view/bidwinscreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'firebase_options.dart';
import 'package:fyp/view/splashscreen.dart';
import 'package:fyp/services/notification_services.dart';

// Create a global navigator key for notification handling
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: "https://ejqogqnyskhakdlziesp.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqcW9ncW55c2toYWtkbHppZXNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcwMzQ3OTIsImV4cCI6MjA2MjYxMDc5Mn0.BzQpXwZuVBouTQB3bGZVg77SbKhtkrbeowN8ksiDn0k",
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("54dc40d7-17f6-48cb-8cf7-d7398b65e95f");
  await OneSignal.Notifications.requestPermission(true);

  // Set up notification click handler
  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData;
    if (data == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final notificationType = data['notification_type'];
    final itemId = data['item_id'];
    final itemType = data['item_type'];

    if (notificationType == 'new_bid') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveBidscreen(
            itemId: itemId,
            itemType: itemType,
            itemTitle: 'Live Bidding',
            imageUrl: '', // You'll need to fetch this
          ),
        ),
      );
    } else if (notificationType == 'auction_win') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BidWinScreen(
            imageUrl: '', // Fetch this
            itemTitle: 'Auction Won',
            winningAmount: 'PKR ${data['amount']}',
            isBidFinished: true,
          ),
        ),
      );
    }
  });

  // Initialize notification service for current user
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    await OneSignal.login(user.id);
    final notificationService = NotificationService(supabase: Supabase.instance.client);
    await notificationService.initialize(user.id);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add the navigator key
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}