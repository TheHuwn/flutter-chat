import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> sendMessage(String content,
      {bool isImage = false, bool isVideo = false}) async {
    if (content.isEmpty) return;

    var userProvider = Provider.of<UserProvider>(context, listen: false);
    Map<String, dynamic> messageToSend = {
      "text": (!isImage && !isVideo) ? content : "",
      "imageUrl": isImage ? content : null,
      "videoUrl": isVideo ? content : null,
      "sender_name": userProvider.userName,
      "sender_email": userProvider.userEmail,
      "sender_id": userProvider.userID,
      "chatroom_id": widget.chatroomId,
      "timestamp": FieldValue.serverTimestamp(),
      "isPinned": false, // Thêm trạng thái ghim
    };

    await db.collection("messages").add(messageToSend);
    messageText.clear();
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
    required String messageId, // Thêm ID tin nhắn để xóa
    String? imageUrl,
    String? videoUrl,
  }) {
    Color avatarColor = getColorFromID(senderID);
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: isCurrentUser
          ? () => showDeleteDialog(context,
              messageId) // Chỉ hiển thị nếu là tin nhắn của user hiện tại
          : null,
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: avatarSize + 8, bottom: 2),
              child: Text(
                //lưu ý
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isCurrentUser && showAvatar)
                CircleAvatar(
                  backgroundColor: avatarColor,
                  radius: avatarSize / 2,
                  child: Text(
                    senderEmail[0].toUpperCase(),
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              else if (!isCurrentUser)
                SizedBox(width: avatarSize),
              SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin: EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? (isDarkMode ? Colors.blue[700] : Colors.blue[300])
                        : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(20),
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
                      : videoUrl != null
                          ? GestureDetector(
                              onTap: () => showVideoDialog(context, videoUrl),
                              child: Icon(Icons.play_circle_fill, size: 50),
                            )
                          : Text(
                              senderText,
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                            ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // Widget buildChatBubble({
  //   required String senderName,
  //   required String senderEmail,
  //   required String senderText,
  //   required String senderID,
  //   required bool showAvatar,
  //   required bool isCurrentUser,
  //   required String messageId,
  //   required bool isPinned, // Thêm trạng thái ghim
  //   String? imageUrl,
  //   String? videoUrl,
  // }) {
  //   Color avatarColor = getColorFromID(senderID);
  //   bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

  //   return GestureDetector(
  //     onLongPress: () {
  //       showModalBottomSheet(
  //         context: context,
  //         builder: (context) => Wrap(
  //           children: [
  //             ListTile(
  //               leading:
  //                   Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
  //               title: Text(isPinned ? "Bỏ ghim" : "Ghim"),
  //               onTap: () {
  //                 togglePinMessage(messageId, isPinned);
  //                 Navigator.pop(context);
  //               },
  //             ),
  //             if (isCurrentUser) // Chỉ hiển thị nút xóa nếu là user gửi tin
  //               ListTile(
  //                 leading: Icon(Icons.delete, color: Colors.red),
  //                 title: Text("Xóa tin nhắn"),
  //                 onTap: () {
  //                   deleteMessage(messageId);
  //                   Navigator.pop(context);
  //                 },
  //               ),
  //           ],
  //         ),
  //       );
  //     },
  //     child: Column(
  //       crossAxisAlignment:
  //           isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
  //       children: [
  //         if (isPinned) // Hiển thị biểu tượng ghim nếu tin nhắn đã ghim
  //           Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Icon(Icons.push_pin, size: 14, color: Colors.orange),
  //               SizedBox(width: 4),
  //               Text(
  //                 "Đã ghim",
  //                 style: TextStyle(fontSize: 12, color: Colors.orange),
  //               ),
  //             ],
  //           ),
  //
  //         Row(
  //           crossAxisAlignment: CrossAxisAlignment.end,
  //           mainAxisAlignment:
  //               isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
  //           children: [
  //             if (!isCurrentUser && showAvatar)
  //               CircleAvatar(
  //                 backgroundColor: avatarColor,
  //                 radius: 20,
  //                 child: Text(
  //                   senderEmail[0].toUpperCase(),
  //                   style: TextStyle(
  //                       color: Colors.white, fontWeight: FontWeight.bold),
  //                 ),
  //               )
  //             else if (!isCurrentUser)
  //               SizedBox(width: 40),
  //             SizedBox(width: 8),
  //             Flexible(
  //               child: Container(
  //                 padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
  //                 margin: EdgeInsets.symmetric(vertical: 2),
  //                 decoration: BoxDecoration(
  //                   color: isCurrentUser
  //                       ? (isDarkMode ? Colors.blue[700] : Colors.blue[300])
  //                       : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
  //                   borderRadius: BorderRadius.circular(20),
  //                 ),
  //                 child: imageUrl != null
  //                     ? GestureDetector(
  //                         onTap: () => showImageDialog(context, imageUrl),
  //                         child: ClipRRect(
  //                           borderRadius: BorderRadius.circular(10),
  //                           child: Image.network(
  //                             imageUrl,
  //                             width: 100,
  //                             height: 100,
  //                             fit: BoxFit.cover,
  //                           ),
  //                         ),
  //                       )
  //                     : videoUrl != null
  //                         ? GestureDetector(
  //                             onTap: () => showVideoDialog(context, videoUrl),
  //                             child: Icon(Icons.play_circle_fill, size: 50),
  //                           )
  //                         : Text(
  //                             senderText,
  //                             style: TextStyle(
  //                                 color:
  //                                     isDarkMode ? Colors.white : Colors.black),
  //                           ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatroomName)),
      body: Column(
        children: [
          // Ô tìm kiếm
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
          // Hiển thị danh sách tin nhắn
          Expanded(
            child: StreamBuilder(
              stream: db
                  .collection("messages")
                  .where("chatroom_id", isEqualTo: widget.chatroomId)
                  .orderBy("isPinned",
                      descending: true) // Hiển thị tin nhắn ghim lên trước
                  .orderBy("timestamp", descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                allMessages = snapshot.data!.docs;
                if (!isSearching) filteredMessages = List.from(allMessages);

                return ListView.builder(
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    var messageData = filteredMessages[index].data()
                            as Map<String, dynamic>? ??
                        {};

                    if (messageData.isEmpty) return SizedBox.shrink();

                    String messageId =
                        filteredMessages[index].id; // Lấy ID tin nhắn
                    bool isCurrentUser = messageData["sender_id"] ==
                        Provider.of<UserProvider>(context, listen: false)
                            .userID;

                    bool showSenderName = !isCurrentUser &&
                        (index == 0 ||
                            (filteredMessages[index - 1].data()
                                        as Map<String, dynamic>? ??
                                    {})["sender_id"] !=
                                messageData["sender_id"]);

                    bool showAvatar = index == filteredMessages.length - 1 ||
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
                        messageId: messageId, // Truyền ID tin nhắn vào
                        imageUrl: messageData["imageUrl"],
                        videoUrl: messageData["videoUrl"],
                        // isPinned: messageData["isPinned"] ??
                        //     false, // Thêm tham số này
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Thanh nhập tin nhắn & nút gửi ảnh/video
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: pickAndSendImage, // Chọn ảnh từ thư viện
                ),
                IconButton(
                  icon: Icon(Icons.videocam),
                  onPressed: pickAndSendVideo, // Chọn video từ thư viện
                ),
                Expanded(
                  child: TextField(
                    controller: messageText,
                    decoration: InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue[300]
                          : Colors.blue[700]),
                  onPressed: () => sendMessage(messageText.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
