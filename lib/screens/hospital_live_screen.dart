import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../database/mongo_connection.dart';

class HospitalLiveLocationScreen extends StatefulWidget {
  final String hospitalEmail;

  const HospitalLiveLocationScreen({super.key, required this.hospitalEmail});

  @override
  _HospitalLiveLocationScreenState createState() =>
      _HospitalLiveLocationScreenState();
}

class _HospitalLiveLocationScreenState
    extends State<HospitalLiveLocationScreen> {
  double latitude = 0.0;
  double longitude = 0.0;
  bool isLoading = true;
  late Timer _timer;
  int _currentIndex = 0;
  bool _showEmergencyOptions = false;

  final String hospitalApiUrl =
      "https://api.thingspeak.com/channels/2888813/feeds.json?api_key=7G7F91FQ2ABCPZ5R&results=1"; // ambulance url

  Map<String, dynamic>? _profileData; // State variable to store profile data
  bool _isProfileLoading = true; // State variable to track loading status

  Future<void> fetchHospitalLocation() async {
    try {
      final response = await http.get(Uri.parse(hospitalApiUrl));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        final newLatitude = double.parse(data['feeds'][0]['field1']);
        final newLongitude = double.parse(data['feeds'][0]['field2']);

        setState(() {
          latitude = newLatitude;
          longitude = newLongitude;
          isLoading = false;
        });
      } else {
        print("Failed to fetch hospital location data.");
      }
    } catch (e) {
      print("Error fetching hospital location: $e");
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
        await MongoDatabase.connect();
      }

      final collection = MongoDatabase.hospitalCollection;
      final profileData = await collection.findOne({
        'hospitalEmail': widget.hospitalEmail,
      });

      setState(() {
        _profileData = profileData;
        _isProfileLoading = false; // Mark loading as complete
      });
    } catch (e) {
      print("Error fetching profile data: $e");
      setState(() {
        _isProfileLoading = false; // Mark loading as complete even on error
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchHospitalLocation();
    _fetchProfileData(); // Fetch profile data
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchHospitalLocation();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _toggleEmergencyOptions() {
    setState(() {
      _showEmergencyOptions = !_showEmergencyOptions;
    });
  }

  Widget _buildEmergencyOptions() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showEmergencyOptions ? 0.0 : -160.0,
      left: 0,
      right: 0,
      child: Container(
        height: 160,
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
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _toggleEmergencyOptions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildEmergencyListItem("Ambulance", "102"),
                  _buildEmergencyListItem("Police", "100"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyListItem(String title, String number) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: IconButton(
        icon: const Icon(Icons.call, color: Colors.green),
        onPressed: () => launchUrl(Uri.parse("tel:$number")),
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
          initialCenter: LatLng(latitude, longitude),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 50.0,
                height: 50.0,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 30.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    if (_isProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_profileData == null) {
      return const Center(child: Text("No profile data found."));
    }

    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueAccent,
                child: Icon(
                  Icons.local_hospital,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _profileData!['hospitalName'] ?? "Unknown",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(_profileData!['hospitalEmail'] ?? "No Email"),
              const SizedBox(height: 5),
              Text(_profileData!['hospitalPhone'] ?? "No Phone"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyServicesTab() {
    final emergencyContacts = [
      {
        "name": "Ambulance",
        "number": "102",
        "icon": Icons.local_hospital,
        "color": Colors.red,
      },
      {
        "name": "Police",
        "number": "100",
        "icon": Icons.local_police,
        "color": Colors.blue,
      },
      {
        "name": "Fire Brigade",
        "number": "101",
        "icon": Icons.local_fire_department,
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children:
      emergencyContacts.map((service) {
        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: Icon(
              service['icon'] as IconData,
              color: service['color'] as Color,
              size: 30,
            ),
            title: Text(
              service['name'] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.blueAccent),
              onPressed:
                  () => launchUrl(Uri.parse("tel:${service['number']}")),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _titles = ["Map", "Profile", "Emergency Services"];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(color: Colors.white), // ONLY THIS LINE CHANGED
        ),
        backgroundColor: Colors.blue.shade600,
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildMapView(),
              _buildProfile(),
              _buildEmergencyServicesTab(),
            ],
          ),
          _buildEmergencyOptions(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
}