import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 WebSocket Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LocationPage(),
    );
  }
}

class LocationPage extends StatefulWidget {
  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final WebSocketChannel channel = WebSocketChannel.connect(
    Uri.parse('ws://192.168.1.9:8266'),
  );

  GoogleMapController? mapController;
  Set<Marker> markers = {};
  
  double latitude = 0.0;
  double longitude = 0.0;
  Map<String, dynamic> locationData = {};
  bool isDataReceived = false;

  @override
  void initState() {
    super.initState();
    
    // Listen for WebSocket data
    channel.stream.listen((message) {
      try {
        final data = json.decode(message);

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final double lat = double.parse(data['latitude'].toString());
          final double lng = double.parse(data['longitude'].toString());

          setState(() {
            latitude = lat;
            longitude = lng;
            locationData = data;
            isDataReceived = true;

            markers.clear();
            markers.add(
              Marker(
                markerId: const MarkerId('currentLocation'),
                position: LatLng(lat, lng),
                infoWindow: const InfoWindow(title: 'Current Location'),
              ),
            );
          });

          if (mapController != null) {
            mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
            );
          }

          print('Updated location: $lat, $lng');
        }
      } catch (e) {
        print('Error parsing data: $e');
      }
    }, onError: (error) {
      print('WebSocket error: $error');
    }, onDone: () {
      print('WebSocket connection closed');
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    
    if (isDataReceived && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 Location Viewer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: locationData.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Latitude: $latitude", style: const TextStyle(fontSize: 16)),
                          Text("Longitude: $longitude", style: const TextStyle(fontSize: 16)),
                          Text("accuracy: ${locationData['accuracy'] ?? 'Unknown'}", style: const TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Text("Waiting for location data..."),
              ),
            ),
          ),
          Container(
            width: 380,
            height: 380,
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                mapType: MapType.normal,
                compassEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                zoomControlsEnabled: true,
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15.0,
                ),
                markers: markers,
              ),
            ),
          ),
        ],
      ),
    );
  }
}