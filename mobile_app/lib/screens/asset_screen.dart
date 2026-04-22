import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ── Main Asset Tracking Screen ──
class AssetScreen extends StatelessWidget {
  final int driverId;
  const AssetScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {
        'title': 'Dashcam Fixation',
        'icon': Icons.videocam_outlined,
        'color': const Color(0xFF1565C0),
      },
      {
        'title': 'Datalogger Fixation',
        'icon': Icons.storage_outlined,
        'color': const Color(0xFF6A1B9A),
      },
      {
        'title': 'Fuel Card Assignment',
        'icon': Icons.credit_card_outlined,
        'color': const Color(0xFF2E7D32),
      },
      {
        'title': 'TC Plate Allocation',
        'icon': Icons.assignment_outlined,
        'color': const Color(0xFFE65100),
        'isTCPlate': true,
      },
      {
        'title': 'Puncture Repair Kit',
        'icon': Icons.build_circle_outlined,
        'color': const Color(0xFF00695C),
      },
      {
        'title': 'Emergency Kit Assignment',
        'icon': Icons.medical_services_outlined,
        'color': const Color(0xFFC62828),
      },
      {
        'title': 'Sandbag Allocation',
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFF4E342E),
      },
    ];

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
                      "ASSET TRACKING",
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
                      const Text(
                        "Track vehicle instrumentation & hardware",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Select Category",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isTCPlate = cat['isTCPlate'] == true;

                            return GestureDetector(
                              onTap: () {
                                if (isTCPlate) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TCPlateScreen(driverId: driverId),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AssetFormScreen(
                                        driverId: driverId,
                                        categoryTitle: cat['title'],
                                        categoryIcon: cat['icon'],
                                        categoryColor: cat['color'],
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (cat['color'] as Color)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        cat['icon'] as IconData,
                                        color: cat['color'] as Color,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        cat['title'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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

// ── Standard Asset Form Screen (6 categories) ──
class AssetFormScreen extends StatefulWidget {
  final int driverId;
  final String categoryTitle;
  final IconData categoryIcon;
  final Color categoryColor;

  const AssetFormScreen({
    super.key,
    required this.driverId,
    required this.categoryTitle,
    required this.categoryIcon,
    required this.categoryColor,
  });

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  List vehicles = [];
  int? selectedVehicle;
  bool isSubmitting = false;
  DateTime? selectedDate;

  final TextEditingController requestedByController = TextEditingController();
  final TextEditingController fittedByController = TextEditingController();
  final TextEditingController assetNumberController = TextEditingController();
  final TextEditingController odoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() async {
    try {
      final v = await ApiService.getVehicles();
      setState(() => vehicles = v);
    } catch (e) {
      debugPrint("Error loading vehicles: $e");
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A2E2A),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
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
                color: Color(0xFF1A1A2E),
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

  void submitAsset() async {
    if (selectedVehicle == null) {
      _showDialog("Please select a VIN !", false);
      return;
    }
    if (assetNumberController.text.trim().isEmpty) {
      _showDialog("Please enter asset number !", false);
      return;
    }
    if (selectedDate == null) {
      _showDialog("Please select installation date !", false);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ApiService.addAsset(
        driverId: widget.driverId,
        vehicleId: selectedVehicle!,
        category: widget.categoryTitle,
        requestedBy: requestedByController.text.trim(),
        fittedBy: fittedByController.text.trim(),
        assetNumber: assetNumberController.text.trim(),
        installationDate: selectedDate!,
        odoReading: odoController.text.trim(),
      );

      setState(() => isSubmitting = false);
      if (!mounted) return;

      requestedByController.clear();
      fittedByController.clear();
      assetNumberController.clear();
      odoController.clear();
      setState(() {
        selectedVehicle = null;
        selectedDate = null;
      });

      _showDialog("Asset Logged! 📦", true);
    } catch (e) {
      setState(() => isSubmitting = false);
      if (!mounted) return;
      _showDialog("Failed to submit !", false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 14,
          ),
        ),
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
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Details header
            const Text(
              "Asset Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 20),

            // Vehicle VIN
            const Text(
              "Vehicle VIN",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text(
                    "Select VIN",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
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
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Installation Date
            const Text(
              "Installation / Allocation Date",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      selectedDate != null
                          ? "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}"
                          : "YYYY-MM-DD",
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedDate != null
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Requested By
            const Text(
              "Requested By",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: requestedByController,
              hint: "Enter requester name",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),

            // Fitted By
            const Text(
              "Fitted / Placed By",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: fittedByController,
              hint: "Enter technician name",
              icon: Icons.people_outline,
            ),
            const SizedBox(height: 16),

            // Asset Number
            const Text(
              "Asset Number",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: assetNumberController,
              hint: "SN-XXXX-XXXX",
              icon: Icons.qr_code_2,
            ),
            const SizedBox(height: 16),

            // ODO Reading
            const Text(
              "ODO Reading",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: odoController,
              hint: "Current mileage",
              icon: Icons.speed,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitAsset,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.lock_outline, color: Colors.white),
                label: const Text(
                  "Submit Asset Allocation",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── TC Plate Unique Screen ──
class TCPlateScreen extends StatefulWidget {
  final int driverId;
  const TCPlateScreen({super.key, required this.driverId});

  @override
  State<TCPlateScreen> createState() => _TCPlateScreenState();
}

class _TCPlateScreenState extends State<TCPlateScreen> {
  List vehicles = [];
  int? selectedVehicle;
  bool isSubmitting = false;
  DateTime? selectedDate;

  final TextEditingController tcPlateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() async {
    try {
      final v = await ApiService.getVehicles();
      setState(() => vehicles = v);
    } catch (e) {
      debugPrint("Error loading vehicles: $e");
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A2E2A),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
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
                color: Color(0xFF1A1A2E),
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

  void submitTCPlate() async {
    if (tcPlateController.text.trim().isEmpty) {
      _showDialog("Please enter TC Plate number !", false);
      return;
    }
    if (selectedVehicle == null) {
      _showDialog("Please select a VIN !", false);
      return;
    }
    if (selectedDate == null) {
      _showDialog("Please select allocation date !", false);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ApiService.addAsset(
        driverId: widget.driverId,
        vehicleId: selectedVehicle!,
        category: "TC Plate Allocation",
        requestedBy: "",
        fittedBy: "",
        assetNumber: tcPlateController.text.trim(),
        installationDate: selectedDate!,
        odoReading: "",
      );

      setState(() => isSubmitting = false);
      if (!mounted) return;

      tcPlateController.clear();
      setState(() {
        selectedVehicle = null;
        selectedDate = null;
      });

      _showDialog("TC Plate Allocated! ✅", true);
    } catch (e) {
      setState(() => isSubmitting = false);
      if (!mounted) return;
      _showDialog("Failed to submit !", false);
    }
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TC Plate Allocation",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "Assign TC Plate to Vehicle",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "NEW ENTRY",
              style: TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(width: 4, height: 20, color: const Color(0xFFE65100)),
                const SizedBox(width: 8),
                const Text(
                  "Allocation Details",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // TC Plate Number
            const Text(
              "TC Plate Number",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: tcPlateController,
                decoration: const InputDecoration(
                  hintText: "Enter TC Plate Number",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.credit_card_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Assigned to VIN
            const Text(
              "Assigned to VIN",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  hint: const Text(
                    "Select Vehicle VIN",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
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
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Allocation Date
            const Text(
              "Allocation Date",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDate != null
                          ? "${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year}"
                          : "Select Date",
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedDate != null
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitTCPlate,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                label: const Text(
                  "Submit Allocation",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
