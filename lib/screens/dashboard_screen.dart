import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:globalchat/screens/profile_screen.dart';
import 'package:globalchat/screens/spash_screen.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var user = FirebaseAuth.instance.currentUser;
  var db = FirebaseFirestore.instance;
  var scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> chatroomsList = [];
  List<String> chatroomsIDs = [];

  void getChatRooms() {
    db.collection("chatrooms").get().then((dataSnapshot) {
      for (var singleChatRoomData in dataSnapshot.docs) {
        chatroomsList.add(singleChatRoomData.data());
        chatroomsIDs.add(singleChatRoomData.id);
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
    var userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text("Global Chat"),
          leading: InkWell(
            onTap: () {
              scaffoldKey.currentState!.openDrawer();
            },
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: CircleAvatar(
                radius: 20,
                child: Text(userProvider.userName[0]),
              ),
            ),
          ),
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
                  title: Text(userProvider.userName),
                  subtitle: Text(userProvider.userEmail),
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
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return ChatRoomScreen(
                      chatroomName: chatroomName,
                      chatroomId: chatroomsIDs[index]);
                }));
              },
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey[900],
                child: Text(chatroomName.isNotEmpty ? chatroomName[0] : "?"),
              ),
              title: Text(chatroomName),
              subtitle: Text(chatroomName),
            );
          },
        ));
  }
}
