import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripScreen extends StatefulWidget {
  final int driverId;
  const TripScreen({super.key, required this.driverId});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  List vehicles = [];
  List routes = [];

  int? selectedVehicle;
  String? selectedVehicleVin;
  int? selectedRoute;
  String? selectedRouteName;
  String? selectedShift;
  Map? currentAllocation;

  bool tripStarted = false;
  int? tripId;

  final TextEditingController startOdoController = TextEditingController();
  final TextEditingController endOdoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    loadTripData();
  }

  void loadTripData() async {
    final prefs = await SharedPreferences.getInstance();
    final String keyPrefix = "driver_${widget.driverId}_";
    final isStarted = prefs.getBool('${keyPrefix}trip_started') ?? false;

    if (isStarted) {
      setState(() {
        tripStarted = true;
        tripId = prefs.getInt('${keyPrefix}trip_id');
        selectedVehicle = prefs.getInt('${keyPrefix}vehicle_id');
        selectedVehicleVin = prefs.getString('${keyPrefix}vehicle_vin') ?? '';
        selectedRoute = prefs.getInt('${keyPrefix}route_id');
        selectedRouteName = prefs.getString('${keyPrefix}route_name') ?? '';
        selectedShift = prefs.getString('${keyPrefix}shift');
        final startOdo = prefs.getInt('${keyPrefix}start_odo');
        if (startOdo != null) startOdoController.text = startOdo.toString();
      });
    }
  }

  void loadData() async {
    final v = await ApiService.getVehicles();
    final r = await ApiService.getRoutes();
    final allocation = await ApiService.getAllocationForDriver(widget.driverId);

    setState(() {
      vehicles = v;
      routes = r;
      currentAllocation = allocation;

      if (!tripStarted && allocation != null && allocation['status'] == 'ACCEPTED') {
        selectedVehicle = allocation['vehicle_id'];
        selectedVehicleVin = allocation['vin'];
        selectedRoute = allocation['route_id'];
        selectedRouteName = allocation['route_name'];
        selectedShift = allocation['shift'];
      } else if (!tripStarted) {
        selectedVehicle = null;
        selectedVehicleVin = null;
        selectedRoute = null;
        selectedRouteName = null;
        selectedShift = null;
      }
    });
  }

  Widget _allocationStatusCard() {
    if (currentAllocation == null) return const SizedBox.shrink();
    final status = currentAllocation!['status'] ?? 'PENDING';
    final isPending = status == 'PENDING';
    final isAccepted = status == 'ACCEPTED';

    if (status == 'CANCELLED') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAccepted ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccepted ? Colors.green.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ASSIGNED TRIP",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isAccepted ? Colors.green.shade800 : Colors.blue.shade800,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isAccepted ? Colors.green : (status == 'CANCELLED' ? Colors.red : Colors.blue),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Vehicle: ${currentAllocation!['vin'] ?? '—'}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text("Route: ${currentAllocation!['route_name'] ?? '—'}"),
          Text("Shift: ${currentAllocation!['shift'] ?? '—'}"),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus('CANCELLED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text("Decline"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus('ACCEPTED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Accept", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _updateStatus(String status) async {
    try {
      await ApiService.updateAllocationStatus(currentAllocation!['id'], status);
      loadData(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Trip $status")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDialog(String title, bool isSuccess) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? const Color(0xFF4CAF50) : Colors.red,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2E2A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void startTrip() async {
    if (selectedVehicle == null) {
      _showDialog("Please select a Vehicle !", false);
      return;
    }
    if (selectedRoute == null) {
      _showDialog("Please select a Route !", false);
      return;
    }
    if (selectedShift == null) {
      _showDialog("Please select a Shift !", false);
      return;
    }
    if (startOdoController.text.isEmpty) {
      _showDialog("Please enter Start ODO !", false);
      return;
    }

    try {
      final id = await ApiService.startTrip(
        driverId: widget.driverId,
        vehicleId: selectedVehicle!,
        routeId: selectedRoute!,
        startOdo: int.parse(startOdoController.text),
        shift: selectedShift!,
      );

      setState(() {
        tripStarted = true;
        tripId = id;
      });

      final prefs = await SharedPreferences.getInstance();
      final String keyPrefix = "driver_${widget.driverId}_";
      await prefs.setBool("${keyPrefix}trip_started", true);
      await prefs.setInt("${keyPrefix}trip_id", id);
      await prefs.setInt("${keyPrefix}vehicle_id", selectedVehicle!);
      await prefs.setString(
        "${keyPrefix}vehicle_vin",
        selectedVehicleVin ?? '',
      );
      await prefs.setInt("${keyPrefix}route_id", selectedRoute!);
      await prefs.setString("${keyPrefix}route_name", selectedRouteName ?? '');
      await prefs.setString("${keyPrefix}shift", selectedShift!);
      await prefs.setInt(
        "${keyPrefix}start_odo",
        int.parse(startOdoController.text),
      );

      // Keep these for backward compatibility if needed by other screens
      await prefs.setInt("driver_${widget.driverId}_trip_id", id);
      await prefs.setInt(
        "driver_${widget.driverId}_vehicle_id",
        selectedVehicle!,
      );
      await prefs.setString(
        "driver_${widget.driverId}_vin",
        selectedVehicleVin ?? '',
      );

      if (!mounted) return;
      _showDialog("Trip Started! 🚀", true);
    } catch (e) {
      debugPrint("ERROR: $e");
      if (!mounted) return;
      _showDialog("Error starting trip !", false);
    }
  }

  void endTrip() async {
    if (endOdoController.text.isEmpty) {
      _showDialog("Please enter End ODO !", false);
      return;
    }

    await ApiService.endTrip(
      tripId: tripId!,
      endOdo: int.parse(endOdoController.text),
    );

    final prefs = await SharedPreferences.getInstance();
    final String keyPrefix = "driver_${widget.driverId}_";
    await prefs.remove("${keyPrefix}trip_started");
    await prefs.remove("${keyPrefix}trip_id");
    await prefs.remove("${keyPrefix}vehicle_id");
    await prefs.remove("${keyPrefix}vehicle_vin");
    await prefs.remove("${keyPrefix}route_id");
    await prefs.remove("${keyPrefix}route_name");
    await prefs.remove("${keyPrefix}shift");
    await prefs.remove("${keyPrefix}start_odo");
    await prefs.remove("driver_${widget.driverId}_trip_id");
    await prefs.remove("driver_${widget.driverId}_vehicle_id");
    await prefs.remove("driver_${widget.driverId}_vin");

    if (!mounted) return;
    _showDialog("Trip Completed! ✅", true);

    setState(() {
      tripStarted = false;
      tripId = null;
      startOdoController.clear();
      endOdoController.clear();
      selectedVehicle = null;
      selectedVehicleVin = null;
      selectedRoute = null;
      selectedRouteName = null;
      selectedShift = null;
    });
  }

  // Top summary box widget
  Widget _summaryBox(IconData icon, String label, String? value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6B7280), size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 4),
            Text(
              value != null && value.isNotEmpty ? value : "Not Set",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value != null && value.isNotEmpty
                    ? const Color(0xFF1A1A2E)
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String hint,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2E2A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _odoField({
    required String label,
    required TextEditingController controller,
    required bool readOnly,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          prefixIcon: const Icon(Icons.speed, color: Colors.grey, size: 20),
          suffixIcon: readOnly
              ? null
              : const Icon(Icons.edit, color: Colors.grey, size: 18),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFB), Color(0xFFF0F2F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1A1A2E),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "TRIP MANAGEMENT",
                      style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentAllocation != null && !tripStarted) ...[
                        _allocationStatusCard(),
                        if (currentAllocation!['status'] == 'CANCELLED')
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "You declined the assigned trip. Please wait for the admin to re-assign a new allocation.",
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                      // ✅ Top summary: VIN | Route | Shift (order changed)
                      const Text(
                        "Assigned Schedule",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2E2A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _summaryBox(
                            Icons.directions_car,
                            "Vehicle",
                            selectedVehicleVin,
                          ),
                          const SizedBox(width: 10),
                          _summaryBox(
                            Icons.location_on,
                            "Route",
                            selectedRouteName,
                          ),
                          const SizedBox(width: 10),
                          _summaryBox(
                            Icons.access_time,
                            "Shift",
                            selectedShift,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Trip Configuration section
                      const Text(
                        "Trip Configuration",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2E2A),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ✅ Order: VIN → Route → Shift
                      // VEHICLE VIN
                      _dropdownField(
                        label: "Vehicle VIN",
                        hint: "Select VIN",
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            hint: const Text(
                              "Select VIN",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            value: selectedVehicle,
                            items: vehicles.map<DropdownMenuItem<int>>((v) {
                              return DropdownMenuItem<int>(
                                value: v['id'],
                                child: Text(
                                  v['vin'] ?? "",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (tripStarted || (currentAllocation != null && currentAllocation!['status'] == 'CANCELLED'))
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedVehicle = value;
                                      final v = vehicles.firstWhere(
                                        (v) => v['id'] == value,
                                        orElse: () => null,
                                      );
                                      selectedVehicleVin = v != null
                                          ? (v['vin'] ?? '')
                                          : '';
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ASSIGNED ROUTE
                      _dropdownField(
                        label: "Assigned Route",
                        hint: "Select Route",
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            hint: const Text(
                              "Select Route",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            value: selectedRoute,
                            items: routes.map<DropdownMenuItem<int>>((r) {
                              return DropdownMenuItem<int>(
                                value: r['id'],
                                child: Text(
                                  r['route_name'] ?? "",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (tripStarted || (currentAllocation != null && currentAllocation!['status'] == 'CANCELLED'))
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedRoute = value;
                                      final r = routes.firstWhere(
                                        (r) => r['id'] == value,
                                        orElse: () => null,
                                      );
                                      selectedRouteName = r != null
                                          ? (r['route_name'] ?? '')
                                          : '';
                                    });
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // SHIFT
                      _dropdownField(
                        label: "Shift",
                        hint: "Select Shift",
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text(
                              "Select Shift", // ✅ null default = Not Set
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            value: selectedShift,
                            items: ["Shift-1", "Shift-2"].map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (tripStarted || (currentAllocation != null && currentAllocation!['status'] == 'CANCELLED'))
                                ? null
                                : (value) =>
                                      setState(() => selectedShift = value),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ODO LOGS
                      const Text(
                        "Odometer Logs",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2E2A),
                        ),
                      ),
                      const SizedBox(height: 10),

                      _odoField(
                        label: "Start Odometer (km)",
                        controller: startOdoController,
                        readOnly: tripStarted,
                      ),
                      const SizedBox(height: 10),

                      if (tripStarted)
                        _odoField(
                          label: "End Odometer (km)",
                          controller: endOdoController,
                          readOnly: false,
                        ),

                      const SizedBox(height: 24),

                      // ACTION BUTTON
                      if (!tripStarted)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: (currentAllocation != null && currentAllocation!['status'] == 'CANCELLED') ? null : startTrip,
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            label: Text(
                              (currentAllocation != null && currentAllocation!['status'] == 'CANCELLED')
                                  ? "Denied - Wait for Admin"
                                  : "Start Trip",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (currentAllocation != null && currentAllocation!['status'] == 'CANCELLED')
                                  ? Colors.grey
                                  : const Color(0xFF1A2E2A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: endTrip,
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "End Trip & Submit",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
