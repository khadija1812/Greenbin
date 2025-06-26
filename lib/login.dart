import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wastem/homefinal.dart'; // User Page
import 'package:wastem/collector.dart'; // Collector Page
import 'package:wastem/signup.dart';

import 'collectorhome.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Authenticate with Firebase Auth
      print('⏱️ Attempting to authenticate with email: ${_emailController.text.trim()}');
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user == null) {
        throw Exception("User not found");
      }

      print('✅ Authentication successful');
      print('📄 User UID: ${user.uid}');
      print('📧 User Email: ${user.email}');

      // DEBUGGING: Check specific collections that we know should exist
      print('🔍 Checking Firestore collections...');

      // Try 'user' collection
      print('🔍 Looking for document in user collection with ID: ${user.uid}');
      DocumentSnapshot userDoc = await _firestore.collection('user').doc(user.uid).get();
      print('🔍 Document exists in "user" collection: ${userDoc.exists}');
      if (userDoc.exists) {
        print('📄 Document data: ${userDoc.data()}');
      } else {
        print('❌ No document found with ID: ${user.uid} in "user" collection');
      }

      // Try 'users' collection as fallback (in case of naming inconsistency)
      print('🔍 Checking "users" collection as fallback...');
      DocumentSnapshot usersDoc = await _firestore.collection('users').doc(user.uid).get();
      print('🔍 Document exists in "users" collection: ${usersDoc.exists}');
      if (usersDoc.exists) {
        print('📄 Document data: ${usersDoc.data()}');
      }

      // Check in 'collectors' collection
      print('🔍 Checking "collectors" collection...');
      DocumentSnapshot collectorDoc = await _firestore.collection('collectors').doc(user.uid).get();
      print('🔍 Document exists in "collectors" collection: ${collectorDoc.exists}');
      if (collectorDoc.exists) {
        print('📄 Document data: ${collectorDoc.data()}');
      }

      // Now let's check the signup.dart code
      print('🔍 Debug signup code - Default collection name would be: ${user.uid.isEmpty ? 'N/A' : (_selectedRole == 'Collector' ? 'collectors' : 'user')}');

      // Use data from whichever collection it exists in
      if (userDoc.exists) {
        print('✅ Document found in "user" collection - navigating to HomeOptionsPage');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeOptionsPage(userData: userDoc.data() as Map<String, dynamic>),
          ),
        );
        return;
      } else if (usersDoc.exists) {
        print('✅ Document found in "users" collection - navigating to HomeOptionsPage');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeOptionsPage(userData: usersDoc.data() as Map<String, dynamic>),
          ),
        );
        return;
      } else if (collectorDoc.exists) {
        print('✅ Document found in "collectors" collection - navigating to CollectorPage');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CollectorHomePage()),
        );
        return;
      }

      // If we get here, no document was found in any collection
      print('❌ No user data found in any collection');
      await _auth.signOut();
      throw Exception("Account authenticated but not found in database");
    } catch (e) {
      print('❌ Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Define a dummy variable to mimic signup.dart's variable for debugging
  String _selectedRole = 'User';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login'), backgroundColor: Colors.green),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            SizedBox(height: 24),

            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Login',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SignupPage()),
                );
              },
              child: Text('Don\'t have an account? Signup'),
            ),
          ],
        ),
      ),
    );
  }
}