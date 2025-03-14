import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:provider/provider.dart';

class CreateGroupChatScreen extends StatefulWidget {
  @override
  _CreateGroupChatScreenState createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  var db = FirebaseFirestore.instance;
  var user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> friendsList = [];
  List<String> selectedFriendIds = [];
  TextEditingController groupNameController = TextEditingController();
  TextEditingController groupDescriptionController = TextEditingController();
  bool showGroupDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  // Lấy danh sách bạn bè từ Firestore
  void _fetchFriends() async {
    if (user == null) return;
    try {
      var friendsSnapshot = await db
          .collection("friends")
          .where("friendIds", arrayContains: user!.uid)
          .get();
      setState(() {
        friendsList = friendsSnapshot.docs.map((doc) {
          var data = doc.data();
          var friendIds = data["friendIds"] as List<dynamic>;
          var friendNames = data["friendNames"] as List<dynamic>;
          var friendIndex = friendIds.indexOf(user!.uid) == 0 ? 1 : 0;
          return {
            "id": friendIds[friendIndex],
            "name": friendNames[friendIndex],
          };
        }).toList();
      });
    } catch (e) {
      print("Lỗi khi lấy danh sách bạn bè: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải danh sách bạn bè: $e")),
      );
    }
  }

  // Chuyển sang bước đặt tên nhóm khi đủ 3 thành viên
  void _proceedToGroupDetails() {
    if (selectedFriendIds.length + 1 < 3) {
      // +1 cho người tạo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cần ít nhất 3 thành viên để tạo nhóm chat")),
      );
    } else {
      setState(() {
        showGroupDetails = true;
      });
    }
  }

  // Tạo nhóm chat
  void _createGroupChat() async {
    if (groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vui lòng nhập tên nhóm")),
      );
      return;
    }

    try {
      var userProvider = Provider.of<UserProvider>(context, listen: false);
      List<String> memberIds = [user!.uid, ...selectedFriendIds];
      List<String> memberNames = [
        userProvider.userName,
        ...selectedFriendIds.map((id) =>
            friendsList.firstWhere((friend) => friend["id"] == id)["name"])
      ];

      var groupData = {
        "chatroom_name": groupNameController.text,
        "description": groupDescriptionController.text,
        "members": memberIds,
        "memberNames": memberNames,
        "admins": [user!.uid], // Người tạo nhóm là admin mặc định
        "timestamp": FieldValue.serverTimestamp(),
        "isGroup": true,
      };

      var docRef = await db.collection("chatrooms").add(groupData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tạo nhóm chat thành công!")),
      );

      Map<String, dynamic> newChatroom = Map.from(groupData);
      newChatroom["chatroomId"] = docRef.id;

      Navigator.pop(context, newChatroom);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatroomName: groupNameController.text,
            chatroomId: docRef.id,
          ),
        ),
      );
    } catch (e) {
      print("Lỗi khi tạo nhóm chat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tạo nhóm chat: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(showGroupDetails ? "Tạo nhóm chat" : "Chọn bạn bè"),
      ),
      body:
          showGroupDetails ? _buildGroupDetailsForm() : _buildFriendSelection(),
    );
  }

  // Giao diện chọn bạn bè
  Widget _buildFriendSelection() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "Chọn bạn để thêm vào nhóm (ít nhất 3 thành viên)",
            style: TextStyle(fontSize: 16),
          ),
        ),
        Expanded(
          child: friendsList.isEmpty
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: friendsList.length,
                  itemBuilder: (context, index) {
                    var friend = friendsList[index];
                    return CheckboxListTile(
                      title: Text(friend["name"]),
                      value: selectedFriendIds.contains(friend["id"]),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedFriendIds.add(friend["id"]);
                          } else {
                            selectedFriendIds.remove(friend["id"]);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: _proceedToGroupDetails,
            child: Text("Tiếp tục"),
          ),
        ),
      ],
    );
  }

  // Giao diện đặt tên và mô tả nhóm
  Widget _buildGroupDetailsForm() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: groupNameController,
            decoration: InputDecoration(
              labelText: "Tên nhóm chat",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: groupDescriptionController,
            decoration: InputDecoration(
              labelText: "Mô tả nhóm (tùy chọn)",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _createGroupChat,
            child: Text("Tạo nhóm"),
          ),
        ],
      ),
    );
  }
}
