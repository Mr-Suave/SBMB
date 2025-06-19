import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'band_setup_screen.dart';
import 'dart:async';
import 'dart:ui';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- ADD THIS IMPORT
import 'package:firebase_core/firebase_core.dart'; // <--- ADD THIS IMPORT
import 'dart:math' as math; // <--- ADD THIS IMPORT FOR MATH FUNCTIONS

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String parentName = '';
  String babyName = '';
  bool isBandConnected = false;
  String apiUrl = '';
  Timer? _timer;

  double temperature = 0;
  double movement = 0;
  double noise = 0;
  double lat = 0;
  double lng = 0;
  double prevMovement = 0;
  double prevNoise = 0;

  // --- NEW STATE VARIABLES FOR LOCATION ---
  LatLng? _homeLocation; // To store the user's geocoded home location
  String _distanceFromHome = 'N/A'; // To display the distance
  String? _fcmToken; // To store the device's FCM token



  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadUserData();
    _loadHomeLocationFromPrefs();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'vital_channel', 'Vital Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }
  Future<void> _loadHomeLocationFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? homeLat = prefs.getDouble('home_lat');
    double? homeLng = prefs.getDouble('home_lng');
    if (homeLat != null && homeLng != null) {
      setState(() {
        _homeLocation = LatLng(homeLat, homeLng);
      });
      _updateDistance(); // Update distance if home location is loaded
    }
  }
  Future<void> _saveHomeLocationToPrefs(LatLng location) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_lat', location.latitude);
    await prefs.setDouble('home_lng', location.longitude);
    print('Home location saved to SharedPreferences.');
  }
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String fetchedApiUrl = prefs.getString('apiUrl') ?? '';
    String fetchedParentName = prefs.getString('parentName') ?? 'Parent';
    String fetchedBabyName = prefs.getString('babyName') ?? 'Baby';
    bool fetchedBandConnected = prefs.getBool('bandConnected') ?? false;

    setState(() {
      parentName = fetchedParentName;
      babyName = fetchedBabyName;
      isBandConnected = fetchedBandConnected;
      apiUrl = fetchedApiUrl;
    });

    if (fetchedBandConnected && fetchedApiUrl.isNotEmpty) {
      await _fetchData(fetchedApiUrl); // pass as param
      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: 2), (_) => _fetchData(fetchedApiUrl));
    }
  }


  Future<void> _fetchData(String baseUrl) async {
    try {
      final fullUrl = '$baseUrl/baby-data';
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double newTemp = data['temperature'];
        double newMove = data['movement'];
        double newNoise = data['noise'];
        double newLat = data['location']['lat'];
        double newLng = data['location']['lng'];

        setState(() {
          temperature = newTemp;
          movement = newMove;
          noise = newNoise;
          lat = newLat;
          lng = newLng;
          prevMovement = newMove;
          prevNoise = newNoise;
        });
        _updateDistance();
      }
    } catch (e) {
      print('Failed to load data: $e');
    }
  }


  void _navigateToBandSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BandSetupScreen()),
    );
    _loadUserData();
  }

  void _showVitalPopup(String label, String value, double rawValue) {
    String message = '';
    switch (label) {
      case 'Temperature':
        if (rawValue < 36.0) {
          message = '⚠️ Baby temperature is low. Low temperatures can be sign of loss of energy and inactivity. Check on them once!';
        } else if (rawValue > 37.5)
          message = '🚨 High temperature. Possible fever! Check on them!';
        else
          message = '😁 Nothing to worry! Normal body temperature! Your baby is safe and sound!';
        break;
      case 'Movement Tracker':
        if (rawValue < 0.2) {
          message = '😴 Baby is still or sleeping.';
        } else if (rawValue > 2.0)
          message = '🤸‍♂️ Baby is very active! Or moving very fast! Something might be wrong, check on your baby once!';
        else
          message = '🙂 Slight movement detected. Normal behaviour! ';
        break;
      case 'Sound Levels':
        if (rawValue < 30) {
          message = '🔇 Quiet environment. There is a lot of silence! Baby might be sleeping! ';
        } else if (rawValue > 70)
          message = '🔊 High noise! Baby might be crying/shouting!. Check on them once!';
        else
          message = '🧘 Calm sound levels. All good! ';
        break;
      case 'Location':
      // Special handling for location - show map instead of regular dialog
        _showLocationMap();
        return;
      default:
        message = 'ℹ️ No data available.';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.1)),
            ),
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(label, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(value, style: TextStyle(fontSize: 18, color: Colors.deepPurple)),
                  ),
                  SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  if (label == 'Movement Tracker') ...[
                    SizedBox(height: 12),
                    Text(
                      'ℹ️ Movement is measured in "g", a unit of acceleration due to gravity. '
                          'Higher values may indicate jerky movements or potential distress.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                )
              ],
            ),
          ],
        );
      },
    );
  }

  void _showLocationMap() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.1)),
            ),
            Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                height: 550,
                width: double.maxFinite,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade200,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            "$babyName's Location",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.home, color: Colors.deepPurple),
                            onPressed: () {
                              Navigator.pop(context); // Close map dialog first
                              _showAddressInputDialog(); // Show address input dialog
                            },
                            tooltip: 'Set Home Address',
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: 15.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.sbmb.project.v3',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng (lat, lng),
                                  width: 60,
                                  height: 60,
                                  child: Container(
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                if(_homeLocation != null)
                                  Marker(
                                    point: _homeLocation!,
                                    width: 60,
                                    height: 60,
                                    child: Container(
                                      child: Icon(
                                        Icons.home,
                                        color: Colors.blue,
                                        size: 40,
                                      ),
                                  ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '📍 Current Coordinates',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Distance from Home: $_distanceFromHome',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDistance() async {
    if (_homeLocation != null && lat != 0 && lng != 0) {
      final distance = _calculateHaversineDistance(lat, lng, _homeLocation!.latitude, _homeLocation!.longitude);
      setState(() {
        _distanceFromHome = '${distance.toStringAsFixed(2)} meters';
      });
    } else {
      setState(() {
        _distanceFromHome = 'N/A (home location not set)';
      });
    }
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Radius of Earth in meters
    final phi1 = _degreesToRadians(lat1);
    final phi2 = _degreesToRadians(lat2);
    final deltaPhi = _degreesToRadians(lat2 - lat1);
    final deltaLambda = _degreesToRadians(lon2 - lon1);

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
            math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }


  // --- UI Helpers ---
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<LatLng?> _geocodeAddress(String address) async {
    final url =
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'YourAppNameHere'}, // Required by Nominatim
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        } else {
          print('No results found for address.');
          return null;
        }
      } else {
        print('Geocoding request failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }

  // --- NEW: Send Home Address to Backend for Geocoding ---
  Future<void> _sendHomeAddressToBackend(String address) async {
    final SharedPrefs = await SharedPreferences.getInstance();
    _fcmToken = SharedPrefs.getString('fcm_token');
    if (_fcmToken == null) {
      _showSnackBar('Error: FCM token not available. Cannot set home address.');
      return;
    }

    // Geocode the address first
    final LatLng? homeLocation = await _geocodeAddress(address);
    if (homeLocation == null) {
      _showSnackBar('Unable to geocode the provided address.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/set_user_home_location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': _fcmToken,
          'home_lat': homeLocation.latitude,
          'home_lng': homeLocation.longitude,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _homeLocation = homeLocation;
        });
        _saveHomeLocationToPrefs(homeLocation);
        _updateDistance();
        _showSnackBar('Home address set successfully!');
        print('Home address set successfully on backend: $homeLocation');
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar('Failed to set home address: ${errorData['message']}');
        print('Failed to set home address: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Error setting home address: $e');
      print('Error setting home address: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAddressSuggestions(String query) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'YourAppNameHere' // Required by Nominatim policy
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map<Map<String, dynamic>>((item) => item).toList();
    } else {
      print("Nominatim error: ${response.statusCode}");
      return [];
    }
  }

  // --- NEW: Dialog for Address Input ---
  Future<void> _showAddressInputDialog() async {
    String? address;

    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set Home Address',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TypeAheadField<Map<String, dynamic>>(
                    textFieldConfiguration: TextFieldConfiguration(
                      decoration: const InputDecoration(
                        labelText: 'Enter home address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    suggestionsCallback: (pattern) async {
                      if (pattern.length < 3) return [];
                      return await fetchAddressSuggestions(pattern);
                    },
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(suggestion['display_name']),
                      );
                    },
                    onSuggestionSelected: (suggestion) async {
                      final lat = double.parse(suggestion['lat']);
                      final lng = double.parse(suggestion['lon']);

                      setState(() {
                        address = suggestion['display_name'];
                        _homeLocation = LatLng(lat, lng);
                      });

                      Navigator.pop(context);
                      await _sendHomeAddressToBackend(address!);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Set'),
                        onPressed: () async {
                          Navigator.pop(context);
                          if (address != null && address!.isNotEmpty) {
                            await _sendHomeAddressToBackend(address!);
                          } else {
                            _showSnackBar('Address cannot be empty.');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade200.withOpacity(0.9),
        title: Text('Hello $parentName 👋', style: TextStyle(fontWeight: FontWeight.bold),),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _navigateToBandSetup,
          ),
        ],
      ),
      body: isBandConnected
          ? Stack(
        children: [
          Container(
            height: 360,
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade200.withOpacity(0.9),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.5,
              child: Lottie.asset(
                'assets/animations/baby_peek.json',
                height: 300, // Adjust to your liking
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$babyName's vitals",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          children: [
                            _buildVitalCard(
                              icon: Icons.thermostat,
                              label: 'Temperature',
                              value: '${temperature.toStringAsFixed(1)} °C',
                              onTap: () => _showVitalPopup('Temperature', '${temperature.toStringAsFixed(1)} °C', temperature),
                            ),
                            _buildVitalCard(
                              icon: Icons.location_on,
                              label: 'Location',
                              value: '$lat, $lng',
                              onTap: () => _showVitalPopup('Location', '$lat, $lng', 0),
                            ),
                            _buildVitalCard(
                              icon: Icons.directions_walk,
                              label: 'Movement Tracker',
                              value: '${movement.toStringAsFixed(1)} g',
                              onTap: () => _showVitalPopup('Movement Tracker', '${movement.toStringAsFixed(1)} g', movement),
                            ),
                            _buildVitalCard(
                              icon: Icons.volume_up,
                              label: 'Sound Levels',
                              value: '${noise.toStringAsFixed(1)} dB 🔊',
                              onTap: () => _showVitalPopup('Sound Levels', '${noise.toStringAsFixed(1)} dB 🔊', noise),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40),
                      Text(
                        "ℹ️ Tap on a card to know more information!",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      )
          : Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 150),
        child: Text(
          'Head over to settings on the top right to configure your smart band!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }





  Widget _buildVitalCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // controls blur intensity
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35), // frosted glass tint
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.deepPurple),
                SizedBox(height: 12),
                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
