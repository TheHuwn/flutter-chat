import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData = {};

  // var db = FirebaseFirestore.instance;
  // var authUser = FirebaseAuth.instance.currentUser;
  //   db.collection("users").doc(authUser!.uid).get().then((dataSnapshot) {
  //     userData = dataSnapshot.data();
  //     setState(() {});
  //   });
  // }

  @override
  void initState() {
    // getData();

    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text("Profile Screen")),
      body: Column(
        children: [
          Text(userProvider.userName),
          Text(userProvider.userID),
          Text(userProvider.userEmail),
        ],
      ),
    );
  }
}
