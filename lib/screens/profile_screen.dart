import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/editprofile_screen.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var user = FirebaseAuth.instance.currentUser;
  var db = FirebaseFirestore.instance;

  // Hiển thị danh sách bạn bè
  void showFriendsListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Danh sách bạn bè",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              StreamBuilder(
                stream: db
                    .collection("friends")
                    .where("friendIds", arrayContains: user!.uid)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  var friendsDocs = snapshot.data!.docs;
                  if (friendsDocs.isEmpty) {
                    return Text("Bạn chưa có bạn bè nào.");
                  }

                  return SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: friendsDocs.length,
                      itemBuilder: (context, index) {
                        var friendData =
                            friendsDocs[index].data() as Map<String, dynamic>;
                        var friendIds =
                            friendData["friendIds"] as List<dynamic>;
                        var friendNames =
                            friendData["friendNames"] as List<dynamic>;
                        var friendIndex =
                            friendIds.indexOf(user!.uid) == 0 ? 1 : 0;
                        var friendId = friendIds[friendIndex];
                        var friendName = friendNames[friendIndex];
                        var friendDocId = friendsDocs[index].id;

                        return ListTile(
                          title: Text(friendName ?? "Người dùng ẩn danh"),
                          leading: CircleAvatar(
                            child: Text(
                                friendName != null && friendName.isNotEmpty
                                    ? friendName[0].toUpperCase()
                                    : "?"),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.person_remove, color: Colors.red),
                            onPressed: () => unfriend(friendId, friendDocId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Đóng"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hủy kết bạn
  void unfriend(String friendId, String friendDocId) async {
    try {
      // Xóa document duy nhất của mối quan hệ bạn bè
      await db.collection("friends").doc(friendDocId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã hủy kết bạn thành công!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi hủy kết bạn: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text("Thông tin cá nhân")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 70,
              backgroundColor: Colors.blueAccent,
              child: Text(
                userProvider.userName[0],
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            Text(userProvider.userName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(userProvider.userEmail,
                style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            SizedBox(height: 20),
            _buildProfileDetail(Icons.phone, "SĐT", userProvider.phoneNumber),
            _buildProfileDetail(Icons.home, "Địa Chỉ", userProvider.address),
            _buildProfileDetail(
                Icons.cake, "Ngày Sinh", userProvider.birthDate),
            SizedBox(height: 20),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () => showFriendsListDialog(context),
              child: Text("Danh sách bạn bè",
                  style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditProfileScreen()));
              },
              child: Text("Chỉnh sửa thông tin",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text("$label: ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
