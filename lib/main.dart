import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/sign_in_page.dart';
import 'pages/staff_home_page.dart';
import 'pages/admin_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Attendance App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text("Something went wrong")),
            );
          } else if (snapshot.hasData) {
            // User is signed in
            final email = snapshot.data!.email ?? '';
            if (email == 'admin@example.com') {
              return const AdminHomePage();
            } else {
              return const StaffHomePage();
            }
          } else {
            // User is not signed in
            return const SignInPage();
          }
        },
      ),
    );
  }
}
