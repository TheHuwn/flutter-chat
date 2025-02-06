import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:provider/provider.dart';

class ChatRoomScreen extends StatefulWidget {
  String chatroomName;
  String chatroomId;

  ChatRoomScreen(
      {super.key, required this.chatroomName, required this.chatroomId});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  TextEditingController messageText = TextEditingController();

  var db = FirebaseFirestore.instance;

  Future<void> sendMessage() async {
    if (messageText.text.isEmpty) {
      return;
    }
    Map<String, dynamic> messageToSend = {
      "text": messageText.text,
      "sender_name": Provider.of<UserProvider>(context, listen: false).userName,
      "chatroom_id": widget.chatroomId,
      "timestamp": FieldValue.serverTimestamp()
    };
    try {
      await db.collection("messages").add(messageToSend);
      messageText.text = " ";
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatroomName)),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
            ),
          ),
          Container(
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: TextField(
                    controller: messageText,
                    decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter Message Here ... "),
                  ),
                )),
                InkWell(onTap: sendMessage, child: Icon(Icons.send))
              ],
            ),
          )
        ],
      ),
    );
  }
}
