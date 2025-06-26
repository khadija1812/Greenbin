import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wastem/mappopup.dart';
import 'package:geocoding/geocoding.dart';

class SellWastePage extends StatefulWidget {
  @override
  _SellWastePageState createState() => _SellWastePageState();
}

class _SellWastePageState extends State<SellWastePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? wasteType;
  String? quantity;
  String? pickupAddress;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? assignedCollectorId;
  bool _isLoading = false;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _assignCollector();
  }

  Future<void> _assignCollector() async {
    try {
      QuerySnapshot collectorSnapshot =
      await _firestore.collection('collectors').limit(1).get();
      if (collectorSnapshot.docs.isNotEmpty) {
        setState(() {
          assignedCollectorId = collectorSnapshot.docs.first.id;
        });
      }
    } catch (e) {
      print("Error assigning collector: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) setState(() => selectedDate = pickedDate);
  }

  Future<void> _selectTime(BuildContext context) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) setState(() => selectedTime = pickedTime);
  }

  Future<void> _showMapPopup() async {
    try {
      final LatLng? selectedLocation = await showDialog<LatLng>(
        context: context,
        builder: (context) => MapPopup(
          onLocationSelected: (location) {
            Navigator.pop(context, location);
          },
        ),
      );

      if (selectedLocation != null) {
        _selectedLocation = selectedLocation;
        String address = await _getAddressFromLatLng(selectedLocation);
        setState(() {
          pickupAddress = address;
        });
      }
    } catch (e) {
      print("Error in map popup: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening map: $e")));
    }
  }

  Future<String> _getAddressFromLatLng(LatLng location) async {
    try {
      print("Geocoding coordinates: ${location.latitude}, ${location.longitude}");
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      print("Placemarks retrieved: ${placemarks.length}");
      if (placemarks.isEmpty) {
        return "No address found for this location";
      }
      Placemark place = placemarks.first;
      String address = "${place.street ?? ''}, ${place.locality ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}";
      print("Address: $address");
      return address.isEmpty ? "Address not found" : address;
    } catch (e) {
      print("Geocoding error: $e");
      return "Unable to fetch address: $e";
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location services are disabled")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Location permissions are denied")));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Location permissions are permanently denied")));
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    _selectedLocation = LatLng(position.latitude, position.longitude);
    String address = await _getAddressFromLatLng(_selectedLocation!);
    setState(() {
      pickupAddress = address;
    });
  }

  Future<void> _schedulePickup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("User not logged in")));
      setState(() => _isLoading = false);
      return;
    }
    try {
      await _firestore.collection('scheduled_collections').add({
        'user_id': user.uid,
        'waste_type': wasteType,
        'quantity': int.parse(quantity!),
        'pickup_address': pickupAddress,
        'pickup_date': "${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}",
        'pickup_time': "${selectedTime!.hour}:${selectedTime!.minute}",
        'collector_id': assignedCollectorId,
        'status': "Pending",
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Pickup scheduled successfully")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error scheduling pickup: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Schedule Waste Pickup", style: GoogleFonts.poppins()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 12,
              shadowColor: Colors.black54,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: wasteType,
                        items: ["Organic", "Plastic", "Metal", "Paper", "Bio-Medical"]
                            .map((type) {
                          return DropdownMenuItem(
                              value: type, child: Text(type, style: GoogleFonts.poppins()));
                        }).toList(),
                        onChanged: (value) => setState(() => wasteType = value),
                        decoration: InputDecoration(labelText: "Waste Type"),
                        validator: (value) => value == null ? "Select waste type" : null,
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        decoration: InputDecoration(labelText: "Quantity (kg)"),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => quantity = value,
                        validator: (value) => value == null || value.isEmpty ? "Enter quantity" : null,
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: "Pickup Address",
                          suffixIcon: IconButton(
                            icon: Icon(Icons.map),
                            onPressed: _showMapPopup,
                          ),
                        ),
                        onChanged: (value) => pickupAddress = value,
                        validator: (value) => value == null || value.isEmpty ? "Enter address" : null,
                        controller: TextEditingController(text: pickupAddress),
                        readOnly: true,
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: Text("Get Current Location", style: GoogleFonts.poppins()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32),
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildDateTimePicker(),
                      SizedBox(height: 20),
                      _isLoading
                          ? CircularProgressIndicator()
                          : ElevatedButton(
                        onPressed: _schedulePickup,
                        child: Text("Schedule Pickup", style: GoogleFonts.poppins(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2E7D32),
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      children: [
        _buildPickerRow("Pickup Date", selectedDate?.toString() ?? "Select Date", Icons.calendar_today, _selectDate),
        _buildPickerRow("Pickup Time", selectedTime?.format(context) ?? "Select Time", Icons.access_time, _selectTime),
      ],
    );
  }

  Widget _buildPickerRow(String label, String value, IconData icon, Function(BuildContext) onTap) {
    return Row(
      children: [
        Expanded(child: Text(value, style: GoogleFonts.poppins())),
        IconButton(icon: Icon(icon, color: Color(0xFF2E7D32)), onPressed: () => onTap(context)),
      ],
    );
  }
}