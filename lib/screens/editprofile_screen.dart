import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:globalchat/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  var db = FirebaseFirestore.instance;
  TextEditingController nameText = TextEditingController();
  TextEditingController phoneText = TextEditingController();
  TextEditingController addressText = TextEditingController();
  String birthDate = "";

  var editProfileForm = GlobalKey<FormState>();

  @override
  void initState() {
    var userProvider = Provider.of<UserProvider>(context, listen: false);
    nameText.text = userProvider.userName;
    phoneText.text = userProvider.phoneNumber ?? "";
    addressText.text = userProvider.address ?? "";
    birthDate = userProvider.birthDate ?? "";
    super.initState();
  }

  void updateData() {
    if (editProfileForm.currentState!.validate()) {
      var userProvider = Provider.of<UserProvider>(context, listen: false);

      Map<String, dynamic> updatedData = {};
      if (nameText.text != userProvider.userName) {
        updatedData["name"] = nameText.text;
      }
      if (phoneText.text.isNotEmpty &&
          phoneText.text != userProvider.phoneNumber) {
        updatedData["phone"] = phoneText.text;
      }
      if (addressText.text.isNotEmpty &&
          addressText.text != userProvider.address) {
        updatedData["address"] = addressText.text;
      }
      if (birthDate.isNotEmpty && birthDate != userProvider.birthDate) {
        updatedData["birthDate"] = birthDate;
      }

      if (updatedData.isNotEmpty) {
        db.collection("users").doc(userProvider.userID).update(updatedData);
        userProvider.getUserDetails();
      }

      Navigator.pop(context);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        birthDate = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chỉnh sửa thông tin",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Colors.blueAccent, size: 28),
            onPressed: updateData,
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: editProfileForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Họ và Tên"),
              _buildTextField(nameText, "Nhập họ và tên"),
              SizedBox(height: 20),
              _buildLabel("Số Điện Thoại"),
              _buildTextField(phoneText, "Nhập số điện thoại"),
              SizedBox(height: 20),
              _buildLabel("Địa Chỉ"),
              _buildTextField(addressText, "Nhập địa chỉ"),
              SizedBox(height: 20),
              _buildLabel("Ngày Sinh"),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: birthDate.isEmpty ? "Chọn Ngày Sinh" : null,
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blueAccent)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2)),
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(text: birthDate),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: updateData,
                  child: Text("Lưu thông tin",
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: controller,
      decoration: InputDecoration(
        hintText: controller.text.isEmpty ? hint : null,
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2)),
        border: OutlineInputBorder(),
      ),
    );
  }
}
