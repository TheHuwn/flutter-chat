import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:globalchat/screens/profile_screen.dart';
import 'package:globalchat/screens/spash_screen.dart';
import 'package:provider/provider.dart';
import 'package:globalchat/services/theme_service.dart';

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
  List<Map<String, dynamic>> filteredChatroomsList = []; // Danh sách đã lọc
  TextEditingController searchController = TextEditingController();

  void getChatRooms() {
    db.collection("chatrooms").get().then((dataSnapshot) {
      for (var singleChatRoomData in dataSnapshot.docs) {
        chatroomsList.add(singleChatRoomData.data());
        chatroomsIDs.add(singleChatRoomData.id);
        filteredChatroomsList =
            List.from(chatroomsList); // Khởi tạo danh sách lọc
      }
      setState(() {}); // make sure to put setState inside the async call
    });
  }

  void filterChatrooms(String keyword) {
    setState(() {
      filteredChatroomsList = chatroomsList
          .where((chatroom) => chatroom["chatroom_name"]
              .toString()
              .toLowerCase()
              .contains(keyword.toLowerCase()))
          .toList();
    });
  }

  @override
  void initState() {
    getChatRooms();
    // TODO: implement initState
    super.initState();
  }

  void toggleOnlineStatus(UserProvider userProvider, bool newStatus) async {
    if (user != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .update({"status": newStatus ? "online" : "offline"});
      userProvider.updateStatus(newStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    var userProvider = Provider.of<UserProvider>(context);
    var theme = Theme.of(context); // Lấy theme hiện tại

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.colorScheme.background, // Áp dụng màu nền từ theme
      appBar: AppBar(
        title: Text(
          "Global Chat",
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        leading: InkWell(
          onTap: () {
            scaffoldKey.currentState!.openDrawer();
          },
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Text(
                    userProvider.userName[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: userProvider.isOnline ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor:
            theme.colorScheme.surface, // Áp dụng màu nền theo theme
        child: Container(
          child: Column(
            children: [
              SizedBox(
                height: 50,
              ),
              ListTile(
                onTap: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return ProfileScreen();
                  }));
                },
                leading: Icon(Icons.people, color: theme.colorScheme.onSurface),
                title: Text(userProvider.userName,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text(userProvider.userEmail,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7))),
              ),
              ListTile(
                leading: Icon(Icons.nightlight_round,
                    color: theme.colorScheme.onSurface),
                title: Text("Dark Mode",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme(value);
                      },
                    );
                  },
                ),
              ),
              ListTile(
                leading: Icon(
                  userProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: userProvider.isOnline ? Colors.green : Colors.red,
                ),
                title: Text("Operating Status",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                trailing: Switch(
                  value: userProvider.isOnline,
                  onChanged: (value) => toggleOnlineStatus(userProvider, value),
                ),
              ),
              ListTile(
                onTap: () async {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return ProfileScreen();
                  }));
                },
                leading: Icon(Icons.people, color: theme.colorScheme.onSurface),
                title: Text("Profile",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
              ListTile(
                onTap: () async {
                  var user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(user.uid)
                        .update({"status": "offline"});
                  }

                  await FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (context) {
                    return SplashScreen();
                  }), (route) => false);
                },
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text("Logout",
                    style: TextStyle(color: theme.colorScheme.error)),
              )
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: filterChatrooms,
              decoration: InputDecoration(
                hintText: "Search chat room...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredChatroomsList.length,
              itemBuilder: (context, index) {
                String chatroomName =
                    filteredChatroomsList[index]["chatroom_name"] ?? "";
                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatRoomScreen(
                          chatroomName: chatroomName,
                          chatroomId: chatroomsIDs[index],
                        ),
                      ),
                    );
                  },
                  title: Text(chatroomName),
                  leading: CircleAvatar(
                    child: Text(chatroomName.isNotEmpty
                        ? chatroomName[0].toUpperCase()
                        : "?"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
