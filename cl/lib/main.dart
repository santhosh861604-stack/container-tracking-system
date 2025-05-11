import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Container Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: IDEntryPage(),
    );
  }
}

class ContainerData {
  final int id;
  final String name;
  final String ip;

  ContainerData({required this.id, required this.name, required this.ip});

  factory ContainerData.fromJson(Map<String, dynamic> json) {
    return ContainerData(
      id: json['id'],
      name: json['name'],
      ip: json['ip'],
    );
  }
}

class IDEntryPage extends StatefulWidget {
  @override
  _IDEntryPageState createState() => _IDEntryPageState();
}

class _IDEntryPageState extends State<IDEntryPage> {
  final TextEditingController _idController = TextEditingController();
  List<ContainerData> containers = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    loadContainerData();
  }

  Future<void> loadContainerData() async {
    try {
      // Load data.json from assets
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      
      setState(() {
        containers = jsonData.map((item) => ContainerData.fromJson(item)).toList();
        isLoading = false;
      });
      
      print('Loaded ${containers.length} containers from data.json');
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load container data: $e';
        isLoading = false;
      });
      print('Error loading data.json: $e');
    }
  }

  void _checkID() {
    if (_idController.text.isEmpty) {
      _showErrorDialog('Please enter a container ID');
      return;
    }

    try {
      final int enteredId = int.parse(_idController.text);
      final ContainerData? matchedContainer = containers.firstWhere(
        (container) => container.id == enteredId,
        orElse: () => throw Exception('No container found with ID: $enteredId'),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LocationPage(containerData: matchedContainer!),
        ),
      );
    } catch (e) {
      if (e is FormatException) {
        _showErrorDialog('Please enter a valid numeric ID');
      } else {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Container Tracker')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Enter Container ID',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _idController,
                        decoration: InputDecoration(
                          labelText: 'Container ID',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 6734',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkID,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 24.0,
                          ),
                          child: Text(
                            'Track Container',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class LocationPage extends StatefulWidget {
  final ContainerData containerData;

  const LocationPage({required this.containerData});

  @override
  _LocationPageState createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late WebSocketChannel channel;
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  
  double latitude = 0.0;
  double longitude = 0.0;
  Map<String, dynamic> locationData = {};
  bool isDataReceived = false;
  bool isConnecting = false;
  String lastUpdateTime = '';
  String connectionStatus = 'No data received yet';

  @override
  void initState() {
    super.initState();
    // Get location data once on page load
    _getLocationData();
  }

  void _getLocationData() {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting...';
    });

    try {
      // Create a new connection each time
      channel = WebSocketChannel.connect(
        Uri.parse(widget.containerData.ip),
      );

      // Set up single-response listener
      channel.stream.listen((message) {
        try {
          final data = json.decode(message);

          if (data.containsKey('latitude') && data.containsKey('longitude')) {
            final double lat = double.parse(data['latitude'].toString());
            final double lng = double.parse(data['longitude'].toString());
            
            // Get current time for last update timestamp
            final now = DateTime.now();
            final formattedTime = 
                '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

            setState(() {
              latitude = lat;
              longitude = lng;
              locationData = data;
              isDataReceived = true;
              isConnecting = false;
              lastUpdateTime = formattedTime;
              connectionStatus = 'Data received successfully';

              markers.clear();
              markers.add(
                Marker(
                  markerId: const MarkerId('currentLocation'),
                  position: LatLng(lat, lng),
                  infoWindow: InfoWindow(title: widget.containerData.name),
                ),
              );
            });

            if (mapController != null) {
              mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.0),
              );
            }

            print('Location updated: $lat, $lng at $formattedTime');

            // Close the connection after receiving data
            channel.sink.close();
          }
        } catch (e) {
          setState(() {
            isConnecting = false;
            connectionStatus = 'Error parsing data: $e';
          });
          print('Error parsing data: $e');
          channel.sink.close();
        }
      }, onError: (error) {
        setState(() {
          isConnecting = false;
          connectionStatus = 'Connection error: $error';
        });
        print('WebSocket error: $error');
        channel.sink.close();
      }, onDone: () {
        if (isConnecting) {
          setState(() {
            isConnecting = false;
            connectionStatus = 'Connection closed without receiving data';
          });
          print('WebSocket connection closed without data');
        }
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
        connectionStatus = 'Failed to connect: $e';
      });
      print('WebSocket connection failed: $e');
    }
  }

  @override
  void dispose() {
    // Ensure channel is closed when page is disposed
    if (channel != null) {
      channel.sink.close();
    }
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
      appBar: AppBar(
        title: Text('${widget.containerData.name} (ID: ${widget.containerData.id})'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: isConnecting ? null : _getLocationData,
            tooltip: 'Get latest location',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnecting ? Icons.sync : (isDataReceived ? Icons.check_circle : Icons.error),
                          color: isConnecting ? Colors.blue : (isDataReceived ? Colors.green : Colors.red),
                        ),
                        SizedBox(width: 8),
                        Text(
                          connectionStatus,
                          style: TextStyle(
                            color: isConnecting ? Colors.blue : (isDataReceived ? Colors.green : Colors.red),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    locationData.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Latitude: $latitude", style: const TextStyle(fontSize: 16)),
                              Text("Longitude: $longitude", style: const TextStyle(fontSize: 16)),
                              Text("Accuracy: ${locationData['accuracy'] ?? 'Unknown'}", style: const TextStyle(fontSize: 16)),
                              if (lastUpdateTime.isNotEmpty)
                                Text("Last updated: $lastUpdateTime", 
                                     style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          )
                        : const Text("Waiting for location data..."),
                  ],
                ),
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