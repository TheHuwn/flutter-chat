import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String userName = "Name";
  String userEmail = "Email";
  String userID = "ID";
  bool isOnline = true; // Mặc định Online khi đăng nhập

  var db = FirebaseFirestore.instance;

  void getUserDetails() {
    var authUser = FirebaseAuth.instance.currentUser;
    db.collection("users").doc(authUser!.uid).get().then((dataSnapshot) {
      userName = dataSnapshot.data()?["name"] ?? "";
      userEmail = dataSnapshot.data()?["email"] ?? "";
      userID = dataSnapshot.data()?["id"] ?? "";
      isOnline = dataSnapshot.data()?["status"] ==
          "online"; // Lấy trạng thái từ Firestore
      notifyListeners();
    });
  }

  void updateStatus(bool status) {
    var authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      db.collection("users").doc(authUser.uid).update({
        "status": status ? "online" : "offline",
      });
      isOnline = status;
      notifyListeners();
    }
  }
}
