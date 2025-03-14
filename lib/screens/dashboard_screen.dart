import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:globalchat/screens/profile_screen.dart';
import 'package:globalchat/screens/spash_screen.dart';
import 'package:globalchat/screens/create_group_chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:globalchat/services/theme_service.dart';
import 'dart:async'; // Thêm để dùng StreamSubscription

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

  // Biến để theo dõi số lượng yêu cầu kết bạn chưa xử lý
  int pendingFriendRequestsCount = 0;
  StreamSubscription<QuerySnapshot>?
      _friendRequestsSubscription; // Để hủy listener

  void togglePinChatroom(String chatroomId, bool currentPinStatus) async {
    try {
      await db.collection("chatrooms").doc(chatroomId).update({
        "isPinned": !currentPinStatus,
        "pinnedBy": FieldValue.arrayUnion([user!.uid]), // Lưu người ghim
      });

      // Cập nhật local state
      setState(() {
        int index = chatroomsList
            .indexWhere((chat) => chat["chatroomId"] == chatroomId);
        if (index != -1) {
          chatroomsList[index]["isPinned"] = !currentPinStatus;
          filteredChatroomsList = List.from(chatroomsList);
          // Sắp xếp lại để đưa chatroom được ghim lên đầu
          filteredChatroomsList.sort((a, b) {
            bool aPinned = a["isPinned"] == true;
            bool bPinned = b["isPinned"] == true;
            if (aPinned && !bPinned) return -1;
            if (!aPinned && bPinned) return 1;
            return 0;
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentPinStatus ? "Đã bỏ ghim" : "Đã ghim")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: $e")),
      );
    }
  }

  void getChatRooms() {
    if (user == null) return;

    chatroomsList.clear();
    chatroomsIDs.clear();

    // Truy vấn nhóm công cộng (isGroup == false)
    db
        .collection("chatrooms")
        .where("isGroup", isEqualTo: false)
        .get()
        .then((publicSnapshot) {
      for (var doc in publicSnapshot.docs) {
        chatroomsList.add(doc.data());
        chatroomsIDs.add(doc.id);
      }

      // Truy vấn nhóm riêng tư
      db
          .collection("chatrooms")
          .where("isGroup", isEqualTo: true)
          .where("members", arrayContains: user!.uid)
          .get()
          .then((privateSnapshot) {
        for (var doc in privateSnapshot.docs) {
          chatroomsList.add(doc.data());
          chatroomsIDs.add(doc.id);
        }

        setState(() {
          filteredChatroomsList = List.from(chatroomsList);
        });
      }).catchError((error) {
        print("Lỗi khi lấy nhóm riêng tư: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể tải nhóm riêng tư: $error")),
        );
      });
    }).catchError((error) {
      print("Lỗi khi lấy nhóm công cộng: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải nhóm công cộng: $error")),
      );
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

  void getPendingFriendRequestsCount() {
    if (user == null) return;
    _friendRequestsSubscription = db
        .collection("friendRequests")
        .where("receiverId", isEqualTo: user!.uid)
        .where("status", isEqualTo: "pending")
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        // Kiểm tra widget còn tồn tại
        setState(() {
          pendingFriendRequestsCount = snapshot.docs.length;
        });
      }
    }, onError: (error) {
      print("Lỗi lắng nghe friendRequests: $error");
    });
  }

  // Hiển thị danh sách yêu cầu kết bạn
  void showFriendRequestsDialog(BuildContext context) {
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
                "Yêu cầu kết bạn",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              StreamBuilder(
                stream: db
                    .collection("friendRequests")
                    .where("receiverId", isEqualTo: user!.uid)
                    .where("status", isEqualTo: "pending")
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  var requests = snapshot.data!.docs;
                  if (requests.isEmpty) {
                    return Text("Không có yêu cầu kết bạn nào.");
                  }
                  return SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        var request =
                            requests[index].data() as Map<String, dynamic>;
                        var requestId = requests[index].id;
                        var senderId = request["senderId"];
                        var senderName =
                            request["senderName"] ?? "Người dùng ẩn danh";

                        return ListTile(
                          title: Text(senderName),
                          subtitle: Text("Đã gửi lời mời kết bạn"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.check, color: Colors.green),
                                onPressed: () =>
                                    acceptFriendRequest(requestId, senderId),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.red),
                                onPressed: () =>
                                    declineFriendRequest(requestId),
                              ),
                            ],
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

  // Chấp nhận yêu cầu kết bạn
  void acceptFriendRequest(String requestId, String senderId) async {
    try {
      var userProvider = Provider.of<UserProvider>(context, listen: false);
      var currentUserId = userProvider.userID;
      var currentUserName = userProvider.userName;

      // Lấy thông tin yêu cầu kết bạn
      var requestDoc =
          await db.collection("friendRequests").doc(requestId).get();
      var requestData = requestDoc.data() as Map<String, dynamic>? ?? {};
      var senderName = requestData["senderName"] ?? "Người dùng ẩn danh";

      // Xóa yêu cầu kết bạn
      await db.collection("friendRequests").doc(requestId).delete();

      // Tạo một document duy nhất cho mối quan hệ bạn bè
      await db.collection("friends").add({
        "friendIds": [currentUserId, senderId], // Mảng chứa cả hai UID
        "friendNames": [currentUserName, senderName], // Mảng chứa cả hai tên
        "timestamp": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã chấp nhận kết bạn!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: $e")),
      );
    }
  }

  // Từ chối yêu cầu kết bạn
  void declineFriendRequest(String requestId) async {
    try {
      await db.collection("friendRequests").doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã từ chối kết bạn.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: $e")),
      );
    }
  }

  @override
  void initState() {
    getChatRooms();
    getPendingFriendRequestsCount(); // Lấy số lượng yêu cầu kết bạn
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    _friendRequestsSubscription?.cancel(); // Hủy listener khi widget bị dispose
    super.dispose();
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
                leading: Icon(
                  Icons.account_circle,
                  color: theme.colorScheme.onSurface,
                  size: 28,
                ),
                title: Text(userProvider.userName,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text(userProvider.userEmail,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7))),
              ),
              ListTile(
                leading: Icon(Icons.nightlight_round,
                    color: theme.colorScheme.onSurface),
                title: Text("Chế độ tối",
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
                title: Text("Trạng thái hoạt động",
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
                leading: Icon(Icons.person, color: theme.colorScheme.onSurface),
                title: Text("Hồ sơ",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
              // Thêm mục xem yêu cầu kết bạn
              ListTile(
                onTap: () => showFriendRequestsDialog(context),
                leading: Stack(
                  children: [
                    Icon(Icons.person_add, color: theme.colorScheme.onSurface),
                    if (pendingFriendRequestsCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text("Yêu cầu kết bạn",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
              ListTile(
                onTap: () async {
                  // Mở CreateGroupChatScreen và chờ kết quả
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CreateGroupChatScreen()),
                  );

                  // Kiểm tra nếu có dữ liệu trả về (nhóm chat mới)
                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      chatroomsList.add(result);
                      chatroomsIDs.add(result["chatroomId"]);
                      filteredChatroomsList = List.from(chatroomsList);
                    });
                  }
                },
                leading:
                    Icon(Icons.group_add, color: theme.colorScheme.onSurface),
                title: Text("Tạo nhóm chat",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
              ListTile(
                onTap: () async {
                  try {
                    // Hủy listener trước
                    _friendRequestsSubscription?.cancel();

                    // Cập nhật trạng thái offline trước khi đăng xuất
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection("users")
                          .doc(user!.uid)
                          .update({"status": "offline"});
                    }

                    // Đăng xuất sau khi cập nhật Firestore thành công
                    await FirebaseAuth.instance.signOut();

                    // Chuyển hướng về SplashScreen
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => SplashScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    // Xử lý lỗi nếu có
                    print("Lỗi khi đăng xuất: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Đăng xuất thất bại: $e")),
                    );
                  }
                },
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  "Đăng xuất",
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
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
                bool isGroup = filteredChatroomsList[index]["isGroup"] ?? false;
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
                  trailing: Icon(
                    isGroup ? Icons.people : Icons.public,
                    color: isGroup ? Colors.blue : Colors.green,
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
