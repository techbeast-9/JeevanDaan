import 'package:flutter/material.dart';
import 'screens/user_selection_screen.dart';

import 'database/mongo_connection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MongoDatabase.connect(); // Initialize MongoDB before running the app

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: LandingPage());
  }
}

// Landing Page
class LandingPage extends StatefulWidget {
  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    _checkAmbulanceStatus();
  }

  Future<void> _checkAmbulanceStatus() async {
    // Removed shared preferences check and notify logic
    bool isAmbulanceActive = await _fetchAmbulanceStatus();

    // Here you can handle what to do if the ambulance status is active
    if (isAmbulanceActive) {
      // Possible future actions if needed
    }
  }

  Future<bool> _fetchAmbulanceStatus() async {
    // Fetch real-time ambulance status from API or database
    // Simulating with a true value (replace with actual logic)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_hospital, size: 100, color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'JeevanDan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserSelectionScreen(),
                      ),
                    );
                  },
                  child: Text('Get Started'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
