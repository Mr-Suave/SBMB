import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Make sure to import your SplashScreen
import 'splash_screen.dart'; // Adjust this path if SplashScreen is in a different directory
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert'; // for json decoding

class BandSetupScreen extends StatefulWidget {
  const BandSetupScreen({super.key});

  @override
  _BandSetupScreenState createState() => _BandSetupScreenState();
}

class _BandSetupScreenState extends State<BandSetupScreen> {
  final TextEditingController _apiController = TextEditingController();
  bool _isLoading = false;
  String? _currentApiUrl;

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startBandStatusChecker();
    _loadCurrentApiUrl();
  }

  Timer? _bandCheckTimer;

  void _startBandStatusChecker() {
    _bandCheckTimer = Timer.periodic(Duration(minutes: 10), (_) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('apiUrl');

      if (url == null || url.isEmpty) {
        // _sendSmartbandDisconnectedNotification();
        return;
      }

      try {
        final response = await http.get(Uri.parse('$url/baby-data'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data == null || data.isEmpty) {
            _sendSmartbandDisconnectedNotification();
          } else {
            print("Smartband data: $data");
          }
        } else {
          _sendSmartbandDisconnectedNotification();
        }
      } catch (e) {
        print("Error checking smartband status: $e");
        _sendSmartbandDisconnectedNotification();
      }
    });
  }
  Future<void> _sendSmartbandDisconnectedNotification() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('apiUrl');

    if (url == null) return;

    try {
      await http.post(Uri.parse('$url/send-disconnect-alert'));
      print("Alert sent to backend");
    } catch (e) {
      print("Failed to send disconnect alert: $e");
    }
  }

  Future<void> _loadCurrentApiUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentApiUrl = prefs.getString('apiUrl');
      // Pre-fill the controller if an API URL already exists
      if (_currentApiUrl != null && _currentApiUrl!.isNotEmpty) {
        _apiController.text = _currentApiUrl!;
      }
    });
  }

  // IMPORTANT: Update _resetToDefaults to go to SplashScreen
  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiUrl');
    await prefs.remove('bandConnected');
    await prefs.remove('parentName');
    await prefs.remove('babyName');
    await prefs.remove('last_fcm_token_sent');
    await prefs.remove('home_lat');
    await prefs.remove('home_lng');

    if (mounted) {
      // Navigate to SplashScreen and remove all other routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SplashScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _confirmResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('This action will reset everything and cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Reset'),
            onPressed: () {
              Navigator.of(context).pop();
              _resetToDefaults(); // call your actual reset function
            },
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDemo() async {
    if (_apiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API URL')),
      );
      _loadCurrentApiUrl(); // Reload current API URL (though it will be empty)
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('apiUrl', _apiController.text.trim());
      await prefs.setBool('bandConnected', true); // Assuming connecting to demo means connected

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected successfully!')),
        );
        // --- CRUCIAL CHANGE HERE ---
        // Instead of pop, navigate to SplashScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
              (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showApiDialog() {
    // If an API URL is already set, pre-fill the text field
    if (_currentApiUrl != null && _currentApiUrl!.isNotEmpty) {
      _apiController.text = _currentApiUrl!;
    } else {
      _apiController.clear(); // Clear it if no URL set
    }


    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('🔌 Connect to Demo Server'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _apiController,
                decoration: const InputDecoration(
                  hintText: 'Enter API URL',
                  labelText: 'API URL',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.of(context).pop(); // Close the dialog first
                _connectToDemo(); // Then connect
              },
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(image: AssetImage('assets/backgrounds/setup_page_bg.png'),
        fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white38,
        appBar: AppBar(
          backgroundColor: Colors.white38,
          title: const Text(
            'Set Up Band',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Set Up Band',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins-Bold',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Set up your smart band for seamless monitoring of your special one!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Physical band setup coming soon!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text(
                          'Set Up Physical Band',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _showApiDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: Colors.white60,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text(
                          'Demo Server Connect',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_currentApiUrl != null && _currentApiUrl!.isNotEmpty)
                        Text(
                          '✅ Connected to API: $_currentApiUrl',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          '⚠️ Not connected to any API',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.red[700]),
                        ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: Colors.white60,
                        ),
                        onPressed: _confirmResetDialog,
                        icon: const Icon(Icons.restore, color: Colors.red),
                        label: const Text(
                          'Reset to Defaults',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}