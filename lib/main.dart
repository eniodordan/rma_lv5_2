import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Address {
  String country;
  String locality;
  String street;

  Address(this.country, this.locality, this.street);
}

void main() => runApp(WhereAmI());

class WhereAmI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gdje sam?',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  AudioCache audioCache = AudioCache();

  Position? _currentPosition;
  Address? _currentAddress;

  GoogleMapController? _controller;
  List<Marker> _markers = [];

  void _takePhoto() async {
    var recordedImage =
        await ImagePicker().getImage(source: ImageSource.camera);

    if (recordedImage != null) {
      await ImageGallerySaver.saveFile(recordedImage.path);

      _showNotification(
          'Spremljena je nova slika', recordedImage.path.toString());
    }
  }

  _onLongPress(LatLng latLng) async {
    await audioCache.play('marker.mp3');

    setState(() {
      _markers
          .add(Marker(markerId: MarkerId(latLng.toString()), position: latLng));
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller = controller;

    Geolocator.getPositionStream(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .listen((Position position) {
      setState(() {
        _currentPosition = position;
        _getAddressFromLatLng();
      });

      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
              target: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15),
        ),
      );
    });
  }

  _getCurrentLocation() {
    Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            forceAndroidLocationManager: true)
        .then((Position position) {
      setState(() {
        _currentPosition = position;
        _getAddressFromLatLng();
      });
    }).catchError((e) {
      print(e);
    });
  }

  _getAddressFromLatLng() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude,
          localeIdentifier: 'hr_HR');

      Placemark place = placemarks[0];

      setState(() {
        _currentAddress =
            Address(place.country!, place.locality!, place.street!);
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'your channel id', 'your channel name', 'your channel description',
            importance: Importance.max, priority: Priority.high);

    const IOSNotificationDetails iosNotificationDetails =
        IOSNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iosNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics);
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings();

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gdje sam?'),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(10),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 50.0,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _takePhoto,
                  child: Text('SNIMI FOTOGRAFIJU'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Geografska širina: ${_currentPosition?.latitude}'),
                    Text('Geografska dužina: ${_currentPosition?.longitude}'),
                    Text('Država: ${_currentAddress?.country}'),
                    Text('Mjesto: ${_currentAddress?.locality}'),
                    Text('Adresa: ${_currentAddress?.street}'),
                  ],
                ),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(45.554962, 18.695515),
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  onMapCreated: _onMapCreated,
                  onLongPress: _onLongPress,
                  markers: Set<Marker>.of(_markers),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
