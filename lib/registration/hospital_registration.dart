import 'package:flutter/material.dart';
import '../screens/hospital_live_screen.dart';
import '../database/mongo_connection.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class HospitalRegistrationScreen extends StatefulWidget {
  @override
  _HospitalRegistrationScreenState createState() =>
      _HospitalRegistrationScreenState();
}

class _HospitalRegistrationScreenState
    extends State<HospitalRegistrationScreen> {
  final TextEditingController hospitalNameController = TextEditingController();
  final TextEditingController hospitalPhoneController = TextEditingController();
  final TextEditingController hospitalEmailController = TextEditingController();
  final TextEditingController hospitalLoginEmailController =
  TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoggingIn = false;

  Future<void> _registerHospitalToDB() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
          await MongoDatabase.connect();
        }

        final hospitalData = {
          "_id": mongo.ObjectId().toHexString(),
          "hospitalName": hospitalNameController.text,
          "hospitalPhone": hospitalPhoneController.text,
          "hospitalEmail": hospitalEmailController.text,
          "createdAt": DateTime.now().toIso8601String(),
        };

        var result = await MongoDatabase.hospitalCollection.insertOne(
          hospitalData,
        );

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ Hospital Registered Successfully!")),
          );

          // Navigate to Hospital Live Location Screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HospitalLiveLocationScreen(
                hospitalEmail: hospitalEmailController.text, // Pass email
              ),
            ),
                (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Registration Failed! Please try again.")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("⚠️ Error: ${e.toString()}")));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginHospital() async {
    if (hospitalLoginEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Please enter your email to login")),
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
        await MongoDatabase.connect();
      }

      var hospital = await MongoDatabase.hospitalCollection.findOne({
        "hospitalEmail": hospitalLoginEmailController.text,
      });

      if (hospital != null) {
        // Navigate to Hospital Live Location Screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HospitalLiveLocationScreen(
              hospitalEmail: hospitalLoginEmailController.text, // Pass email
            ),
          ),
              (route) => false,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Login Successful!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No hospital found with this email.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ Error: ${e.toString()}")));
    } finally {
      setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hospital Registration',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade800,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: hospitalNameController,
                decoration: InputDecoration(
                  labelText: 'Hospital Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value!.isEmpty ? 'Please enter the hospital name' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: hospitalPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Hospital Phone',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value!.isEmpty ? 'Please enter the hospital phone number' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: hospitalEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Hospital Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter the hospital email';
                  if (!RegExp(
                    r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$",
                  ).hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerHospitalToDB,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Register',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Divider(thickness: 1),
              SizedBox(height: 10),
              Center(
                child: Text(
                  "Already registered? Login",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: hospitalLoginEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Enter hospital email',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoggingIn ? null : _loginHospital,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: _isLoggingIn
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Login',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}