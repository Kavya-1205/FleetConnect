import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class FuelScreen extends StatefulWidget {
  final int driverId;
  const FuelScreen({super.key, required this.driverId});

  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  // ── Active trip state ──
  bool tripActive = false;
  int? activeTripId;
  int? activeTripVehicleId;
  String activeTripVin = "";
  String? activePrimaryFC;
  String? activeSecondaryFC;

  // ── Inactive trip state ──
  List vehicles = [];
  int? selectedVehicle;
  String? inactivePrimaryFC;
  String? inactiveSecondaryFC;

  // ── Tab selection ──
  int _selectedTab = 0;

  // ── Shared ──
  List<String> allFuelCards = [];

  // ── Active trip form ──
  String activeFuelType = "Diesel";
  XFile? activeBillImage;
  bool activeSubmitting = false;
  final TextEditingController activeLitresCtrl = TextEditingController();
  final TextEditingController activeAmountCtrl = TextEditingController();

  // ── Inactive trip form ──
  String inactiveFuelType = "Diesel";
  XFile? inactiveBillImage;
  bool inactiveSubmitting = false;
  final TextEditingController inactiveLitresCtrl = TextEditingController();
  final TextEditingController inactiveAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTripStatus();
    _loadVehicles();
    _loadAllFuelCards();
  }

  void _loadTripStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripId = prefs.getInt('driver_${widget.driverId}_trip_id');
      final vehicleId = prefs.getInt('driver_${widget.driverId}_vehicle_id');
      final vin = prefs.getString('driver_${widget.driverId}_vin') ?? "";
      setState(() {
        tripActive = tripId != null;
        activeTripId = tripId;
        activeTripVehicleId = vehicleId;
        activeTripVin = vin;
        _selectedTab = tripId != null ? 0 : 1;
      });
      if (vehicleId != null) {
        final fc = await ApiService.getFuelCardForVehicle(vehicleId);
        setState(() => activePrimaryFC = fc);
      }
    } catch (e) {
      debugPrint("Error loading trip status: $e");
    }
  }

  void _loadVehicles() async {
    try {
      final v = await ApiService.getVehicles();
      setState(() => vehicles = v);
    } catch (e) {
      debugPrint("Error loading vehicles: $e");
    }
  }

  void _loadAllFuelCards() async {
    try {
      final cards = await ApiService.getAllFuelCards();
      setState(() => allFuelCards = cards);
    } catch (e) {
      debugPrint("Error loading all fuel cards: $e");
    }
  }

  void _loadInactiveFuelCard(int vehicleId) async {
    try {
      final fc = await ApiService.getFuelCardForVehicle(vehicleId);
      setState(() {
        inactivePrimaryFC = fc;
        inactiveSecondaryFC = null;
      });
    } catch (e) {
      debugPrint("Error loading inactive fuel card: $e");
    }
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      return await picker.pickImage(source: source, imageQuality: 30);
    } catch (e) {
      debugPrint("Image picker error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open camera/gallery: $e")),
        );
      }
      return null;
    }
  }

  void _showImageOptions(Function(XFile) onPicked) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1A2E2A)),
              title: const Text("Take Photo"),
              onTap: () async {
                Navigator.pop(context);
                final f = await _pickImage(ImageSource.camera);
                if (f != null) onPicked(f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1A2E2A)),
              title: const Text("Choose from Gallery"),
              onTap: () async {
                Navigator.pop(context);
                final f = await _pickImage(ImageSource.gallery);
                if (f != null) onPicked(f);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? const Color(0xFF4CAF50) : Colors.red,
                size: 56),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2E2A)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitActive() async {
    if (activePrimaryFC == null) {
      _showDialog("No fuel card assigned to this vehicle!", false);
      return;
    }
    if (activeLitresCtrl.text.isEmpty) {
      _showDialog("Please enter Litres!", false);
      return;
    }
    if (activeAmountCtrl.text.isEmpty) {
      _showDialog("Please enter Amount!", false);
      return;
    }
    setState(() => activeSubmitting = true);
    print("Image: $activeBillImage");
    try {
      String? base64Image;
      if (activeBillImage != null) {
        debugPrint("FUEL_UPLOAD: Reading image bytes...");
        final bytes = await activeBillImage!.readAsBytes();
        debugPrint("FUEL_UPLOAD: Image size = ${bytes.length} bytes");
        base64Image = base64Encode(bytes);
        debugPrint("FUEL_UPLOAD: Base64 length = ${base64Image.length}");
      }
      await ApiService.addFuelEntry(
        tripId: activeTripId,
        driverId: widget.driverId,
        vehicleId: activeTripVehicleId,
        litres: double.parse(activeLitresCtrl.text),
        amount: double.parse(activeAmountCtrl.text),
        fuelType: activeFuelType,
        fuelCardNumber: activeSecondaryFC ?? activePrimaryFC!,
        billImage: base64Image,
      );
      setState(() {
        activeSubmitting = false;
        activeBillImage = null;
        activeFuelType = "Diesel";
        activeSecondaryFC = null;
        activeLitresCtrl.clear();
        activeAmountCtrl.clear();
      });
      if (!mounted) return;
      _showDialog("Fuel Entry Added! ⛽", true);
    } catch (e) {
      setState(() => activeSubmitting = false);
      _showDialog("Failed to submit!", false);
    }
  }

  void _submitInactive() async {
    if (selectedVehicle == null) {
      _showDialog("Please select a VIN!", false);
      return;
    }
    if (inactivePrimaryFC == null) {
      _showDialog("No fuel card assigned to this VIN!", false);
      return;
    }
    if (inactiveLitresCtrl.text.isEmpty) {
      _showDialog("Please enter Litres!", false);
      return;
    }
    if (inactiveAmountCtrl.text.isEmpty) {
      _showDialog("Please enter Amount!", false);
      return;
    }
    setState(() => inactiveSubmitting = true);
    try {
      String? base64Image;
      if (inactiveBillImage != null) {
        final bytes = await inactiveBillImage!.readAsBytes();
        base64Image = base64Encode(bytes);
      }
      await ApiService.addFuelEntry(
        tripId: null,
        driverId: widget.driverId,
        vehicleId: selectedVehicle,
        litres: double.parse(inactiveLitresCtrl.text),
        amount: double.parse(inactiveAmountCtrl.text),
        fuelType: inactiveFuelType,
        fuelCardNumber: inactiveSecondaryFC ?? inactivePrimaryFC!,
        billImage: base64Image,
      );
      setState(() {
        inactiveSubmitting = false;
        inactiveBillImage = null;
        inactiveFuelType = "Petrol";
        inactiveSecondaryFC = null;
        inactiveLitresCtrl.clear();
        inactiveAmountCtrl.clear();
        selectedVehicle = null;
        inactivePrimaryFC = null;
      });
      if (!mounted) return;
      _showDialog("Fuel Entry Added! ⛽", true);
    } catch (e) {
      setState(() => inactiveSubmitting = false);
      _showDialog("Failed to submit!", false);
    }
  }

  // ── Reusable fuel form ──
  Widget _fuelTypeRow(String selected, ValueChanged<String> onChanged) {
    return Row(
      children: ["Petrol", "Diesel"].map((type) {
        final isSelected = selected == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: Container(
              margin: EdgeInsets.only(right: type == "Petrol" ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A2E2A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Icon(Icons.local_gas_station,
                      color: isSelected ? Colors.white : Colors.grey, size: 24),
                  const SizedBox(height: 4),
                  Text(type,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _photoBox(XFile? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(image.path, fit: BoxFit.cover)
                    : Image.file(File(image.path), fit: BoxFit.cover))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                  SizedBox(height: 6),
                  Text("Tap to upload bill",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
      ),
    );
  }

  Widget _fcAutoFill(String? fc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: fc != null
            ? const Color(0xFF1A2E2A).withValues(alpha: 0.05)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: fc != null
                ? const Color(0xFF1A2E2A).withValues(alpha: 0.3)
                : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.credit_card,
              color: fc != null ? const Color(0xFF1A2E2A) : Colors.grey,
              size: 20),
          const SizedBox(width: 10),
          Text(fc ?? "Select VIN to load fuel card",
              style: TextStyle(
                  fontSize: 14,
                  color: fc != null ? const Color(0xFF1A1A2E) : Colors.grey)),
          const Spacer(),
          if (fc != null)
            const Text("Assigned",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _secondaryFCDropdown(
      String? value, List<String> exclude, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: const Text("None (use primary)",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          items: [
            const DropdownMenuItem<String?>(
                value: null,
                child: Text("None (use primary)",
                    style: TextStyle(color: Colors.grey, fontSize: 14))),
            ...allFuelCards
                .where((fc) => !exclude.contains(fc))
                .map((fc) => DropdownMenuItem<String?>(
                    value: fc,
                    child: Text(fc, style: const TextStyle(fontSize: 14)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionHeader(bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isActive
                ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.directions_car : Icons.directions_car_outlined,
            color: isActive ? const Color(0xFF2E7D32) : Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isActive ? "Active Trip Fuel Filling" : "Non-Active Trip Fuel Filling",
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isActive
                    ? const Color(0xFF2E7D32)
                    : Colors.orange.shade800),
          ),
          if (!isActive && !tripActive) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("Available",
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600)),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Fuel Log",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedTab = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedTab == 0
                          ? const Color(0xFF1A2E2A)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car,
                            size: 15,
                            color: _selectedTab == 0
                                ? Colors.white
                                : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text("Active",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _selectedTab == 0
                                    ? Colors.white
                                    : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedTab == 1
                          ? Colors.orange.shade700
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car_outlined,
                            size: 15,
                            color: _selectedTab == 1
                                ? Colors.white
                                : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text("Non-Active",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _selectedTab == 1
                                    ? Colors.white
                                    : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ══════════════════════════════
              // SECTION 1: ACTIVE TRIP
              // ══════════════════════════════
              if (_selectedTab == 0) ...[
              _sectionHeader(true),
              const SizedBox(height: 14),

              if (!tripActive)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "No active trip. Start a trip from the Trips tab to use this section.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // VIN auto-filled
                const Text("Vehicle VIN",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2A))),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car,
                          color: Colors.grey, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        activeTripVin.isNotEmpty ? activeTripVin : "Loading...",
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1A1A2E)),
                      ),
                      const Spacer(),
                      const Text("Auto-filled",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                const Text("Fuel Card (Primary)",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2A))),
                const SizedBox(height: 8),
                _fcAutoFill(activePrimaryFC),
                const SizedBox(height: 4),
                const Text("Auto-filled based on assigned VIN",
                    style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
                const SizedBox(height: 12),

                const Text("Secondary Fuel Card (Low Balance?)",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2A))),
                const SizedBox(height: 8),
                _secondaryFCDropdown(
                  activeSecondaryFC,
                  [activePrimaryFC ?? ''],
                  (v) => setState(() => activeSecondaryFC = v),
                ),
                const SizedBox(height: 4),
                const Text("Select only if primary card has low balance",
                    style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
                const SizedBox(height: 12),

                const Text("Receipt Photo",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2A))),
                const SizedBox(height: 8),
                _photoBox(activeBillImage,
                    () => _showImageOptions((f) => setState(() => activeBillImage = f))),
                const SizedBox(height: 12),

                const Text("Select Fuel Type",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2A))),
                const SizedBox(height: 8),
                _fuelTypeRow(activeFuelType,
                    (v) => setState(() => activeFuelType = v)),
                const SizedBox(height: 12),

                _inputField(activeLitresCtrl, "Litres Filled",
                    Icons.oil_barrel_outlined, isNumber: true),
                const SizedBox(height: 4),
                const Text("Enter total litres filled",
                    style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
                const SizedBox(height: 10),

                _inputField(activeAmountCtrl, "Total Amount (Rs.)",
                    Icons.currency_rupee, isNumber: true),
                const SizedBox(height: 4),
                const Text("Total cost as per receipt",
                    style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: activeSubmitting ? null : _submitActive,
                    icon: activeSubmitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.local_gas_station,
                            color: Colors.white),
                    label: const Text("Add Fuel Entry (Active Trip)",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2E2A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],

              ],

              // ══════════════════════════════
              // SECTION 2: NON-ACTIVE TRIP
              // ══════════════════════════════
              if (_selectedTab == 1) ...[
              _sectionHeader(false),
              const SizedBox(height: 14),

              // VIN dropdown
              const Text("Select VIN",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2E2A))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    hint: const Text("Select VIN",
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    value: selectedVehicle,
                    items: vehicles.map<DropdownMenuItem<int>>((v) {
                      return DropdownMenuItem<int>(
                        value: v['id'],
                        child: Text(v['vin'] ?? "",
                            style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedVehicle = value;
                        inactivePrimaryFC = null;
                        inactiveSecondaryFC = null;
                      });
                      if (value != null) _loadInactiveFuelCard(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text("Fuel Card (Primary)",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2E2A))),
              const SizedBox(height: 8),
              _fcAutoFill(inactivePrimaryFC),
              const SizedBox(height: 4),
              const Text("Auto-filled based on assigned VIN",
                  style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
              const SizedBox(height: 12),

              const Text("Secondary Fuel Card (Low Balance?)",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2E2A))),
              const SizedBox(height: 8),
              _secondaryFCDropdown(
                inactiveSecondaryFC,
                [inactivePrimaryFC ?? ''],
                (v) => setState(() => inactiveSecondaryFC = v),
              ),
              const SizedBox(height: 4),
              const Text("Select only if primary card has low balance",
                  style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
              const SizedBox(height: 12),

              const Text("Receipt Photo",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2E2A))),
              const SizedBox(height: 8),
              _photoBox(inactiveBillImage,
                  () => _showImageOptions((f) => setState(() => inactiveBillImage = f))),
              const SizedBox(height: 12),

              const Text("Select Fuel Type",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2E2A))),
              const SizedBox(height: 8),
              _fuelTypeRow(inactiveFuelType,
                  (v) => setState(() => inactiveFuelType = v)),
              const SizedBox(height: 12),

              _inputField(inactiveLitresCtrl, "Litres Filled",
                  Icons.oil_barrel_outlined, isNumber: true),
              const SizedBox(height: 4),
              const Text("Enter total litres filled",
                  style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
              const SizedBox(height: 10),

              _inputField(inactiveAmountCtrl, "Total Amount (Rs.)",
                  Icons.currency_rupee, isNumber: true),
              const SizedBox(height: 4),
              const Text("Total cost as per receipt",
                  style: TextStyle(color: Color(0xFF4A90A4), fontSize: 12)),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: inactiveSubmitting ? null : _submitInactive,
                  icon: inactiveSubmitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.local_gas_station,
                          color: Colors.white),
                  label: const Text("Add Fuel Entry (Non-Trip)",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
