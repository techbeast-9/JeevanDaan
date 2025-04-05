import 'package:flutter/material.dart';
import '../screens/live_location_screen.dart';
import '../database/mongo_connection.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';

class UserRegistrationScreen extends StatefulWidget {
  @override
  _UserRegistrationScreenState createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController userPhoneController = TextEditingController();
  final TextEditingController userEmailController = TextEditingController();
  final TextEditingController loginEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoggingIn = false; // Loading state for login

  Future<void> _saveLoginState(String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('loggedInEmail', email);

    // Save session in MongoDB
    await MongoDatabase.userCollection.updateOne(
      {"email": email},
      {
        "\$set": {
          "isLoggedIn": true,
          "lastLogin": DateTime.now().toIso8601String(),
        },
      },
    );
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        if (MongoDatabase.db == null || !MongoDatabase.db.isConnected) {
          await MongoDatabase.connect();
        }

        final userData = {
          "_id": mongo.ObjectId().toHexString(),
          "name": userNameController.text,
          "phone": userPhoneController.text,
          "email": userEmailController.text,
          "createdAt": DateTime.now().toIso8601String(),
        };

        var result = await MongoDatabase.userCollection.insertOne(userData);

        if (result.isSuccess) {
          await _saveLoginState(userEmailController.text); // Save login state
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (context) => LiveLocationScreen(
                userType: UserType.User,
                email:
                userEmailController.text, // Pass the registered email
              ),
            ),
                (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ User Registered Successfully!")),
          );
        } else {
          String errorMessage =
          result.containsKey('errmsg')
              ? result['errmsg']
              : "Unknown error occurred!";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Registration Failed: $errorMessage")),
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

  Future<void> _loginUser() async {
    if (loginEmailController.text.isEmpty) {
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

      var user = await MongoDatabase.userCollection.findOne({
        "email": loginEmailController.text,
      });

      if (user != null) {
        await _saveLoginState(loginEmailController.text); // Save login state
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) => LiveLocationScreen(
              userType: UserType.User,
              email: loginEmailController.text, // Pass the logged-in email
            ),
          ),
              (route) => false,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Login Successful!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No account found with this email.")),
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
        title: Text('User Registration', style: TextStyle(color: Colors.white)),
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
                controller: userNameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: userPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                value!.isEmpty
                    ? 'Please enter your phone number'
                    : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: userEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter your email';
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
                  onPressed: _isLoading ? null : _registerUser,
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
                  "Already have an account? Login",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: loginEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoggingIn ? null : _loginUser,
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