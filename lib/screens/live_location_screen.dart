import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:newdemoapp/screens/user_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/mongo_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_telephony/telephony.dart';
import 'dart:io';

enum UserType { User, Hospital, Police }

class LiveLocationScreen extends StatefulWidget {
  final UserType userType;
  final String email;

  const LiveLocationScreen({
    super.key,
    required this.userType,
    required this.email,
  });

  @override
  _LiveLocationScreenState createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  double userLatitude = 0.0;
  double userLongitude = 0.0;
  double ambulanceLatitude = 0.0;
  double ambulanceLongitude = 0.0;
  bool isLoading = true;
  late Timer _locationTimer;
  bool _showEmergencyOptions = false;
  double _alertDistance = 2.0;
  bool _alertShown = false;
  double _currentDistance = 0.0;
  bool _isDialogOpen = false;

  // Cache previous values
  double _prevUserLat = 0.0;
  double _prevUserLon = 0.0;
  double _prevAmbulanceLat = 0.0;
  double _prevAmbulanceLon = 0.0;

  final String userLocationApi =
      "https://api.thingspeak.com/channels/2888813/feeds.json?api_key=7G7F91FQ2ABCPZ5R&results=1";
  final String ambulanceLocationApi =
      "https://api.thingspeak.com/channels/2898037/feeds.json?api_key=O6SNZ5M0FUL98V84&results=2";

  Map<String, dynamic>? _profileData;
  bool _isProfileLoading = true;

  final telephony = Telephony.instance;

