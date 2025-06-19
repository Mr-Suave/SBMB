import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import this
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

// Top-level function to handle background messages
// MUST be a top-level function (outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupFlutterNotifications();
  if(message.notification == null) { // Ensure channel is set up even if app was terminated
    showFlutterNotification(message);
  }// Display the notification
  print('Handling a background message: ${message.messageId}');
}

// Global instances for notification handling
late AndroidNotificationChannel channel; // Declare this globally
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin; // Declare this globally

bool isFlutterLocalNotificationsInitialized = false; // Declare this globally

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }

  // --- THIS IS WHERE THE high_importance_channel IS DEFINED ---
  channel = const AndroidNotificationChannel(
    'high_importance_channel', // <<-- THIS ID MUST MATCH YOUR BACKEND'S 'channel_id'
    'High Importance Notifications', // User-visible title for the channel
    description: 'This channel is used for important notifications.', // User-visible description
    importance: Importance.max, // THIS IS KEY for heads-up (pop-up) notifications
  );
  // --- END OF CHANNEL DEFINITION ---


  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Create an Android notification channel.
  ///
  /// We use this channel in the AndroidManifest.xml to override the default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  /// For iOS, ensure foreground notifications show as alerts
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  isFlutterLocalNotificationsInitialized = true;
}

// Function to display the local notification (used for foreground messages)
void showFlutterNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;
  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode, // Unique ID for the notification
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, // Use the ID of the high importance channel
          channel.name,
          channelDescription: channel.description,
          // icon: 'launch_background', // Your app's notification icon
          importance: Importance.max, // Ensure max importance is used here too
          priority: Priority.high,
          ticker: 'ticker',
          icon: 'ic_stat_child_care',
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST
  FirebaseApp app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background message handler before runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // ✅ Debug print to confirm the correct messagingSenderId is loaded
  print("=== DEBUG FIREBASE INFO ===");
  print("Messaging Sender ID: ${app.options.messagingSenderId}");
  print("===========================");
  // Set up local notifications channel and foreground presentation options
  await setupFlutterNotifications(); // Call this to create the channel

  // --- Request Notification Permissions (keep this) ---
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true, announcement: false, badge: true, carPlay: false,
    criticalAlert: false, provisional: false, sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission for notifications');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission for notifications');
  } else {
    print('User declined or has not yet accepted permission for notifications');
  }
  // --- End Notification Permissions ---

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // @override
  // void initState() {
  //   super.initState();
  //   // Listen for messages while the app is in the foreground
  //   FirebaseMessaging.onMessage.listen(showFlutterNotification);
  //
  //   // Handle interaction when the app is opened from a terminated state
  //   FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
  //     if (message != null) {
  //       print('App opened from terminated state by tapping notification: ${message.data}');
  //     }
  //   });
  //
  //   // Handle interaction when the app is opened from a background state
  //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  //     print('App opened from background by tapping notification: ${message.data}');
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Baby Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
