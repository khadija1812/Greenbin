import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  final String orderId;

  MapPage({required this.orderId});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  LatLng? _collectorLocation;
  LatLng? _userLocation;
  Set<Polyline> _polylines = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _errorMessage;
  bool _isLoading = true;

  // Move the API key to a secure location in production
  static const String _googleApiKey = 'AIzaSyBi64Rv17l9KsYs0civEAQooLfhdFdiCxE';

  @override
  void initState() {
    super.initState();
    print("MapPage initialized with orderId: ${widget.orderId}");
    _listenToCollectorLocation();
  }

  void _listenToCollectorLocation() {
    print("Listening to Firestore for orderId: ${widget.orderId}");
    _firestore
        .collection('scheduled_collections')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        print("Snapshot data received: $data");

        // Debug all fields
        data.forEach((key, value) => print("Field: $key, Value: $value"));

        // Set user location first
        double? userLat = data['latitude']?.toDouble();
        double? userLng = data['longitude']?.toDouble();

        if (userLat != null && userLng != null) {
          setState(() {
            _userLocation = LatLng(userLat, userLng);
            print("User location set: ($_userLocation)");
          });
        } else {
          print("User location missing: lat=$userLat, lng=$userLng");
          setState(() {
            _errorMessage = "User location not available.";
            _isLoading = false;
          });
          return;
        }

        // Try to get collector location
        if (data.containsKey('collector_id')) {
          // Fetch collector location from collectors collection
          String collectorId = data['collector_id'];
          _firestore.collection('collectors').doc(collectorId).get().then((collectorDoc) {
            if (collectorDoc.exists) {
              var collectorData = collectorDoc.data() as Map<String, dynamic>;
              double? collectorLat = data['collector_latitude']?.toDouble();
              double? collectorLng = data['collector_longitude']?.toDouble();

              if (collectorLat != null && collectorLng != null) {
                setState(() {
                  _collectorLocation = LatLng(collectorLat, collectorLng);
                  print("Collector location set directly: ($_collectorLocation)");
                  _isLoading = false;
                });

                // Now that we have both locations, fetch the route
                _fetchAndDrawRoute();
              } else {
                setState(() {
                  _errorMessage = "Collector location data incomplete.";
                  _isLoading = false;
                });
              }
            } else {
              setState(() {
                _errorMessage = "Collector not found.";
                _isLoading = false;
              });
            }
          }).catchError((error) {
            setState(() {
              _errorMessage = "Error fetching collector: $error";
              _isLoading = false;
            });
          });
        } else {
          // Try direct collector location fields
          double? collectorLat = data['collector_latitude']?.toDouble();
          double? collectorLng = data['collector_longitude']?.toDouble();

          if (collectorLat != null && collectorLng != null) {
            setState(() {
              _collectorLocation = LatLng(collectorLat, collectorLng);
              print("Collector location set directly: ($_collectorLocation)");
              _isLoading = false;
            });

            // Now that we have both locations, fetch the route
            _fetchAndDrawRoute();
          } else {
            setState(() {
              _errorMessage = "Collector location not available.";
              _isLoading = false;
            });
          }
        }
      } else {
        print("Document does not exist for orderId: ${widget.orderId}");
        setState(() {
          _errorMessage = "Order not found.";
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print("Error fetching location: $error");
      setState(() {
        _errorMessage = "Error loading location: $error";
        _isLoading = false;
      });
    });
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_collectorLocation == null || _userLocation == null) {
      print("Cannot fetch route: locations not available");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Routes API v2 endpoint - make sure this is the correct URL
    final String url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    print("Fetching route using Google Routes API v2");
    print("From: ${_collectorLocation!.latitude},${_collectorLocation!.longitude}");
    print("To: ${_userLocation!.latitude},${_userLocation!.longitude}");

    try {
      // Routes API requires a POST request with a JSON body
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
          'X-Goog-FieldMask': 'routes.polyline'
        },
        body: json.encode({
          "origin": {
            "location": {
              "latLng": {
                "latitude": _collectorLocation!.latitude,
                "longitude": _collectorLocation!.longitude
              }
            }
          },
          "destination": {
            "location": {
              "latLng": {
                "latitude": _userLocation!.latitude,
                "longitude": _userLocation!.longitude
              }
            }
          },
          "travelMode": "DRIVE",
          "routingPreference": "TRAFFIC_AWARE",
          "computeAlternativeRoutes": false,
          "routeModifiers": {
            "avoidTolls": false,
            "avoidHighways": false,
            "avoidFerries": false
          },
          "languageCode": "en-US",
          "units": "METRIC"
        }),
      );

      print("Routes API response status: ${response.statusCode}");
      print("Routes API response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          // Extract the polyline from the response
          final String encodedPolyline = data['routes'][0]['polyline']['encodedPolyline'];
          List<LatLng> routePoints = _decodePolyline(encodedPolyline);

          print("Route decoded with ${routePoints.length} points");

          if (routePoints.isNotEmpty) {
            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: routePoints,
                  color: Colors.blue,
                  width: 5,
                ),
              );
              _isLoading = false;
            });

            _fitMapToBounds();
          }
        } else {
          setState(() {
            _errorMessage = "No route found between locations";
            _isLoading = false;
          });
        }
      } else {
        print("HTTP error: ${response.statusCode}, Body: ${response.body}");

        // Try fallback to Directions API if Routes API fails
        _tryDirectionsAPIFallback();
      }
    } catch (e) {
      print("Exception fetching route: $e");
      setState(() {
        _errorMessage = "Error fetching route: $e";
        _isLoading = false;
      });

      // Try fallback to Directions API
      _tryDirectionsAPIFallback();
    }
  }