  // Optimized distance calculation
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == _prevUserLat &&
        lon1 == _prevUserLon &&
        lat2 == _prevAmbulanceLat &&
        lon2 == _prevAmbulanceLon) {
      return _currentDistance;
    }

    _prevUserLat = lat1;
    _prevUserLon = lon1;
    _prevAmbulanceLat = lat2;
    _prevAmbulanceLon = lon2;

    // Convert to radians
    final lat1Rad = lat1 * (pi / 180);
    final lon1Rad = lon1 * (pi / 180);
    final lat2Rad = lat2 * (pi / 180);
    final lon2Rad = lon2 * (pi / 180);

    // Haversine formula
    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return 6371000 * c; // Earth radius in meters
  }

  void _showApproachAlert(double distance) {
    if (!_alertShown && !_isDialogOpen) {
      _isDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
          title: const Text('EMERGENCY VEHICLE APPROACHING!'),
          content: Text(
            'Ambulance is within ${distance.toStringAsFixed(1)} meters!\n'
                'Please move aside immediately.',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
                setState(() => _alertShown = true);
              },
              child: const Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ).then((_) => _isDialogOpen = false);
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(userLocationApi)),
        http.get(Uri.parse(ambulanceLocationApi)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final userData = jsonDecode(responses[0].body);
        final ambulanceData = jsonDecode(responses[1].body);

        final newUserLat = double.parse(userData['feeds'][0]['field1']);
        final newUserLon = double.parse(userData['feeds'][0]['field2']);
        final newAmbulanceLat = double.parse(
          ambulanceData['feeds'][0]['field1'],
        );
        final newAmbulanceLon = double.parse(
          ambulanceData['feeds'][0]['field2'],
        );

        if (newUserLat != userLatitude ||
            newUserLon != userLongitude ||
            newAmbulanceLat != ambulanceLatitude ||
            newAmbulanceLon != ambulanceLongitude) {
          setState(() {
            userLatitude = newUserLat;
            userLongitude = newUserLon;
            ambulanceLatitude = newAmbulanceLat;
            ambulanceLongitude = newAmbulanceLon;
            isLoading = false;
          });
        }

        _currentDistance = calculateDistance(
          userLatitude,
          userLongitude,
          ambulanceLatitude,
          ambulanceLongitude,
        );

        if (_currentDistance <= _alertDistance) {
          _showApproachAlert(_currentDistance);
        } else {
          _alertShown = false;
        }
      }
    } catch (e) {
      print("Location fetch error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchProfileData();
    _fetchUserEmergencyNumbers();
    _locationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _fetchLocations();
    });
  }

  Future<void> _fetchProfileData() async {
    try {
      if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
        await MongoDatabase.connect();
      }

      final collection =
      widget.userType == UserType.Hospital
          ? MongoDatabase.hospitalCollection
          : MongoDatabase.userCollection;

      final emailKey =
      widget.userType == UserType.Hospital ? 'hospitalEmail' : 'email';
      final profileData = await collection.findOne({emailKey: widget.email});

      setState(() {
        _profileData = profileData;
        _isProfileLoading = false;
      });
    } catch (e) {
      print("Profile fetch error: $e");
      setState(() => _isProfileLoading = false);
    }
  }

  @override
  void dispose() {
    _locationTimer.cancel();
    super.dispose();
  }

  int _currentIndex = 0;
  final List<String> _titles = [
    "Live Location",
    "Profile",
    "Emergency Services",
  ];

  void _toggleEmergencyOptions() {
    setState(() => _showEmergencyOptions = !_showEmergencyOptions);
  }

  bool _isEditingEmergencyNumbers = false;
  final List<Map<String, String>> _userEmergencyNumbers = [];

  Future<void> _addEmergencyNumber(String name, String number) async {
    setState(() {
      _userEmergencyNumbers.add({"name": name, "number": number});
    });

    try {
      final collection = MongoDatabase.userCollection;
      await collection.updateOne(
        {"email": widget.email},
        {
          "\$push": {
            "emergency": {"name": name, "number": number},
          },
        },
      );
    } catch (e) {
      print("Error adding emergency number: $e");
    }
  }

  Future<void> _removeEmergencyNumber(int index) async {
    final removedNumber = _userEmergencyNumbers[index];
    setState(() {
      _userEmergencyNumbers.removeAt(index);
    });

    try {
      final collection = MongoDatabase.userCollection;
      await collection.updateOne(
        {"email": widget.email},
        {
          "\$pull": {
            "emergency": {
              "name": removedNumber["name"],
              "number": removedNumber["number"],
            },
          },
        },
      );
    } catch (e) {
      print("Error removing emergency number: $e");
    }
  }

  Future<void> _fetchUserEmergencyNumbers() async {
    try {
      final collection = MongoDatabase.userCollection;
      final userData = await collection.findOne({"email": widget.email});
      final emergencyNumbers = userData?["emergency"] as List<dynamic>? ?? [];
      setState(() {
        _userEmergencyNumbers.addAll(
          emergencyNumbers.map(
                (e) => {
              "name": e["name"] as String,
              "number": e["number"] as String,
            },
          ),
        );
      });
    } catch (e) {
      print("Error fetching user emergency numbers: $e");
    }
  }

  Future<void> _callEmergencyNumber(String number) async {
    final Uri callUri = Uri.parse("tel:$number");
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);

      // Send SMS for user-added numbers
      if (!_isDefaultEmergencyNumber(number)) {
        _sendEmergencyMessage(number);
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not launch $number")));
    }
  }

  bool _isDefaultEmergencyNumber(String number) {
    return ["102", "100"].contains(number); // Default emergency numbers
  }

  void _sendEmergencyMessage(String number) {
    String message =
        "Emergency! I need help. Please contact me immediately. "
        "My current location is: https://www.google.com/maps?q=$userLatitude,$userLongitude";

    if (Platform.isAndroid) {
      telephony.sendSms(to: number, message: message);
    } else if (Platform.isIOS) {
      _showIosAlert(number, message);
    }
  }

  void _showIosAlert(String number, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Apple Security Restriction"),
          content: const Text(
            "iOS does not allow sending SMS automatically. Please send it manually.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final Uri smsUri = Uri.parse("sms:$number?body=$message");
                if (await canLaunchUrl(smsUri)) {
                  await launchUrl(smsUri);
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildMapView(),
              _buildUserProfile(),
              _buildEmergencyServicesTab(),
            ],
          ),
          _buildEmergencyOptions(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.blue.shade600,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: "Emergency",
          ),
        ],
      ),
      floatingActionButton:
      _showEmergencyOptions
          ? null
          : FloatingActionButton(
        onPressed: _toggleEmergencyOptions,
        backgroundColor: Colors.red,
        child: const Text(
          "SOS",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Center(
      child:
      isLoading
          ? const CircularProgressIndicator()
          : FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(userLatitude, userLongitude),
          initialZoom: 17.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(userLatitude, userLongitude),
                width: 40.0,
                height: 40.0,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              Marker(
                point: LatLng(ambulanceLatitude, ambulanceLongitude),
                width: 40.0,
                height: 40.0,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ],
          ),
          if (_currentDistance <= _alertDistance * 3)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    LatLng(userLatitude, userLongitude),
                    LatLng(ambulanceLatitude, ambulanceLongitude),
                  ],
                  color: Colors.red,
                  strokeWidth: 3.0,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildUserProfile() {
    if (_isProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profileData == null) {
      return const Center(child: Text("No profile data"));
    }

    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Text(
                  _profileData!['name']?.substring(0, 1) ?? '?',
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _profileData!['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(_profileData!['email'] ?? 'No email'),
              const SizedBox(height: 10),
              Text(_profileData!['phone'] ?? 'No phone'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _logoutUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logoutUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear login state

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => UserSelectionScreen()),
          (route) => false,
    );
  }

  Widget _buildEmergencyServicesTab() {
    final services = [
      {
        "name": "Ambulance",
        "number": "102",
        "icon": Icons.medical_services,
        "color": Colors.red,
      },
      {
        "name": "Police",
        "number": "100",
        "icon": Icons.local_police,
        "color": Colors.blue,
      },
      {
        "name": "Fire",
        "number": "101",
        "icon": Icons.fire_truck,
        "color": Colors.orange,
      },
      {
        "name": "Road Accident Emergency",
        "number": "1073",
        "icon": Icons.car_crash,
        "color": Colors.red,
      },
      {
        "name": "Highway Accident Emergency",
        "number": "1033",
        "icon": Icons.emergency,
        "color": Colors.red,
      },
      {
        "name": "Women Helpline",
        "number": "1091",
        "icon": Icons.woman,
        "color": Colors.purple,
      },
      {
        "name": "Domestic Abuse Helpline",
        "number": "181",
        "icon": Icons.security,
        "color": Colors.purple,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: Icon(
              service['icon'] as IconData,
              color: service['color'] as Color,
              size: 30,
            ),
            title: Text(
              service['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => launchUrl(Uri.parse("tel:${service['number']}")),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyOptions() {
    final int itemCount =
        2 + _userEmergencyNumbers.length + (_isEditingEmergencyNumbers ? 1 : 0);
    final double boxHeight = (itemCount * 70.0).clamp(
      240.0,
      MediaQuery.of(context).size.height * 0.8,
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showEmergencyOptions ? 0.0 : -boxHeight,
      left: 0,
      right: 0,
      child: Container(
        height: boxHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Emergency Services",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isEditingEmergencyNumbers ? Icons.done : Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed:
                            () => setState(() {
                          _isEditingEmergencyNumbers =
                          !_isEditingEmergencyNumbers;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _toggleEmergencyOptions,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (_isEditingEmergencyNumbers)
                    ListTile(
                      leading: const Icon(Icons.add, color: Colors.green),
                      title: const Text("Add Emergency Number"),
                      onTap: () => _showAddEmergencyNumberDialog(),
                    ),
                  _buildEmergencyListItem("Ambulance", "102", isDefault: true),
                  _buildEmergencyListItem("Police", "100", isDefault: true),
                  ..._userEmergencyNumbers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final number = entry.value;
                    return _buildEmergencyListItem(
                      number["name"]!,
                      number["number"]!,
                      isDefault: false,
                      onDelete: () => _removeEmergencyNumber(index),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyListItem(
      String title,
      String number, {
        bool isDefault = false,
        VoidCallback? onDelete,
      }) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(number),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () => _callEmergencyNumber(number),
          ),
          if (!isDefault && _isEditingEmergencyNumbers)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  Future<void> _showAddEmergencyNumberDialog() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text("Add Emergency Number"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: "Number"),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final number = numberController.text.trim();
              if (name.isNotEmpty && number.isNotEmpty) {
                _addEmergencyNumber(name, number);
                Navigator.of(context).pop();
              }
            },
            child: const Text("Add Number"),
          ),
        ],
      ),
    );
  }
}