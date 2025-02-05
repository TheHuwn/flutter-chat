import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/controllers/signup_controller.dart';
import 'package:globalchat/screens/dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
  Widget build(BuildContext context) {
    var userForm = GlobalKey<FormState>();

    TextEditingController email = TextEditingController();
    TextEditingController password = TextEditingController();

    print("Account Created Successfully");

    return Scaffold(
      appBar: AppBar(
        title: Text("Sign up Screen"),
      ),
      body: Form(
        key: userForm,
        child: Column(
          children: [
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: email,
              decoration: InputDecoration(label: Text("Email")),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Email is required";
                }
              },
            ),
            SizedBox(
              height: 20,
            ),
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: password,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(label: Text("Password")),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Password is required";
                }
              },
            ),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
                onPressed: () {
                  SignupController.createAccount(
                      email: email.text,
                      password: password.text,
                      context: context);
                },
                child: Text("Create Account"))
          ],
        ),
      ),
    );
  }
}
