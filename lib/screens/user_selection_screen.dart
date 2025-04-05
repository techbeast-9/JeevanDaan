import 'package:flutter/material.dart';
import 'package:newdemoapp/registration/police_registration.dart';
import '../registration/user_registration.dart';
import '../registration/hospital_registration.dart';


class UserSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select User Type')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSelectionButton(context, Icons.person, 'User', Colors.blue, UserRegistrationScreen()),
            SizedBox(height: 20),
            _buildSelectionButton(context, Icons.local_hospital, 'Hospital', Colors.green, HospitalRegistrationScreen()),
            SizedBox(height: 20),
            _buildSelectionButton(context, Icons.local_police, 'Police', Colors.red, PoliceRegistrationScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton(BuildContext context, IconData icon, String label, Color color, Widget targetScreen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen));
      },
      child: Container(
        width: 200,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, offset: Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.white),
            SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
