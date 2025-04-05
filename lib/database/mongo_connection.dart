import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static var db, userCollection, hospitalCollection, policeCollection;

  static Future<void> connect() async {
    try {
      // Replace <username>, <password>, and <database> with your details
      db = await Db.create("mongodb+srv://bhoopendra:5rJb0naEScLW5vFk@cluster0.zdwpe4a.mongodb.net/?retryWrites=true&w=majority&appName=registration");
      await db.open();

      // Collections for different registrations
      userCollection = db.collection("users");
      hospitalCollection = db.collection("hospitals");
      policeCollection = db.collection("police");

      print("✅ MongoDB Connected Successfully!");
    } catch (e) {
      print("❌ MongoDB Connection Error: $e");
    }
  }
}
