import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/screens/dashboard_screen.dart';
import 'package:globalchat/screens/spash_screen.dart';

class SignupController {
  static Future<void> createAccount({
    required String email,
    required String password,
    required String name,
    required String country,
    required BuildContext context,
  }) async {
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      var userId = FirebaseAuth.instance.currentUser!.uid;
      var db = FirebaseFirestore.instance;

      Map<String, dynamic> data = {
        "name": name,
        "country": country,
        "email": email,
        "id": userId.toString()
      };

      try {
        await db.collection("users").doc(userId.toString()).set(data);
      } catch (e) {
        print("Error");
        print(e);
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
        return SplashScreen();
      }));
    } catch (e) {
      SnackBar messageSnackBar =
          SnackBar(backgroundColor: Colors.red, content: Text(e.toString()));
      ScaffoldMessenger.of(context).showSnackBar(messageSnackBar);
    }
  }
}
