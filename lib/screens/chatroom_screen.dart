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
      "sender_id": Provider.of<UserProvider>(context, listen: false).userID,
      "chatroom_id": widget.chatroomId,
      "timestamp": FieldValue.serverTimestamp()
    };
    messageText.text = " ";
    try {
      await db.collection("messages").add(messageToSend);
    } catch (e) {}
  }

  Widget singleChatItem(
      {required String senderName,
      required String senderText,
      required String senderID}) {
    return Column(
      crossAxisAlignment:
          senderID == Provider.of<UserProvider>(context, listen: false).userID
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6.0, right: 6),
          child:
              Text(senderName, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Container(
            decoration: BoxDecoration(
                color: senderID ==
                        Provider.of<UserProvider>(context, listen: false).userID
                    ? Colors.grey[300]
                    : Colors.blueGrey[900],
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(senderText,
                  style: TextStyle(
                      color: senderID ==
                              Provider.of<UserProvider>(context, listen: false)
                                  .userID
                          ? Colors.black
                          : Colors.white)),
            )),
        SizedBox(
          height: 8,
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatroomName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
                stream: db
                    .collection("messages")
                    .where("chatroom_id", isEqualTo: widget.chatroomId)
                    .orderBy("timestamp", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print(snapshot.error);
                  }
                  var allMessages = snapshot.data?.docs ?? [];
                  if (allMessages.isEmpty) {
                    return Center(child: Text("No messages yet"));
                  }
                  return ListView.builder(
                      reverse: true,
                      itemCount: allMessages.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: singleChatItem(
                              senderName: allMessages[index]["sender_name"],
                              senderText: allMessages[index]["text"],
                              senderID: allMessages[index]["sender_id"]),
                        );
                      });
                }),
          ),
          Container(
            color: Colors.grey[200],
            child: Expanded(
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
            ),
          )
        ],
      ),
    );
  }
}
