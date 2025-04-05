import 'package:flutter/material.dart';
import '../screens/police_map_screen.dart';
import '../database/mongo_connection.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class PoliceRegistrationScreen extends StatefulWidget {
  @override
  _PoliceRegistrationScreenState createState() =>
      _PoliceRegistrationScreenState();
}

class _PoliceRegistrationScreenState extends State<PoliceRegistrationScreen> {
  final TextEditingController policeStationNameController =
  TextEditingController();
  final TextEditingController policePhoneController = TextEditingController();
  final TextEditingController policeEmailController = TextEditingController();
  final TextEditingController policeLoginEmailController =
  TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoggingIn = false;

  Future<void> _registerPoliceStation() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
          await MongoDatabase.connect();
        }

        final policeData = {
          "_id": mongo.ObjectId().toHexString(),
          "policeStationName": policeStationNameController.text,
          "policePhone": policePhoneController.text,
          "policeEmail": policeEmailController.text,
          "createdAt": DateTime.now().toIso8601String(),
        };

        var result = await MongoDatabase.policeCollection.insertOne(policeData);

        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Police Station Registered Successfully!"),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                  AccidentMapScreen(email: policeEmailController.text),
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

  Future<void> _loginPoliceStation() async {
    if (policeLoginEmailController.text.isEmpty) {
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

      var policeStation = await MongoDatabase.policeCollection.findOne({
        "policeEmail": policeLoginEmailController.text,
      });

      if (policeStation != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                AccidentMapScreen(email: policeLoginEmailController.text),
          ),
              (route) => false,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Login Successful!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No police station found with this email.")),
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
          'Police Station Registration',
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
                controller: policeStationNameController,
                decoration: InputDecoration(
                  labelText: 'Police Station Name',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                value!.isEmpty
                    ? 'Please enter the police station name'
                    : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: policePhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Police Phone',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                value!.isEmpty
                    ? 'Please enter the police phone number'
                    : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: policeEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Police Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter the police email';
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
                  onPressed: _isLoading ? null : _registerPoliceStation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child:
                  _isLoading
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
                controller: policeLoginEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Enter police email',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoggingIn ? null : _loginPoliceStation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child:
                  _isLoggingIn
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