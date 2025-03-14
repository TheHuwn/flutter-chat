// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:globalchat/controllers/signup_controller.dart';
// import 'package:globalchat/screens/dashboard_screen.dart';

// class SignupScreen extends StatefulWidget {
//   const SignupScreen({super.key});

//   @override
//   State<SignupScreen> createState() => _SignupScreenState();
// }

// class _SignupScreenState extends State<SignupScreen> {
//   @override
//   Widget build(BuildContext context) {
//     var userForm = GlobalKey<FormState>();

//     TextEditingController email = TextEditingController();
//     TextEditingController password = TextEditingController();
//     TextEditingController name = TextEditingController();
//     TextEditingController country = TextEditingController();

//     print("Account Created Successfully");

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//             ""), // Keep this for back button, else can still swipe with no arrow
//       ),
//       body: Form(
//         key: userForm,
//         child: Column(
//           children: [
//             Image.asset("assets/images/reddit.png"),
//             TextFormField(
//               autovalidateMode: AutovalidateMode.onUserInteraction,
//               controller: email,
//               decoration: InputDecoration(label: Text("Email")),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return "Email is required";
//                 }
//               },
//             ),
//             SizedBox(
//               height: 20,
//             ),
//             TextFormField(
//               autovalidateMode: AutovalidateMode.onUserInteraction,
//               controller: password,
//               obscureText: true,
//               enableSuggestions: false,
//               autocorrect: false,
//               decoration: InputDecoration(label: Text("Password")),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return "Password is required";
//                 }
//               },
//             ),
//             SizedBox(
//               height: 20,
//             ),
//             TextFormField(
//               autovalidateMode: AutovalidateMode.onUserInteraction,
//               controller: name,
//               enableSuggestions: false,
//               autocorrect: false,
//               decoration: InputDecoration(label: Text("Name")),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return "Name is required";
//                 }
//               },
//             ),
//             SizedBox(
//               height: 20,
//             ),
//             TextFormField(
//               autovalidateMode: AutovalidateMode.onUserInteraction,
//               controller: country,
//               enableSuggestions: false,
//               autocorrect: false,
//               decoration: InputDecoration(label: Text("Country")),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return "Country is required";
//                 }
//               },
//             ),
//             SizedBox(
//               height: 50,
//             ),
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                           minimumSize: Size(0, 50),
//                           foregroundColor: Colors.white,
//                           backgroundColor: Colors.redAccent),
//                       onPressed: () {
//                         SignupController.createAccount(
//                             email: email.text,
//                             password: password.text,
//                             name: name.text,
//                             country: country.text,
//                             context: context);
//                       },
//                       child: Text("Create Account")),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:globalchat/controllers/login_controller.dart';
import 'package:globalchat/controllers/signup_controller.dart';
import 'package:globalchat/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userForm = GlobalKey<FormState>();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: userForm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage("assets/images/reddit.png"),
                    radius: 50,
                  ),
                  SizedBox(height: 30),
                  _buildTextField(email, "Email", Icons.email),
                  SizedBox(height: 25),
                  _buildTextField(password, "Password", Icons.lock,
                      obscureText: true),
                  SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        padding: EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.blueAccent,
                        elevation: 5,
                      ),
                      onPressed: () async {
                        if (userForm.currentState!.validate()) {
                          await LoginController.createAccount(
                            email: email.text,
                            password: password.text,
                            context: context,
                          );
                        }
                      },
                      child: Text(
                        "Login",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 25),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupScreen()),
                    ),
                    child: Text(
                      "Don't have an account? Sign up here",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(fontSize: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 30),
        labelText: label,
        labelStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 25),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? "$label is required" : null,
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final userForm = GlobalKey<FormState>();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController country = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: userForm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage("assets/images/logo.png"),
                    radius: 50,
                  ),
                  SizedBox(height: 60),
                  _buildTextField(email, "Email", Icons.email),
                  SizedBox(height: 25),
                  _buildTextField(password, "Password", Icons.lock,
                      obscureText: true),
                  SizedBox(height: 25),
                  _buildTextField(name, "Name", Icons.person),
                  SizedBox(height: 25),
                  _buildTextField(country, "Country", Icons.public),
                  SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        padding: EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.blueAccent,
                        elevation: 5,
                      ),
                      onPressed: () {
                        if (userForm.currentState!.validate()) {
                          SignupController.createAccount(
                            email: email.text,
                            password: password.text,
                            name: name.text,
                            country: country.text,
                            context: context,
                          );
                        }
                      },
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(fontSize: 20),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 30),
        labelText: label,
        labelStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 25),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? "$label is required" : null,
    );
  }
}
