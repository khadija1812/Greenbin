import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class CollectorPage extends StatefulWidget {
  final String filterStatus;

  CollectorPage({required this.filterStatus});

  @override
  _CollectorPageState createState() => _CollectorPageState();
}

class _CollectorPageState extends State<CollectorPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionStream;

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<bool> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled. Please enable them.')),
      );
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied. Using simulated location.')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location permissions permanently denied. Using simulated location. Enable in settings if needed.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async {
              await Geolocator.openAppSettings();
            },
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      print("Updating status for docId: $docId to $newStatus");
      Map<String, dynamic> updateData = {
        'status': newStatus,
      };

      if (newStatus == "In Progress") {
        bool permissionGranted = await _checkAndRequestLocationPermission();
        if (permissionGranted) {
          try {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            updateData['collector_latitude'] = position.latitude;
            updateData['collector_longitude'] = position.longitude;

            _positionStream = Geolocator.getPositionStream(
              locationSettings: LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 10,
              ),
            ).listen((Position position) {
              _firestore.collection('scheduled_collections').doc(docId).update({
                'collector_latitude': position.latitude,
                'collector_longitude': position.longitude,
              });
              print("Location updated: (${position.latitude}, ${position.longitude})");
            });
          } catch (e) {
            print("Error getting location: $e");
            updateData['collector_latitude'] = 37.7749;
            updateData['collector_longitude'] = -122.4194;
            print("Using simulated coordinates due to location error");
          }
        } else {
          updateData['collector_latitude'] = 37.7749;
          updateData['collector_longitude'] = -122.4194;
          print("Using simulated coordinates due to denied permission");
        }
      } else if (newStatus == "Completed") {
        _positionStream?.cancel();
        _positionStream = null;
      }

      await _firestore.collection('scheduled_collections').doc(docId).update(updateData);
      print("Status successfully updated to: $newStatus");
    } catch (e) {
      print("Error updating Firestore: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    if (widget.filterStatus == "Pending") {
      return _firestore
          .collection('scheduled_collections')
          .where('status', whereIn: ["Pending", "In Progress"]) // Show both statuses
          .snapshots();
    } else {
      return _firestore
          .collection('scheduled_collections')
          .where('status', isEqualTo: widget.filterStatus)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Collector Dashboard - ${widget.filterStatus} Orders"),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getFilteredStream(), // Use dynamic stream based on filterStatus
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          var orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return Center(child: Text("No ${widget.filterStatus} orders found."));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              var order = orders[index];
              return ListTile(
                title: Text("Order ID: ${order.id}"),
                subtitle: Text("Status: ${order['status']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order['status'] == "Pending")
                      ElevatedButton(
                        onPressed: () {
                          print("Start button pressed for ${order.id}");
                          _updateStatus(order.id, "In Progress");
                        },
                        child: Text("Start"),
                      ),
                    if (order['status'] == "In Progress")
                      ElevatedButton(
                        onPressed: () => _updateStatus(order.id, "Completed"),
                        child: Text("Complete"),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}