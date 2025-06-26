import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugFirestorePage extends StatefulWidget {
  @override
  _DebugFirestorePageState createState() => _DebugFirestorePageState();
}

class _DebugFirestorePageState extends State<DebugFirestorePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Debug Firestore - User Data"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, authSnapshot) {
          if (!authSnapshot.hasData) {
            return Center(child: Text("Please log in to view your data."));
          }

          final user = authSnapshot.data!;
          debugPrint("🔹 Logged-in user ID: ${user.uid}");

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('scheduled_collections')
                .where('user_id', isEqualTo: user.uid) // ✅ Filter by logged-in user
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              debugPrint("🔥 Firestore snapshot count: ${snapshot.data?.docs.length}");

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text("No data found for this user."));
              }

              var schedules = snapshot.data!.docs;

              return ListView.builder(
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  var scheduleData = schedules[index].data() as Map<String, dynamic>;

                  // Extract data safely
                  String wasteType = scheduleData['waste_type'] ?? "Unknown";
                  String quantity = scheduleData['quantity']?.toString() ?? "N/A";
                  String pickupDate = scheduleData['pickup_date'] ?? "N/A";
                  String pickupTime = scheduleData['pickup_time'] ?? "N/A";
                  String address = scheduleData['pickup_address'] ?? "N/A";

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.history, color: Colors.green, size: 40),
                      title: Text(
                        "Waste Type: $wasteType",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Quantity: $quantity kg"),
                          Text("Pickup Date: $pickupDate"),
                          Text("Pickup Time: $pickupTime"),
                          Text("Address: $address"),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
