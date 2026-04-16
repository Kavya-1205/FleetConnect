import 'package:flutter/material.dart';
import 'package:mobile_app/login_screen.dart';
import 'services/api_service.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // ✅ fixed warning

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: LoginScreen());
  }
}

class TripScreen extends StatefulWidget {
  const TripScreen({super.key}); // ✅ fixed warning

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  List vehicles = [];
  List routes = [];

  int? selectedVehicle;
  int? selectedRoute;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final v = await ApiService.getVehicles();
    final r = await ApiService.getRoutes();

    setState(() {
      vehicles = v;
      routes = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start Trip")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // VEHICLE DROPDOWN
            DropdownButtonFormField<int>(
              hint: const Text("Select Vehicle"),
              initialValue: selectedVehicle,
              items: vehicles.map<DropdownMenuItem<int>>((v) {
                return DropdownMenuItem<int>(
                  value: v['id'],
                  child: Text(v['vin']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedVehicle = value;
                });
              },
            ),

            const SizedBox(height: 20),

            // ROUTE DROPDOWN
            DropdownButtonFormField<int>(
              hint: const Text("Select Route"),
              initialValue: selectedRoute,
              items: routes.map<DropdownMenuItem<int>>((r) {
                return DropdownMenuItem<int>(
                  value: r['id'],
                  child: Text(r['route_name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedRoute = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
