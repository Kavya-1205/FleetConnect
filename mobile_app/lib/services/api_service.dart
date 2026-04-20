import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = "https://fleet-backend-xxeg.onrender.com";

  // ─────────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────────
  // Returns full user map on success, null on fail
  static Future<Map<String, dynamic>?> login(String empId, String password, String role) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "emp_id": empId,
          "password": password,
          "role": role.toLowerCase(),
        }),
      );

      debugPrint("LOGIN STATUS: ${response.statusCode}");
      debugPrint("LOGIN BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) return data["user"];
      }
    } catch (e) {
      debugPrint("LOGIN ERROR: $e");
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stats'));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("getStats error: $e"); }
    return {
      "active_drivers": 0, "active_vehicles": 0,
      "active_admins": 0, "active_routes": 0,
      "active_trips": 0, "trip_allocations": 0,
    };
  }

  // ─────────────────────────────────────────────
  // VEHICLES
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getVehicles() async {
    final response = await http.get(Uri.parse('$baseUrl/vehicles'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load vehicles');
  }

  static Future<List<dynamic>> getVehiclesAll() async {
    final response = await http.get(Uri.parse('$baseUrl/vehicles/all'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> addVehicle(String vin, String brand, String variant,
      String engineType, String gearboxType, String projectCode,
      String batch, String svNumber, String powertrainType) async {
    await http.post(Uri.parse('$baseUrl/vehicles'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vin": vin, "brand": brand, "variant": variant,
          "engine_type": engineType, "gearbox_type": gearboxType,
          "project_code": projectCode, "batch": batch,
          "sv_number": svNumber, "powertrain_type": powertrainType,
        }));
  }

  static Future<void> updateVehicle(int id, String vin, String brand,
      String variant, String engineType, String gearboxType, bool active,
      String projectCode, String batch, String svNumber, String powertrainType) async {
    await http.put(Uri.parse('$baseUrl/vehicles/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vin": vin, "brand": brand, "variant": variant,
          "engine_type": engineType, "gearbox_type": gearboxType, "active": active,
          "project_code": projectCode, "batch": batch,
          "sv_number": svNumber, "powertrain_type": powertrainType,
        }));
  }

  static Future<void> deleteVehicle(int id) async {
    await http.delete(Uri.parse('$baseUrl/vehicles/$id'));
  }

  // ─────────────────────────────────────────────
  // ROUTES
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getRoutes() async {
    final response = await http.get(Uri.parse('$baseUrl/routes'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load routes');
  }

  static Future<List<dynamic>> getRoutesAll() async {
    final response = await http.get(Uri.parse('$baseUrl/routes/all'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> addRoute(String name, String circuit, int kms) async {
    await http.post(Uri.parse('$baseUrl/routes'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "route_name": name, "circuit_type": circuit, "kms_coverage": kms,
        }));
  }

  static Future<void> updateRoute(int id, String name, String circuit,
      int kms, bool active) async {
    await http.put(Uri.parse('$baseUrl/routes/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "route_name": name, "circuit_type": circuit,
          "kms_coverage": kms, "active": active,
        }));
  }

  static Future<void> deleteRoute(int id) async {
    await http.delete(Uri.parse('$baseUrl/routes/$id'));
  }

  // ─────────────────────────────────────────────
  // ADMINS
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getAdmins() async {
    final response = await http.get(Uri.parse('$baseUrl/users/admins'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> addUser(String empId, String name,
      String password, String role) async {
    await http.post(Uri.parse('$baseUrl/users'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "employee_id": empId, "name": name,
          "password": password, "role": role,
        }));
  }

  static Future<void> updateUser(int id, String empId, String name,
      String password, String role) async {
    await http.put(Uri.parse('$baseUrl/users/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "employee_id": empId, "name": name,
          "password": password, "role": role,
        }));
  }

  static Future<void> deleteUser(int id) async {
    await http.delete(Uri.parse('$baseUrl/users/$id'));
  }

  // ─────────────────────────────────────────────
  // DRIVERS
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getDrivers() async {
    final response = await http.get(Uri.parse('$baseUrl/users/drivers'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> addDriver({
    required String empId, required String name, required String password,
    required double experience, required String dlNumber, required String dlExpiry,
    required String joiningDate,
  }) async {
    await http.post(Uri.parse('$baseUrl/drivers'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "employee_id": empId, "name": name, "password": password,
          "experience": experience, "dl_number": dlNumber, "dl_expiry": dlExpiry,
          "joining_date": joiningDate,
        }));
  }

  static Future<void> updateDriver({
    required int id, required String empId, required String name,
    required String password, required double experience,
    required String dlNumber, required String dlExpiry, required bool active,
    required String joiningDate,
  }) async {
    await http.put(Uri.parse('$baseUrl/drivers/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "employee_id": empId, "name": name, "password": password,
          "experience": experience, "dl_number": dlNumber,
          "dl_expiry": dlExpiry, "active": active,
          "joining_date": joiningDate,
        }));
  }

  // ─────────────────────────────────────────────
  // FUEL CARDS
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getFuelCardsAll() async {
    final response = await http.get(Uri.parse('$baseUrl/fuel-cards'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> addFuelCard(String fcNumber, int? vehicleId) async {
    await http.post(Uri.parse('$baseUrl/fuel-cards'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"fc_number": fcNumber, "vehicle_id": vehicleId}));
  }

  static Future<void> updateFuelCard(int id, String fcNumber,
      int? vehicleId, bool active) async {
    await http.put(Uri.parse('$baseUrl/fuel-cards/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fc_number": fcNumber, "vehicle_id": vehicleId, "active": active,
        }));
  }

  static Future<void> deleteFuelCard(int id) async {
    await http.delete(Uri.parse('$baseUrl/fuel-cards/$id'));
  }

  // ─────────────────────────────────────────────
  // TRIP ALLOCATION
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getTripAllocations() async {
    final response = await http.get(Uri.parse('$baseUrl/trip-allocations'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> assignTrip({
    required int driverId, required int vehicleId,
    required int routeId, required String shift,
  }) async {
    final response = await http.post(Uri.parse('$baseUrl/trip-allocations'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driver_id": driverId, "vehicle_id": vehicleId,
          "route_id": routeId, "shift": shift,
        }));
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? "Failed to assign trip");
    }
  }

  static Future<void> deleteAllocation(int id) async {
    await http.delete(Uri.parse('$baseUrl/trip-allocations/$id'));
  }

  // ─────────────────────────────────────────────
  // TRIPS
  // ─────────────────────────────────────────────
  static Future<int> startTrip({
    required int driverId, required int vehicleId, required int routeId,
    required int startOdo, required String shift,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/start-trip"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "driver_id": driverId, "vehicle_id": vehicleId, "route_id": routeId,
        "start_odo": startOdo, "shift": shift,
      }),
    );
    final data = jsonDecode(response.body);
    debugPrint("API RESPONSE: $data");
    return data["trip_id"];
  }

  static Future<void> endTrip({required int tripId, required int endOdo}) async {
    await http.post(
      Uri.parse("$baseUrl/end-trip"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"trip_id": tripId, "end_odo": endOdo}),
    );
  }

  static Future<List<dynamic>> getAllTrips() async {
    final response = await http.get(Uri.parse('$baseUrl/trips/all'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ─────────────────────────────────────────────
  // REPORTS
  // ─────────────────────────────────────────────
  static Future<List<dynamic>> getAllFuel() async {
    final response = await http.get(Uri.parse('$baseUrl/fuel/all'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getAllIssues() async {
    final response = await http.get(Uri.parse('$baseUrl/issues/all'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getAllRepairs() async {
    final response = await http.get(Uri.parse('$baseUrl/repairs/all'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<List<dynamic>> getAllAssets() async {
    final response = await http.get(Uri.parse('$baseUrl/assets'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  static Future<void> addAsset({
    required int vehicleId,
    required String category,
    required String requestedBy,
    required String fittedBy,
    required String assetNumber,
    required DateTime installationDate,
    required String odoReading,
  }) async {
    await http.post(Uri.parse('$baseUrl/assets'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vehicle_id": vehicleId,
          "category": category,
          "requested_by": requestedBy,
          "fitted_by": fittedBy,
          "asset_number": assetNumber,
          "installation_date": installationDate.toIso8601String(),
          "odo_reading": odoReading,
        }));
  }

  static Future<void> deleteAsset(int id) async {
    await http.delete(Uri.parse('$baseUrl/assets/$id'));
  }

  // ─────────────────────────────────────────────
  // FUEL CARD - for driver app
  // ─────────────────────────────────────────────
  // Returns the fc_number string, or null if none assigned
  static Future<String?> getFuelCardForVehicle(int vehicleId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/fuel-cards/by-vehicle/$vehicleId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) return data['fc_number'] as String?;
      }
    } catch (e) { debugPrint("getFuelCardForVehicle error: $e"); }
    return null;
  }

  // Returns list of fc_number strings for dropdown
  static Future<List<String>> getAllFuelCards() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/fuel-cards'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e['fc_number'].toString()).toList();
      }
    } catch (e) { debugPrint("getAllFuelCards error: $e"); }
    return [];
  }

  // ─────────────────────────────────────────────
  // FUEL ENTRY - exact params fuel_screen uses
  // ─────────────────────────────────────────────
  static Future<void> addFuelEntry({
    required int? tripId,
    required int driverId,
    required int? vehicleId,
    required double litres,
    required double amount,
    required String fuelType,
    required String fuelCardNumber,
    String? billImage,
  }) async {
    final response = await http.post(Uri.parse('$baseUrl/fuel-entries'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "trip_id": tripId,
          "driver_id": driverId,
          "vehicle_id": vehicleId,
          "litres": litres,
          "amount": amount,
          "fuel_type": fuelType,
          "fuel_card_number": fuelCardNumber,
          "bill_image": billImage,
        }));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to add fuel entry: ${response.statusCode}");
    }
  }

  // ─────────────────────────────────────────────
  // ISSUES - exact params issue_screen uses
  // ─────────────────────────────────────────────
  static Future<void> addIssue({
    required int driverId,
    required String vehicleVin,
    required String description,
    required DateTime date,
    required int odoEntry,
  }) async {
    await http.post(Uri.parse('$baseUrl/issues'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driver_id": driverId,
          "vehicle_vin": vehicleVin,
          "description": description,
          "odo_entry": odoEntry,
          "date": date.toIso8601String(),
        }));
  }

  // ─────────────────────────────────────────────
  // REPAIRS - exact params repair_screen uses
  // ─────────────────────────────────────────────
  static Future<void> addRepair({
    required int driverId,
    required int vehicleId,
    required DateTime serviceDate,
    required String requestedBy,
    required String performedBy,
    required String odoReading,
    required String repairDetails,
    required String notes,
    required bool partReplacement,
    required bool partRemovalRefit,
    required bool softwareFlashing,
  }) async {
    await http.post(Uri.parse('$baseUrl/repairs'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driver_id": driverId,
          "vehicle_id": vehicleId,
          "service_date": serviceDate.toIso8601String(),
          "requested_by": requestedBy,
          "performed_by": performedBy,
          "odo_reading": odoReading,
          "repair_details": repairDetails,
          "notes": notes,
          "part_replacement": partReplacement,
          "part_removal_refit": partRemovalRefit,
          "software_flashing": softwareFlashing,
        }));
  }
  // Returns the current allocation for a specific driver
  static Future<Map<String, dynamic>?> getAllocationForDriver(int driverId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/trip-allocations/by-driver/$driverId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) { debugPrint("getAllocationForDriver error: $e"); }
    return null;
  }

  // ─────────────────────────────────────────────
  // ATTENDANCE
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getTodayAttendance(int driverId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/attendance/today/$driverId'));
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body == 'null' || body.isEmpty) return null;
        return jsonDecode(body);
      }
    } catch (e) { debugPrint("getTodayAttendance error: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>?> punchIn(int driverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/punch-in'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"driver_id": driverId}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("punchIn error: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>?> punchOut(int driverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/punch-out'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"driver_id": driverId}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("punchOut error: $e"); }
    return null;
  }

  static Future<List<dynamic>> getAllAttendance({String? date}) async {
    try {
      final uri = date != null
          ? Uri.parse('$baseUrl/attendance/all?date=$date')
          : Uri.parse('$baseUrl/attendance/all');
      final response = await http.get(uri);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("getAllAttendance error: $e"); }
    return [];
  }
}