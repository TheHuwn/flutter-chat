import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/screens/profile_screen.dart';
import 'package:globalchat/screens/spash_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var user = FirebaseAuth.instance.currentUser;
  var db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> chatroomsList = [];

  void getChatRooms() {
    db.collection("chatrooms").get().then((dataSnapshot) {
      for (var singleChatRoomData in dataSnapshot.docs) {
        chatroomsList.add(singleChatRoomData.data());
        print("Data added : ${singleChatRoomData.data()}");
        print("chatroomsList content : ${chatroomsList}");
      }
      setState(() {}); // make sure to put setState inside the async call
    });
  }

  @override
  void initState() {
    getChatRooms();
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Global Chat"),
        ),
        drawer: Drawer(
          child: Container(
            child: Column(
              children: [
                SizedBox(
                  height: 50,
                ),
                ListTile(
                  onTap: () async {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return ProfileScreen();
                    }));
                  },
                  leading: Icon(Icons.people),
                  title: Text("Profile"),
                ),
                ListTile(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (context) {
                      return SplashScreen();
                    }), (route) {
                      return false;
                    });
                  },
                  leading: Icon(Icons.logout),
                  title: Text("Logout"),
                )
              ],
            ),
          ),
        ),
        body: ListView.builder(
          itemCount: chatroomsList.length,
          itemBuilder: (BuildContext context, int index) {
            print("chat room list data is ${chatroomsList}");
            String chatroomName = chatroomsList[index]["chatroom_name"] ?? "";
            // print("ChatROOMNAME is ${chatroomName}");
            return ListTile(
              leading: CircleAvatar(
                child: Text(chatroomName.isNotEmpty ? chatroomName[0] : "?"),
              ),
              title: Text(chatroomName),
              subtitle: Text(chatroomName),
            );
          },
        ));
  }
}
