import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging

// Import your other screens
import 'setup_screen.dart';
import 'activity_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAppAndNavigate(); // Call the async function directly
  }

  Future<void> _initializeAppAndNavigate() async {
    // Optional: Add a small delay for splash screen visibility
    await Future.delayed(const Duration(seconds: 3));

    // --- Retrieve SharedPreferences data ---
    final prefs = await SharedPreferences.getInstance();
    final String? apiUrl = prefs.getString('apiUrl');
    final bool? bandConnected = prefs.getBool('bandConnected');
    final String? parentName = prefs.getString('parentName');
    final String? babyName = prefs.getString('babyName');

    // --- Debugging print statements ---
    if (kDebugMode) {
      print('Splash Screen:');
      print('  API URL: $apiUrl');
      print('  Band Connected: $bandConnected');
      print('  Parent Name: $parentName');
      print('  Baby Name: $babyName');
    }

    // --- FCM Token Sending Logic (Firebase is already initialized in main.dart) ---
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        print("FCM Token on startup/reset: $fcmToken");
      }
      try {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if(fcmToken != null) {
          prefs.setString("fcm_token", fcmToken);
        }
        // Get Sender ID
        String senderId = Firebase.app().options.messagingSenderId;

        if (kDebugMode) {
          print("=== FCM DEBUG INFO ===");
          print("FCM Token: $fcmToken");
          print("Sender ID: $senderId");
          print("Expected Sender ID from google-services.json: 977693311394");
          print("Sender IDs match: ${senderId == '977693311394'}");
          print("=====================");
        }

        // Continue with your existing FCM token sending logic...
        if (apiUrl != null && apiUrl.isNotEmpty) {
          await _sendFcmTokenToBackend(apiUrl, fcmToken, prefs);
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error getting FCM token or Sender ID: $e");
        }
      }

      // TODO: Implement the logic to send the FCM token to your Render backend
      // This part is critical. You'll likely need an HTTP client (like 'http' or 'dio').
      // Only attempt to send if apiUrl is valid and token is available.
      if (apiUrl != null && apiUrl.isNotEmpty) {
        // Example: Call a function to send the token
        await _sendFcmTokenToBackend(apiUrl, fcmToken, prefs); // Pass nullable fcmToken
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting or sending FCM token: $e");
      }
      // Consider showing a user-friendly error or logging it internally
    }
    // --- End FCM Token Sending Logic ---

    // --- Determine Next Screen Logic ---
    final bool isApiUrlSet = apiUrl != null && apiUrl.isNotEmpty;
    final bool isBandConnectedCorrectly = bandConnected == true;
    final bool hasNamesSetup = (parentName != null && parentName.isNotEmpty) &&
        (babyName != null && babyName.isNotEmpty);

    if (!isApiUrlSet || !isBandConnectedCorrectly || !hasNamesSetup) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SetupScreen(),
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ActivityScreen(),
          ),
        );
      }
    }
  }

  // --- Helper function to send FCM token to backend ---
  // Change the fcmToken parameter type from 'String' to 'String?'
  Future<void> _sendFcmTokenToBackend(String apiUrl, String? fcmToken, SharedPreferences prefs) async { // CHANGED HERE
    // IMPORTANT: Handle the case where fcmToken might be null
    if (fcmToken == null) {
      if (kDebugMode) {
        print('FCM Token is null, cannot send to backend.');
      }
      return; // Exit the function if there's no token
    }

    // Determine your specific API endpoint for sending FCM tokens
    final String fcmEndpoint = '$apiUrl/register_token'; // Adjust this endpoint

    // You might want to save the last sent token to avoid re-sending unnecessarily
    final String? lastSentToken = prefs.getString('last_fcm_token_sent');

    if (fcmToken == lastSentToken) {
      if (kDebugMode) {
        print('FCM token already sent to backend. Skipping.');
      }
      return; // Token hasn't changed, no need to resend
    }

    try {
      final response = await http.post(
        Uri.parse(fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          // You might need an Authorization header if your API is secured
          // 'Authorization': 'Bearer YOUR_AUTH_TOKEN',
        },
        body: jsonEncode({ // Make sure to import 'dart:convert' for jsonEncode
          'token': fcmToken,
          // Add any other user identifiers your backend needs (e.g., parentId, userId)
          // 'userId': prefs.getString('userId'), // Example
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          print('FCM Token successfully sent to backend.');
        }
        await prefs.setString('last_fcm_token_sent', fcmToken); // Save to prevent re-sending
      } else {
        if (kDebugMode) {
          print('Failed to send FCM Token. Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending FCM Token to backend: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Smart Baby Monitor',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Parenting Redefined!',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}