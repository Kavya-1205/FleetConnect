import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RepairScreen extends StatefulWidget {
  final int driverId;
  const RepairScreen({super.key, required this.driverId});

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen> {
  List vehicles = [];
  int? selectedVehicle;
  bool isSubmitting = false;
  DateTime? selectedDate;

  final TextEditingController requestedByController = TextEditingController();
  final TextEditingController performedByController = TextEditingController();
  final TextEditingController odoController = TextEditingController();
  final TextEditingController repairDetailsController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // ✅ NEW: Yes/No toggles
  bool partReplacement = false;
  bool partRemovalRefit = false;
  bool softwareFlashing = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() async {
    final v = await ApiService.getVehicles();
    setState(() => vehicles = v);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A2E2A),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _showDialog(String title, bool isSuccess) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                child:
                    const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void submitRepair() async {
    if (selectedVehicle == null) {
      _showDialog("Please select a VIN !", false);
      return;
    }
    if (selectedDate == null) {
      _showDialog("Please select service date !", false);
      return;
    }
    if (repairDetailsController.text.trim().isEmpty) {
      _showDialog("Please enter repair details !", false);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ApiService.addRepair(
        driverId: widget.driverId,
        vehicleId: selectedVehicle!,
        serviceDate: selectedDate!,
        requestedBy: requestedByController.text.trim(),
        performedBy: performedByController.text.trim(),
        odoReading: odoController.text.trim(),
        repairDetails: repairDetailsController.text.trim(),
        notes: notesController.text.trim(),
        partReplacement: partReplacement,       // ✅ NEW
        partRemovalRefit: partRemovalRefit,     // ✅ NEW
        softwareFlashing: softwareFlashing,     // ✅ NEW
      );

      setState(() => isSubmitting = false);
      if (!mounted) return;

      requestedByController.clear();
      performedByController.clear();
      odoController.clear();
      repairDetailsController.clear();
      notesController.clear();
      setState(() {
        selectedVehicle = null;
        selectedDate = null;
        partReplacement = false;   // ✅ reset
        partRemovalRefit = false;  // ✅ reset
        softwareFlashing = false;  // ✅ reset
      });

      _showDialog("Repair Log Submitted! 🛠️", true);
    } catch (e) {
      setState(() => isSubmitting = false);
      debugPrint("ERROR: $e");
      if (!mounted) return;
      _showDialog("Failed to submit !", false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
      ),
    );
  }

  // ✅ NEW: Yes/No toggle widget — same style as the rest of the app
  Widget _yesNoToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF1A1A2E))),
          Row(
            children: [
              GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: value
                        ? const Color(0xFF1A2E2A)
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8)),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text("Yes",
                      style: TextStyle(
                          color: value ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
              GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: !value
                        ? Colors.red.shade400
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(8)),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text("No",
                      style: TextStyle(
                          color: !value ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
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
        title: const Text("Repair Logging",
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
                "Record maintenance and repair activities for the fleet.",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),

            // Vehicle VIN
            const Text("Vehicle VIN",
                style: TextStyle(
                    fontSize: 14,
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
                  onChanged: (value) =>
                      setState(() => selectedVehicle = value),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Service Date
            const Text("Service Date",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2E2A))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.grey, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      selectedDate != null
                          ? "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}"
                          : "YYYY-MM-DD",
                      style: TextStyle(
                          fontSize: 14,
                          color: selectedDate != null
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Service Personnel
            Row(
              children: [
                Container(width: 4, height: 18, color: Colors.orange),
                const SizedBox(width: 8),
                const Text("Service Personnel",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2E2A))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Requested By",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      _buildField(
                        controller: requestedByController,
                        label: "Requested By",
                        hint: "EMP Name",
                        icon: Icons.person_outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Performed By",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      _buildField(
                        controller: performedByController,
                        label: "Performed By",
                        hint: "Technician/Shop",
                        icon: Icons.build_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Service Information
            Row(
              children: [
                Container(width: 4, height: 18, color: Colors.orange),
                const SizedBox(width: 8),
                const Text("Service Information",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2E2A))),
              ],
            ),
            const SizedBox(height: 12),

            const Text("ODO Reading (km)",
                style: TextStyle(fontSize: 13, color: Color(0xFF1A2E2A))),
            const SizedBox(height: 6),
            _buildField(
              controller: odoController,
              label: "ODO Reading",
              hint: "Current Mileage",
              icon: Icons.speed,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            // Repair Details
            const Text("Repair Details",
                style: TextStyle(fontSize: 13, color: Color(0xFF1A2E2A))),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: repairDetailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Describe the work performed...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ✅ NEW: Repair Type Section with Yes/No toggles
            Row(
              children: [
                Container(width: 4, height: 18, color: Colors.orange),
                const SizedBox(width: 8),
                const Text("Repair Type",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2E2A))),
              ],
            ),
            const SizedBox(height: 12),
            _yesNoToggle("Part Replacement", partReplacement,
                (v) => setState(() => partReplacement = v)),
            const SizedBox(height: 10),
            _yesNoToggle("Part Removal / Refit", partRemovalRefit,
                (v) => setState(() => partRemovalRefit = v)),
            const SizedBox(height: 10),
            _yesNoToggle("Software Flashing", softwareFlashing,
                (v) => setState(() => softwareFlashing = v)),
            const SizedBox(height: 20),

            // Additional Notes
            const Text("Additional Notes",
                style: TextStyle(fontSize: 13, color: Color(0xFF1A2E2A))),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Parts used, warranty info, etc.",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitRepair,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline,
                        color: Colors.white),
                label: const Text("Submit Repair Log",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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