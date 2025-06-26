import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';


class MapPopup extends StatefulWidget {
  final Function(LatLng) onLocationSelected;

  const MapPopup({Key? key, required this.onLocationSelected}) : super(key: key);

  @override
  _MapPopupState createState() => _MapPopupState();
}

class _MapPopupState extends State<MapPopup> {
  GoogleMapController? _controller;
  LatLng? _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  final places = GoogleMapsPlaces(apiKey: "AIzaSyBi64Rv17l9KsYs0civEAQooLfhdFdiCxE"); // Replace with your API key
  List<PlacesSearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      if (_controller != null && _selectedLocation != null) {
        _controller!.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation!, 15));
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      PlacesSearchResponse response = await places.searchByText(query);
      setState(() {
        _searchResults = response.results;
      });
    } catch (e) {
      print("Error searching location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error searching location: $e")),
      );
    }
  }

  void _selectPlace(PlacesSearchResult place) {
    LatLng newLocation = LatLng(
      place.geometry!.location.lat,
      place.geometry!.location.lng,
    );
    setState(() {
      _selectedLocation = newLocation;
      _searchResults = [];
      _searchController.clear();
    });
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 15));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: 500, // Increased height for search results
        width: double.infinity,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search location",
                  suffixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _searchLocation, // Real-time search
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                height: 100,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    return ListTile(
                      title: Text(place.name),
                      subtitle: Text(place.formattedAddress ?? ''),
                      onTap: () => _selectPlace(place),
                    );
                  },
                ),
              ),
            Expanded(
              child: _selectedLocation == null
                  ? Center(child: CircularProgressIndicator())
                  : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation!,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _controller = controller;
                },
                onTap: (location) {
                  setState(() {
                    _selectedLocation = location;
                    _searchResults = [];
                    _searchController.clear();
                  });
                },
                markers: _selectedLocation == null
                    ? {}
                    : {
                  Marker(
                    markerId: MarkerId('selected_location'),
                    position: _selectedLocation!,
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _selectedLocation == null
                        ? null
                        : () => widget.onLocationSelected(_selectedLocation!),
                    child: Text('Confirm Location'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}