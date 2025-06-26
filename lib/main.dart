import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:wastem/firebase_options.dart';
import 'package:wastem/homefinal.dart';
import 'package:wastem/signup.dart';
import 'package:wastem/collector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgroWaste',
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          User? user = snapshot.data;
          if (user == null) {
            return SignupPage();
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('user').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                print("🔹 User data retrieved: $userData");
                return HomeOptionsPage(userData: userData);
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('collectors').doc(user.uid).get(),
                builder: (context, collectorSnapshot) {
                  if (collectorSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (collectorSnapshot.hasData &&
                      collectorSnapshot.data != null &&
                      collectorSnapshot.data!.exists) {
                    var collectorData = collectorSnapshot.data!.data() as Map<String, dynamic>;
                    print("🔹 Collector data retrieved: $collectorData");
                    return CollectorPage(filterStatus: "Pending"); // Default to "Pending" orders
                  }

                  return Scaffold(
                    body: Center(
                      child: Text('Error fetching data. Please try again.'),
                    ),
                  );
                },
              );
            },
          );
        }

        return SignupPage();
      },
    );
  }
}