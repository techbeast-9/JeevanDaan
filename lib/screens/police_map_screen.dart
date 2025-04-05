import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/mongo_connection.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AccidentMapScreen(email: 'example@example.com'),
    );
  }
}

class AccidentMapScreen extends StatefulWidget {
  final String email;

  const AccidentMapScreen({Key? key, required this.email}) : super(key: key);

  @override
  _AccidentMapScreenState createState() => _AccidentMapScreenState();
}

class _AccidentMapScreenState extends State<AccidentMapScreen> {
  List<Map<String, dynamic>> accidentLocations = [];
  bool isLoading = true;
  int _currentIndex = 0;
  Map<String, dynamic>? policeData;

  @override
  void initState() {
    super.initState();
    fetchAccidentLocations();
    fetchPoliceData();
  }

  Future<void> fetchAccidentLocations() async {
    final url = Uri.parse(
      "https://api.thingspeak.com/channels/2889698/feeds.json?api_key=EAEQH65XGGSQLNY9&results=10",
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        Set<String> uniqueLocations = {};
        List<Map<String, dynamic>> newAccidents = [];

        for (var feed in data['feeds']) {
          double? latitude = double.tryParse(feed['field1'] ?? '');
          double? longitude = double.tryParse(feed['field2'] ?? '');
          String timestamp = feed['created_at'];

          if (latitude == null || longitude == null) continue;
          if (feed['field4'] == "1") {
            String locationKey = "$latitude,$longitude";
            if (!uniqueLocations.contains(locationKey)) {
              uniqueLocations.add(locationKey);
              newAccidents.add({
                "latitude": latitude,
                "longitude": longitude,
                "timestamp": timestamp,
              });
            }
          }
        }

        setState(() {
          accidentLocations = newAccidents;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> fetchPoliceData() async {
    try {
      if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
        await MongoDatabase.connect();
      }

      print("Fetching police data for email: ${widget.email}"); // Debug log

      final data = await MongoDatabase.policeCollection.findOne({
        "policeEmail": widget.email,
      });

      if (data != null) {
        print("Police data fetched: $data"); // Debug log
        setState(() {
          policeData = data;
        });
      } else {
        print("No police data found for email: ${widget.email}"); // Debug log
        setState(() {
          policeData = {}; // Set to an empty map to avoid null issues
        });
      }
    } catch (e) {
      print("Error fetching police data: $e");
      setState(() {
        policeData = {}; // Set to an empty map to avoid null issues
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Accident Alerts", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: _currentIndex == 0 ? buildMapScreen() : buildPoliceProfile(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget buildMapScreen() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter:
                accidentLocations.isNotEmpty
                    ? LatLng(
                      accidentLocations.first['latitude'],
                      accidentLocations.first['longitude'],
                    )
                    : LatLng(20.5937, 78.9629),
            initialZoom: 10.0,
          ),
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a', 'b', 'c'],
            ),
            MarkerLayer(
              markers:
                  accidentLocations
                      .map(
                        (accident) => Marker(
                          point: LatLng(
                            accident['latitude'],
                            accident['longitude'],
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 40.0,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
        if (accidentLocations.isNotEmpty)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Latest Accident Alert:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Location: ${accidentLocations.last['latitude']}, ${accidentLocations.last['longitude']}",
                  ),
                  Text("Time: ${accidentLocations.last['timestamp']}"),
                  SizedBox(height: 5),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget buildPoliceProfile() {
    if (policeData == null) {
      return Center(child: CircularProgressIndicator());
    }

    if (policeData!.isEmpty) {
      return Center(
        child: Text(
          "No profile data available.",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Police Profile",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.person, size: 40, color: Colors.blue),
            title: Text(
              "Officer Name: ${policeData!['policeStationName'] ?? 'N/A'}",
            ),
            subtitle: Text("Badge Number: ${policeData!['_id'] ?? 'N/A'}"),
          ),
          ListTile(
            leading: Icon(Icons.local_police, size: 40, color: Colors.blue),
            title: Text("Department: Traffic Police"),
            subtitle: Text(
              "Station: ${policeData!['policeStationName'] ?? 'N/A'}",
            ),
          ),
          ListTile(
            leading: Icon(Icons.phone, size: 40, color: Colors.blue),
            title: Text("Contact: ${policeData!['policePhone'] ?? 'N/A'}"),
          ),
        ],
      ),
    );
  }
}
