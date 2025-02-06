import 'package:flutter/material.dart';

class ChatRoomScreen extends StatefulWidget {
  String chatroomName;
  String chatroomId;

  ChatRoomScreen(
      {super.key, required this.chatroomName, required this.chatroomId});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatroomName)),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.red,
            ),
          ),
          Expanded(
              child: Row(
            children: [Expanded(child: TextField()), Icon(Icons.send)],
          ))
        ],
      ),
    );
  }
}
