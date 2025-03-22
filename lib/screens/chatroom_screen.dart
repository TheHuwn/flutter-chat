import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Thêm import này
import 'package:globalchat/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_flutter/cloudinary_context.dart';
import 'package:cloudinary_flutter/cloudinary_object.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:globalchat/services/cloudinary_service.dart';
import 'package:globalchat/widgets/videoplayer_widget.dart';
import 'package:globalchat/screens/dashboard_screen.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class ChatRoomScreen extends StatefulWidget {
  final String chatroomName;
  final String chatroomId;

  ChatRoomScreen(
      {super.key, required this.chatroomName, required this.chatroomId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

Color getColorFromID(String id) {
  List<Color> colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.indigo
  ];

  int hash = id.hashCode.abs(); // Chuyển ID thành số nguyên dương
  return colors[hash % colors.length]; // Chọn màu theo hash
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  TextEditingController messageText = TextEditingController();
  var db = FirebaseFirestore.instance;
  final double avatarSize = 40; // Kích thước avatar
  TextEditingController searchController = TextEditingController();
  List<QueryDocumentSnapshot> allMessages = [];
  List<QueryDocumentSnapshot> filteredMessages = [];
  bool isSearching = false;
  final ImagePicker _picker = ImagePicker();
  bool isAdmin = false; // Biến kiểm tra quyền admin
  User? user = FirebaseAuth.instance.currentUser; // Khai báo biến user
  List<Map<String, dynamic>> friendsList = [];
  List<String> selectedFriendIds = [];
  Map<String, Map<String, dynamic>> reactionIcons = {
    'heart': {'icon': Icons.favorite, 'color': Colors.redAccent},
    'haha': {
      'icon': Icons.sentiment_very_satisfied,
      'color': Colors.yellow.shade700
    },
    'sad': {'icon': Icons.sentiment_dissatisfied, 'color': Colors.blueAccent},
    'like': {'icon': Icons.thumb_up, 'color': Colors.greenAccent},
    'dislike': {'icon': Icons.thumb_down, 'color': Colors.orangeAccent},
  };

  // Thêm ScrollController
  ScrollController _scrollController = ScrollController();

  // Thêm biến cho ghi âm và phát âm
  //final AudioRecorder _recorder = AudioRecorder();
  AudioRecorder? _recorder; // Đổi thành nullable
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _audioPath; // Đường dẫn file âm thanh tạm thời

  // Thêm biến mới cho tín hiệu âm thanh
  double _currentAmplitude = 0.0; // Biên độ hiện tại
  StreamSubscription? _amplitudeSubscription; // Theo dõi biên độ

  @override
  void initState() {
    super.initState();
    checkAdminStatus();
    _fetchFriends();
    _recorder = AudioRecorder(); // Khởi tạo ban đầu
    // Cuộn xuống cuối khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _recorder?.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose(); // Giải phóng ScrollController
    messageText.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    if (await _requestMicrophonePermission()) {
      // Tạo mới AudioRecorder mỗi lần ghi âm
      _recorder?.dispose(); // Giải phóng instance cũ nếu có
      _recorder = AudioRecorder(); // Tạo instance mới

      final directory = await getTemporaryDirectory();
      _audioPath =
          '${directory.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder!.start(const RecordConfig(), path: _audioPath!);

      // Lắng nghe biên độ âm thanh
      _amplitudeSubscription = _recorder!
          .onAmplitudeChanged(Duration(milliseconds: 100))
          .listen((amplitude) {
        setState(() {
          _currentAmplitude = amplitude.current; // Cập nhật biên độ
        });
      });

      setState(() {
        _isRecording = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cần cấp quyền microphone để ghi âm")),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      await _recorder!.stop();
      _amplitudeSubscription?.cancel();
      setState(() {
        _isRecording = false;
        _currentAmplitude = 0.0;
      });
      if (_audioPath != null) {
        await _uploadAndSendVoiceMessage();
      }
    }
  }

  Future<void> _uploadAndSendVoiceMessage() async {
    if (_audioPath == null) {
      print("Lỗi: _audioPath là null");
      return;
    }

    try {
      print("Bắt đầu tải file âm thanh: $_audioPath");
      File audioFile = File(_audioPath!);
      String? audioUrl =
          await CloudinaryService.uploadFile(audioFile, isAudio: true);

      if (audioUrl != null) {
        print("Tải lên thành công, URL: $audioUrl");
        await sendMessage(audioUrl, isAudio: true);
      } else {
        print("Tải lên thất bại: audioUrl là null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể tải lên tin nhắn thoại")),
        );
      }

      // Xóa file tạm sau khi tải lên
      print("Xóa file tạm: $_audioPath");
      await audioFile.delete();
      _audioPath = null;
    } catch (e) {
      print("Lỗi trong _uploadAndSendVoiceMessage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi tải lên tin nhắn thoại: $e")),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchFriends() async {
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
    }
  }

  Future<void> addMembersToGroup() async {
    if (selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vui lòng chọn ít nhất một thành viên")),
      );
      return;
    }

    try {
      DocumentReference chatroomRef =
          db.collection("chatrooms").doc(widget.chatroomId);
      List<String> newMemberNames = selectedFriendIds
          .map((id) => friendsList
              .firstWhere((friend) => friend["id"] == id)["name"] as String)
          .toList();

      await db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(chatroomRef);
        if (!snapshot.exists) {
          throw Exception("Chatroom không tồn tại");
        }

        List<String> currentMembers =
            (snapshot.get("members") as List<dynamic>?)?.cast<String>() ?? [];
        List<String> currentMemberNames =
            (snapshot.get("memberNames") as List<dynamic>?)?.cast<String>() ??
                [];

        List<String> membersToAdd = selectedFriendIds
            .where((id) => !currentMembers.contains(id))
            .toList();
        List<String> namesToAdd = newMemberNames
            .where((name) => !currentMemberNames.contains(name))
            .toList();

        if (membersToAdd.isEmpty) {
          throw Exception("Tất cả bạn bè đã chọn đều đã ở trong nhóm");
        }

        transaction.update(chatroomRef, {
          "members": FieldValue.arrayUnion(membersToAdd),
          "memberNames": FieldValue.arrayUnion(namesToAdd),
        });
      });

      setState(() {
        selectedFriendIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã thêm thành viên vào nhóm")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi thêm thành viên: $e")),
      );
    }
  }

  void showAddMembersDialog() {
    setState(() {
      selectedFriendIds.clear();
    });

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
                "Thêm thành viên mới",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: friendsList.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : StreamBuilder(
                        stream: db
                            .collection("chatrooms")
                            .doc(widget.chatroomId)
                            .snapshots(),
                        builder: (context,
                            AsyncSnapshot<DocumentSnapshot> snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          var data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          List<String> currentMembers =
                              (data["members"] as List<dynamic>?)
                                      ?.cast<String>() ??
                                  [];

                          return StatefulBuilder(
                            builder: (BuildContext context,
                                StateSetter setDialogState) {
                              return ListView.builder(
                                itemCount: friendsList.length,
                                itemBuilder: (context, index) {
                                  var friend = friendsList[index];
                                  bool isAlreadyMember =
                                      currentMembers.contains(friend["id"]);
                                  return CheckboxListTile(
                                    title: Text(friend["name"]),
                                    value: selectedFriendIds
                                        .contains(friend["id"]),
                                    onChanged: isAlreadyMember
                                        ? null // Vô hiệu hóa nếu đã là thành viên
                                        : (bool? value) {
                                            setDialogState(() {
                                              if (value == true) {
                                                selectedFriendIds
                                                    .add(friend["id"]);
                                              } else {
                                                selectedFriendIds
                                                    .remove(friend["id"]);
                                              }
                                            });
                                          },
                                    subtitle: isAlreadyMember
                                        ? Text(
                                            "Đã có trong nhóm",
                                            style:
                                                TextStyle(color: Colors.grey),
                                          )
                                        : null,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Hủy"),
                  ),
                  TextButton(
                    onPressed: () {
                      addMembersToGroup();
                      Navigator.pop(context);
                    },
                    child: Text("Thêm", style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kiểm tra xem người dùng có phải là admin không
  Future<void> checkAdminStatus() async {
    var userProvider = Provider.of<UserProvider>(context, listen: false);
    var doc = await db.collection("chatrooms").doc(widget.chatroomId).get();
    if (doc.exists) {
      List<dynamic> admins = doc.data()?["admins"] ?? [];
      setState(() {
        isAdmin = admins.contains(userProvider.userID);
      });
    }
  }

  // Xóa thành viên khỏi nhóm
  Future<void> kickMember(String memberId) async {
    try {
      DocumentSnapshot chatroomDoc =
          await db.collection("chatrooms").doc(widget.chatroomId).get();
      List<dynamic> admins = chatroomDoc["admins"] ?? [];
      String memberName = await _getUserNameFromId(memberId) ?? "Unknown";

      // Không cho phép kick admin
      if (admins.contains(memberId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể xóa quản trị viên")),
        );
        return;
      }

      await db.collection("chatrooms").doc(widget.chatroomId).update({
        "members": FieldValue.arrayRemove([memberId]),
        "memberNames": FieldValue.arrayRemove([memberName]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã xóa $memberName khỏi nhóm")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi xóa thành viên: $e")),
      );
    }
  }

  // Trao quyền quản trị
  Future<void> promoteToAdmin(String memberId) async {
    try {
      var userProvider = Provider.of<UserProvider>(context, listen: false);
      DocumentReference chatroomRef =
          db.collection("chatrooms").doc(widget.chatroomId);

      // Thực hiện transaction để đảm bảo tính toàn vẹn dữ liệu
      await db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(chatroomRef);
        if (!snapshot.exists) {
          throw Exception("Chatroom không tồn tại");
        }

        List<dynamic> currentAdmins = snapshot.get("admins") ?? [];
        if (!currentAdmins.contains(userProvider.userID)) {
          throw Exception("Bạn không có quyền thực hiện hành động này");
        }

        // Cập nhật danh sách admin
        List<dynamic> newAdmins = List.from(currentAdmins)
          ..remove(userProvider.userID) // Xóa admin hiện tại
          ..add(memberId); // Thêm admin mới

        transaction.update(chatroomRef, {
          "admins": newAdmins,
        });
      });

      // Cập nhật trạng thái ngay lập tức mà không cần reload
      setState(() {
        isAdmin = false; // Người dùng hiện tại mất quyền admin
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã chuyển giao quyền quản trị")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi trao quyền: $e")),
      );
    }
  }

  // Rời nhóm
  Future<void> leaveGroup() async {
    var userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      DocumentReference chatroomRef =
          db.collection("chatrooms").doc(widget.chatroomId);

      await db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(chatroomRef);
        if (!snapshot.exists) {
          throw Exception("Chatroom không tồn tại");
        }

        List<dynamic> admins = snapshot.get("admins") ?? [];
        List<dynamic> members = snapshot.get("members") ?? [];
        List<dynamic> memberNames = snapshot.get("memberNames") ?? [];

        // Kiểm tra xem user có trong nhóm không
        if (!members.contains(userProvider.userID)) {
          throw Exception("Bạn không phải thành viên của nhóm này");
        }

        // Nếu là admin duy nhất, tự động trao quyền cho thành viên khác
        if (admins.length == 1 && admins.contains(userProvider.userID)) {
          if (members.length <= 1) {
            throw Exception("Không thể rời nhóm khi chỉ có một thành viên");
          }

          // Chọn thành viên đầu tiên không phải user hiện tại để làm admin mới
          String newAdminId =
              members.firstWhere((id) => id != userProvider.userID);

          // Cập nhật danh sách admin: xóa user hiện tại, thêm admin mới
          List<dynamic> newAdmins = List.from(admins)
            ..remove(userProvider.userID)
            ..add(newAdminId);

          transaction.update(chatroomRef, {
            "members": FieldValue.arrayRemove([userProvider.userID]),
            "memberNames": FieldValue.arrayRemove([userProvider.userName]),
            "admins": newAdmins, // Cập nhật danh sách admin mới
          });
        } else {
          // Trường hợp không phải admin duy nhất hoặc không phải admin
          transaction.update(chatroomRef, {
            "members": FieldValue.arrayRemove([userProvider.userID]),
            "memberNames": FieldValue.arrayRemove([userProvider.userName]),
            "admins": FieldValue.arrayRemove([userProvider.userID]),
          });
        }
      });

      // Nếu là admin, cập nhật trạng thái
      if (isAdmin) {
        setState(() {
          isAdmin = false;
        });
      }

      // Quay về Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã rời nhóm")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi rời nhóm: $e")),
      );
    }
  }

  // Hiển thị danh sách thành viên
  void showMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.8,
          child: StreamBuilder(
            stream:
                db.collection("chatrooms").doc(widget.chatroomId).snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (!snapshot.hasData)
                return Center(child: CircularProgressIndicator());
              var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              List<String> members =
                  (data["members"] as List<dynamic>?)?.cast<String>() ?? [];
              List<String> memberNames =
                  (data["memberNames"] as List<dynamic>?)?.cast<String>() ?? [];
              List<String> admins =
                  (data["admins"] as List<dynamic>?)?.cast<String>() ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Thành viên",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    height: 300, // Giữ chiều cao cố định
                    child: Scrollbar(
                      // Thêm Scrollbar
                      thumbVisibility:
                          true, // Hiển thị thanh cuộn ngay cả khi không cuộn
                      child: ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          String memberId = members[index];
                          String memberName = memberNames[index];
                          bool isMemberAdmin = admins.contains(memberId);
                          return ListTile(
                            title: Text(memberName),
                            subtitle: Text(
                                isMemberAdmin ? "Quản trị viên" : "Thành viên"),
                            trailing: isAdmin && memberId != user!.uid
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.person_remove,
                                            color: Colors.red),
                                        onPressed: () => kickMember(memberId),
                                      ),
                                      if (!isMemberAdmin)
                                        IconButton(
                                          icon: Icon(Icons.admin_panel_settings,
                                              color: Colors.blue),
                                          onPressed: () {
                                            promoteToAdmin(memberId);
                                            Navigator.pop(
                                                context); // Đóng dialog sau khi trao quyền
                                          },
                                        ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Đóng"),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Hiển thị menu cài đặt
  void showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.group),
              title: Text("Xem thành viên"),
              onTap: () {
                Navigator.pop(context);
                showMembersDialog();
              },
            ),
            ListTile(
              // Loại bỏ điều kiện isAdmin để mọi người đều thêm được
              leading: Icon(Icons.person_add),
              title: Text("Thêm thành viên"),
              onTap: () {
                Navigator.pop(context);
                showAddMembersDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red),
              title: Text("Rời nhóm", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                leaveGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    File imageFile = File(image.path);
    String? imageUrl = await CloudinaryService.uploadFile(imageFile);

    if (imageUrl != null) {
      sendMessage(imageUrl, isImage: true); // Gửi ảnh bằng URL thay vì Base64
    }
  }

  Future<void> pickAndSendVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video == null) return;

    File videoFile = File(video.path);
    String? videoUrl =
        await CloudinaryService.uploadFile(videoFile, isVideo: true);

    if (videoUrl != null) {
      sendMessage(videoUrl, isVideo: true);
    }
  }

  void filterMessages(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        isSearching = false;
        filteredMessages = List.from(allMessages);
      } else {
        isSearching = true;
        filteredMessages = allMessages.where((msg) {
          String senderName = msg["sender_name"].toString().toLowerCase();
          String messageText = msg["text"].toString().toLowerCase();
          return senderName.contains(keyword.toLowerCase()) ||
              messageText.contains(keyword.toLowerCase());
        }).toList();
      }
    });
  }

  void showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context), // Đóng khi bấm ra ngoài
          child: InteractiveViewer(
            panEnabled: true, // Cho phép di chuyển khi zoom
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 3,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showVideoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayerWidget(videoUrl: videoUrl),
          ),
        ),
      ),
    );
  }

  void deleteMessage(String messageId) async {
    try {
      await db.collection("messages").doc(messageId).delete();
    } catch (e) {
      print("Lỗi khi xóa tin nhắn: $e");
    }
  }

  void showDeleteDialog(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Xóa tin nhắn"),
        content: Text("Bạn có chắc chắn muốn xóa tin nhắn này?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Hủy"),
          ),
          TextButton(
            onPressed: () {
              deleteMessage(messageId);
              Navigator.pop(context);
            },
            child: Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Future<void> sendMessage(String content,
  //     {bool isImage = false, bool isVideo = false}) async {
  //   if (content.isEmpty) return;

  //   var userProvider = Provider.of<UserProvider>(context, listen: false);
  //   // Đảm bảo senderName luôn lấy từ Firestore nếu userProvider.userName rỗng
  //   String senderName = userProvider.userName.isNotEmpty
  //       ? userProvider.userName
  //       : (await _getUserNameFromId(userProvider.userID)) ??
  //           "Tên không xác định";

  //   Map<String, dynamic> messageToSend = {
  //     "text": (!isImage && !isVideo) ? content : "",
  //     "imageUrl": isImage ? content : null,
  //     "videoUrl": isVideo ? content : null,
  //     "sender_name": senderName,
  //     "sender_email": userProvider.userEmail,
  //     "sender_id": userProvider.userID,
  //     "chatroom_id": widget.chatroomId,
  //     "timestamp": FieldValue.serverTimestamp(),
  //     "isPinned": false,
  //   };

  //   await db.collection("messages").add(messageToSend);
  //   messageText.clear();
  // }
  // Future<void> sendMessage(String content,
  //     {bool isImage = false, bool isVideo = false}) async {
  //   if (content.isEmpty) return;

  //   var userProvider = Provider.of<UserProvider>(context, listen: false);
  //   String senderName = userProvider.userName.isNotEmpty
  //       ? userProvider.userName
  //       : (await _getUserNameFromId(userProvider.userID)) ??
  //           "Tên không xác định";

  //   Map<String, dynamic> messageToSend = {
  //     "text": (!isImage && !isVideo) ? content : "",
  //     "imageUrl": isImage ? content : null,
  //     "videoUrl": isVideo ? content : null,
  //     "sender_name": senderName,
  //     "sender_email": userProvider.userEmail,
  //     "sender_id": userProvider.userID,
  //     "chatroom_id": widget.chatroomId,
  //     "timestamp": FieldValue.serverTimestamp(),
  //     "isPinned": false,
  //     "reactions": {
  //       "heart": [],
  //       "haha": [],
  //       "sad": [],
  //       "like": [],
  //       "dislike": [],
  //     },
  //   };

  //   await db.collection("messages").add(messageToSend);
  //   messageText.clear();
  //   // Cuộn xuống tin nhắn vừa gửi
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _scrollToBottom();
  //   });
  // }
  Future<void> sendMessage(String content,
      {bool isImage = false,
      bool isVideo = false,
      bool isAudio = false}) async {
    if (content.isEmpty) return;

    var userProvider = Provider.of<UserProvider>(context, listen: false);
    String senderName = userProvider.userName.isNotEmpty
        ? userProvider.userName
        : (await _getUserNameFromId(userProvider.userID)) ??
            "Tên không xác định";

    Map<String, dynamic> messageToSend = {
      "text": (!isImage && !isVideo && !isAudio) ? content : "",
      "imageUrl": isImage ? content : null,
      "videoUrl": isVideo ? content : null,
      "audioUrl": isAudio ? content : null, // Thêm trường audioUrl
      "sender_name": senderName,
      "sender_email": userProvider.userEmail,
      "sender_id": userProvider.userID,
      "chatroom_id": widget.chatroomId,
      "timestamp": FieldValue.serverTimestamp(),
      "isPinned": false,
      "reactions": {
        "heart": [],
        "haha": [],
        "sad": [],
        "like": [],
        "dislike": [],
      },
    };

    await db.collection("messages").add(messageToSend);
    messageText.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void showReactionMenu(BuildContext context, String messageId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: reactionIcons.entries.map((entry) {
              return GestureDetector(
                onTap: () {
                  toggleReaction(messageId, entry.key);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (entry.value['color'] as Color).withOpacity(0.1),
                  ),
                  child: Icon(
                    entry.value['icon'],
                    size: 32,
                    color: entry.value['color'],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> toggleReaction(String messageId, String reactionType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bạn cần đăng nhập để thả reaction")),
      );
      return;
    }

    print("User ID hiện tại: ${currentUser.uid}");
    print("Message ID: $messageId");
    print("Reaction type: $reactionType");

    try {
      DocumentReference messageRef = db.collection("messages").doc(messageId);
      DocumentSnapshot snapshot = await messageRef.get();
      if (!snapshot.exists) {
        throw Exception("Tin nhắn không tồn tại");
      }

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      print("Dữ liệu tin nhắn hiện tại: $data");

      Map<String, dynamic> reactions =
          Map<String, dynamic>.from(data["reactions"] ?? {});
      for (var key in reactionIcons.keys) {
        reactions[key] ??= [];
      }

      List<dynamic> currentReactions =
          List<dynamic>.from(reactions[reactionType] ?? []);
      if (currentReactions.contains(currentUser.uid)) {
        currentReactions.remove(currentUser.uid);
        print("Xóa reaction $reactionType của ${currentUser.uid}");
      } else {
        currentReactions.add(currentUser.uid);
        print("Thêm reaction $reactionType cho ${currentUser.uid}");
        reactions.forEach((key, value) {
          if (key != reactionType) {
            (value as List).remove(currentUser.uid);
          }
        });
      }

      reactions[reactionType] = currentReactions;
      print("Dữ liệu reactions gửi đi: $reactions");
      await messageRef.update({"reactions": reactions});
      print("Reaction được cập nhật thành công");
    } catch (e) {
      print("Lỗi khi thêm reaction: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể thêm reaction: $e")),
      );
    }
  }

  void togglePinMessage(String messageId, bool isCurrentlyPinned) async {
    try {
      await db.collection("messages").doc(messageId).update({
        "isPinned": !isCurrentlyPinned, // Đảo ngược trạng thái ghim
      });
    } catch (e) {
      print("Lỗi khi ghim tin nhắn: $e");
    }
  }

  Widget buildChatBubble({
    required String senderName,
    required String senderEmail,
    required String senderText,
    required String senderID,
    required bool showAvatar,
    required bool isCurrentUser,
    required String messageId,
    String? imageUrl,
    String? videoUrl,
    String? audioUrl, // Thêm tham số audioUrl
  }) {
    Color avatarColor = getColorFromID(senderID);
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: !isCurrentUser ? () => showReactionMenu(context, messageId) : null,
      onLongPress:
          isCurrentUser ? () => showDeleteDialog(context, messageId) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderName.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: avatarSize + 8, bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: isCurrentUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!isCurrentUser && showAvatar)
                  GestureDetector(
                    onTap: () =>
                        showFriendRequestDialog(context, senderID, senderName),
                    child: CircleAvatar(
                      backgroundColor: avatarColor,
                      radius: avatarSize / 2,
                      child: Text(
                        senderEmail[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else if (!isCurrentUser)
                  SizedBox(width: avatarSize),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isCurrentUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? (isDarkMode
                                  ? Colors.blue.shade700
                                  : Colors.blue.shade300)
                              : (isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: imageUrl != null
                            ? GestureDetector(
                                onTap: () => showImageDialog(context, imageUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            // : videoUrl != null
                            //     ? GestureDetector(
                            //         onTap: () =>
                            //             showVideoDialog(context, videoUrl),
                            //         child: const Icon(Icons.play_circle_fill,
                            //             size: 50, color: Colors.white),
                            //       )
                            //     : Text(
                            //         senderText,
                            //         style: TextStyle(
                            //           color: isDarkMode
                            //               ? Colors.white
                            //               : Colors.black87,
                            //           fontSize: 16,
                            //         ),
                            //       ),
                            : videoUrl != null
                                ? GestureDetector(
                                    onTap: () =>
                                        showVideoDialog(context, videoUrl),
                                    child: const Icon(Icons.play_circle_fill,
                                        size: 50, color: Colors.white),
                                  )
                                : audioUrl != null
                                    ? GestureDetector(
                                        onTap: () => _playAudio(audioUrl),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow,
                                                color: Colors.white),
                                            SizedBox(width: 8),
                                            Text(
                                              "Tin nhắn thoại",
                                              style: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Text(
                                        senderText,
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: db
                            .collection("messages")
                            .doc(messageId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null)
                            return const SizedBox.shrink();
                          var data =
                              snapshot.data!.data() as Map<String, dynamic>? ??
                                  {};
                          Map<String, dynamic> reactions =
                              data["reactions"] ?? {};

                          if (reactions.isEmpty ||
                              reactions.values
                                  .every((value) => (value as List).isEmpty)) {
                            return const SizedBox.shrink();
                          }

                          List<MapEntry<String, dynamic>> nonEmptyReactions =
                              reactions.entries
                                  .where((entry) =>
                                      (entry.value as List).isNotEmpty)
                                  .toList();

                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: GestureDetector(
                              onTap: () => _showReactionDetails(context,
                                  reactions, messageId), // Truyền messageId
                              child: Wrap(
                                spacing: 6,
                                children: [
                                  ...nonEmptyReactions.take(2).map((entry) =>
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.grey.shade900
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              reactionIcons[entry.key]!['icon'],
                                              size: 14,
                                              color: reactionIcons[entry.key]![
                                                  'color'],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${(entry.value as List).length}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  if (nonEmptyReactions.length > 2)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.grey.shade900
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "...",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      print("Bắt đầu phát âm thanh từ URL: $audioUrl");
      await _audioPlayer.stop(); // Dừng phát trước nếu đang phát
      await _audioPlayer.setUrl(audioUrl);
      print("Đã đặt URL thành công");
      await _audioPlayer.play();
      print("Phát âm thanh hoàn tất");
    } catch (e) {
      print("Lỗi khi phát tin nhắn thoại: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi phát tin nhắn thoại: $e")),
      );
    }
  }

  void _showReactionDetails(
      BuildContext context, Map<String, dynamic> reactions, String messageId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Người thả reaction",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  child: Column(
                    children: reactions.entries
                        .where((entry) => (entry.value as List).isNotEmpty)
                        .map((entry) {
                      List<String> userIds =
                          (entry.value as List).cast<String>();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: userIds
                            .map((userId) => FutureBuilder<DocumentSnapshot>(
                                  future:
                                      db.collection("users").doc(userId).get(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData)
                                      return const SizedBox.shrink();
                                    var userData = snapshot.data!.data()
                                            as Map<String, dynamic>? ??
                                        {};
                                    String userName =
                                        userData["name"] ?? "Unknown";

                                    bool isCurrentUserReaction =
                                        userId == currentUser.uid;

                                    return ListTile(
                                      leading: GestureDetector(
                                        onTap: isCurrentUserReaction
                                            ? () {
                                                toggleReaction(
                                                    messageId,
                                                    entry
                                                        .key); // Sử dụng messageId được truyền vào
                                                Navigator.pop(context);
                                              }
                                            : null,
                                        child: Icon(
                                          reactionIcons[entry.key]!['icon'],
                                          color: reactionIcons[entry.key]![
                                              'color'],
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(userName),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 2),
                                    );
                                  },
                                ))
                            .toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text("Đóng", style: TextStyle(color: Colors.blue)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kiểm tra trạng thái bạn bè
  Future<bool> isFriend(String friendId) async {
    var userId = Provider.of<UserProvider>(context, listen: false).userID;
    try {
      var friendship = await db
          .collection("friends")
          .where("friendIds", arrayContains: userId)
          .get();
      return friendship.docs
          .any((doc) => (doc.data()["friendIds"] as List).contains(friendId));
    } catch (e) {
      print("Lỗi khi kiểm tra trạng thái bạn bè: $e");
      return false;
    }
  }

// Kiểm tra yêu cầu kết bạn đang chờ
  Future<bool> hasPendingRequest(String friendId) async {
    var userId = Provider.of<UserProvider>(context, listen: false).userID;
    try {
      var request = await db
          .collection("friendRequests")
          .where("senderId", isEqualTo: userId)
          .where("receiverId", isEqualTo: friendId)
          .where("status", isEqualTo: "pending")
          .limit(1)
          .get();
      return request.docs.isNotEmpty;
    } catch (e) {
      print("Lỗi khi kiểm tra yêu cầu kết bạn: $e");
      return false;
    }
  }

// Hiển thị dialog gửi yêu cầu kết bạn hoặc trạng thái đã kết bạn
  void showFriendRequestDialog(
      BuildContext context, String friendId, String friendName) async {
    var userProvider = Provider.of<UserProvider>(context, listen: false);
    String currentUserId = userProvider.userID;

    if (friendId == currentUserId) return; // Không kết bạn với chính mình

    // Lấy tên từ Firestore nếu friendName rỗng hoặc null
    String displayName = friendName.isNotEmpty
        ? friendName
        : (await _getUserNameFromId(friendId)) ?? "Tên không xác định";

    try {
      bool alreadyFriends = await isFriend(friendId);
      bool pendingRequest = await hasPendingRequest(friendId);

      if (!mounted) return; // Kiểm tra widget còn tồn tại

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Kết bạn"),
          content: Text(
            alreadyFriends
                ? "Bạn và $displayName đã là bạn bè."
                : pendingRequest
                    ? "Bạn đã gửi yêu cầu kết bạn tới $displayName rồi."
                    : "Bạn có muốn gửi lời mời kết bạn tới $displayName không?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Đóng"),
            ),
            if (!alreadyFriends && !pendingRequest)
              TextButton(
                onPressed: () async {
                  try {
                    await db.collection("friendRequests").add({
                      "senderId": currentUserId,
                      "senderName": userProvider.userName,
                      "receiverId": friendId,
                      "status": "pending",
                      "timestamp": FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text("Đã gửi lời mời kết bạn tới $displayName"),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.white,
                        ),
                      );
                    }
                  } catch (e) {
                    print("Lỗi khi gửi lời mời kết bạn: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Có lỗi xảy ra khi gửi lời mời"),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child:
                    Text("Gửi yêu cầu", style: TextStyle(color: Colors.blue)),
              ),
          ],
        ),
      );
    } catch (e) {
      print("Lỗi khi hiển thị dialog kết bạn: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã xảy ra lỗi: $e"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Hàm phụ để lấy tên người dùng từ Firestore dựa trên UID
  Future<String?> _getUserNameFromId(String userId) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()?["name"] as String?;
      }
      return null; // Trả về null nếu document không tồn tại
    } catch (e) {
      print("Lỗi khi lấy tên người dùng: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection("chatrooms").doc(widget.chatroomId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        var chatroomData = snapshot.data!.data() as Map<String, dynamic>;
        bool isGroup = chatroomData["isGroup"] ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.chatroomName),
            actions: [
              if (isGroup) // Chỉ hiển thị nút setting trong nhóm tự tạo (isGroup == true)
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: showSettingsMenu,
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: TextField(
                  controller: searchController,
                  onChanged: filterMessages,
                  decoration: InputDecoration(
                    hintText: "Search user or messages...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: db
                      .collection("messages")
                      .where("chatroom_id", isEqualTo: widget.chatroomId)
                      .orderBy("isPinned", descending: true)
                      .orderBy("timestamp", descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return Center(child: CircularProgressIndicator());

                    allMessages = snapshot.data!.docs;
                    if (!isSearching) filteredMessages = List.from(allMessages);

                    // Cuộn xuống cuối khi danh sách tin nhắn thay đổi
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    return ListView.builder(
                      controller:
                          _scrollController, // Gắn ScrollController vào ListView
                      itemCount: filteredMessages.length,
                      itemBuilder: (context, index) {
                        var messageData = filteredMessages[index].data()
                                as Map<String, dynamic>? ??
                            {};

                        if (messageData.isEmpty) return SizedBox.shrink();

                        String messageId = filteredMessages[index].id;
                        bool isCurrentUser = messageData["sender_id"] ==
                            Provider.of<UserProvider>(context, listen: false)
                                .userID;

                        bool showSenderName = !isCurrentUser &&
                            (index == 0 ||
                                (filteredMessages[index - 1].data()
                                            as Map<String, dynamic>? ??
                                        {})["sender_id"] !=
                                    messageData["sender_id"]);

                        bool showAvatar =
                            index == filteredMessages.length - 1 ||
                                (filteredMessages[index + 1].data()
                                            as Map<String, dynamic>? ??
                                        {})["sender_id"] !=
                                    messageData["sender_id"];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: buildChatBubble(
                            senderName: showSenderName
                                ? messageData["sender_name"] ?? ""
                                : "",
                            senderEmail: messageData["sender_email"] ?? "",
                            senderText: messageData["text"] ?? "",
                            senderID: messageData["sender_id"] ?? "",
                            showAvatar: showAvatar,
                            isCurrentUser: isCurrentUser,
                            messageId: messageId,
                            imageUrl: messageData["imageUrl"],
                            videoUrl: messageData["videoUrl"],
                            audioUrl: messageData["audioUrl"], // Thêm audioUrl
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Container(
              //   color: Theme.of(context).brightness == Brightness.dark
              //       ? Colors.black
              //       : Colors.white,
              //   padding: EdgeInsets.all(8),
              //   child: Row(
              //     children: [
              //       IconButton(
              //         icon: Icon(Icons.image),
              //         onPressed: pickAndSendImage,
              //       ),
              //       IconButton(
              //         icon: Icon(Icons.videocam),
              //         onPressed: pickAndSendVideo,
              //       ),
              //       IconButton(
              //         icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              //         onPressed:
              //             _isRecording ? _stopRecording : _startRecording,
              //       ),
              //       Expanded(
              //         child: TextField(
              //           controller: messageText,
              //           decoration: InputDecoration(
              //             hintText: "Nhập tin nhắn...",
              //             filled: true,
              //             fillColor:
              //                 Theme.of(context).brightness == Brightness.dark
              //                     ? Colors.grey[800]
              //                     : Colors.grey[200],
              //             border: OutlineInputBorder(
              //               borderRadius: BorderRadius.circular(20),
              //               borderSide: BorderSide.none,
              //             ),
              //           ),
              //         ),
              //       ),
              //       SizedBox(width: 8),
              //       IconButton(
              //         icon: Icon(Icons.send,
              //             color: Theme.of(context).brightness == Brightness.dark
              //                 ? Colors.blue[300]
              //                 : Colors.blue[700]),
              //         onPressed: () => sendMessage(messageText.text),
              //       ),
              //     ],
              //   ),
              // ),
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    if (_isRecording) // Hiển thị sóng âm thanh khi đang ghi
                      Container(
                        height: 30, // Giảm chiều cao từ 50 xuống 30
                        width: MediaQuery.of(context).size.width *
                            0.6, // Rộng 60% màn hình
                        margin: EdgeInsets.only(bottom: 8),
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          borderRadius:
                              BorderRadius.circular(15), // Bo góc mềm hơn
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomPaint(
                              size: Size(50, 20), // Kích thước nhỏ hơn cho sóng
                              painter: WaveformPainter(_currentAmplitude),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Đang ghi...",
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                                fontSize: 12, // Giảm kích thước chữ
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.image),
                          onPressed: pickAndSendImage,
                        ),
                        IconButton(
                          icon: Icon(Icons.videocam),
                          onPressed: pickAndSendVideo,
                        ),
                        IconButton(
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          onPressed:
                              _isRecording ? _stopRecording : _startRecording,
                        ),
                        Expanded(
                          child: TextField(
                            controller: messageText,
                            decoration: InputDecoration(
                              hintText: "Nhập tin nhắn...",
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.blue[300]
                                  : Colors.blue[700]),
                          onPressed: () => sendMessage(messageText.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double amplitude;

  WaveformPainter(this.amplitude);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    final double normalizedAmplitude =
        (amplitude.abs() / 60).clamp(0.0, 1.0); // Chuẩn hóa biên độ
    final int barCount = 10; // Số thanh sóng
    final double barWidth = size.width / (barCount * 2); // Chiều rộng mỗi thanh
    final double maxHeight = size.height; // Chiều cao tối đa

    for (int i = 0; i < barCount; i++) {
      // Tính chiều cao thanh dựa trên biên độ, tạo hiệu ứng ngẫu nhiên nhẹ
      double barHeight =
          maxHeight * normalizedAmplitude * (0.5 + (i % 2) * 0.5);
      double x = i * barWidth * 2; // Khoảng cách giữa các thanh

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            (size.height - barHeight) / 2, // Căn giữa theo chiều dọc
            barWidth,
            barHeight,
          ),
          Radius.circular(2), // Bo góc nhẹ cho thanh sóng
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Luôn vẽ lại khi biên độ thay đổi
  }
}