// Fallback to the older Directions API if Routes API fails
  Future<void> _tryDirectionsAPIFallback() async {
    print("Trying fallback to Directions API");

    if (_collectorLocation == null || _userLocation == null) {
      return;
    }

    try {
      final String directionsUrl =
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${_collectorLocation!.latitude},${_collectorLocation!.longitude}'
          '&destination=${_userLocation!.latitude},${_userLocation!.longitude}'
          '&mode=driving'
          '&key=${_googleApiKey}';

      final response = await http.get(Uri.parse(directionsUrl));
      print("Directions API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          // Extract polyline points from the first route
          String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          List<LatLng> routePoints = _decodePolyline(encodedPolyline);

          print("Directions API route decoded with ${routePoints.length} points");

          if (routePoints.isNotEmpty) {
            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: routePoints,
                  color: Colors.blue,
                  width: 5,
                ),
              );
              _isLoading = false;
              _errorMessage = null;
            });

            _fitMapToBounds();
          }
        } else {
          setState(() {
            _errorMessage = "No route found: ${data['status']}";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Error fetching directions: HTTP ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error with directions fallback: $e";
        _isLoading = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _fitMapToBounds() {
    if (_collectorLocation != null && _userLocation != null && _mapController != null) {
      // Add padding to ensure both markers are visible
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _collectorLocation!.latitude < _userLocation!.latitude
              ? _collectorLocation!.latitude - 0.01
              : _userLocation!.latitude - 0.01,
          _collectorLocation!.longitude < _userLocation!.longitude
              ? _collectorLocation!.longitude - 0.01
              : _userLocation!.longitude - 0.01,
        ),
        northeast: LatLng(
          _collectorLocation!.latitude > _userLocation!.latitude
              ? _collectorLocation!.latitude + 0.01
              : _userLocation!.latitude + 0.01,
          _collectorLocation!.longitude > _userLocation!.longitude
              ? _collectorLocation!.longitude + 0.01
              : _userLocation!.longitude + 0.01,
        ),
      );

      // Use padding to ensure markers aren't cut off
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Collector Route - Order ${widget.orderId.substring(0, min(8, widget.orderId.length))}"),
        backgroundColor: Colors.green.shade700,
        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (_collectorLocation != null && _userLocation != null) {
                _fetchAndDrawRoute();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation ?? LatLng(0, 0), // Start with user location if available
              zoom: 14.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              print("Google Map created");
              _mapController = controller;
              if (_collectorLocation != null && _userLocation != null) {
                _fitMapToBounds();
              }
            },
            markers: {
              if (_collectorLocation != null)
                Marker(
                  markerId: MarkerId('collector'),
                  position: _collectorLocation!,
                  infoWindow: InfoWindow(title: "Collector"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              if (_userLocation != null)
                Marker(
                  markerId: MarkerId('user'),
                  position: _userLocation!,
                  infoWindow: InfoWindow(title: "Your Location"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
            },
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                color: Colors.black.withOpacity(0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        if (_collectorLocation != null && _userLocation != null) {
                          _fetchAndDrawRoute();
                        }
                      },
                      child: Text("Retry"),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.green.shade700),
                        SizedBox(height: 16),
                        Text("Loading route information...", style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_collectorLocation != null && _userLocation != null) {
            _fitMapToBounds();
          }
        },
        child: Icon(Icons.center_focus_strong),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}