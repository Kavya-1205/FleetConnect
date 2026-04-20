import 'package:flutter/material.dart';
import '../services/api_service.dart';

class IssueScreen extends StatefulWidget {
  final int driverId;
  const IssueScreen({super.key, required this.driverId});

  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  List vehicles = [];
  String? selectedVin;
  bool isSubmitting = false;
  DateTime selectedDate = DateTime.now();

  // ✅ NEW: ODO Entry controller
  final TextEditingController odoController = TextEditingController();
  final TextEditingController issueController = TextEditingController();

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
      initialDate: selectedDate,
      firstDate: DateTime(2023),
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

  void submitIssue() async {
    if (selectedVin == null) {
      _showDialog("Please select a VIN !", false);
      return;
    }
    // ✅ Validate ODO
    if (odoController.text.trim().isEmpty) {
      _showDialog("Please enter ODO reading !", false);
      return;
    }
    if (issueController.text.trim().isEmpty) {
      _showDialog("Please describe the issue !", false);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ApiService.addIssue(
        driverId: widget.driverId,
        vehicleVin: selectedVin!,
        description: issueController.text.trim(),
        date: selectedDate,
        odoEntry: int.parse(odoController.text.trim()), // ✅ NEW
      );

      setState(() => isSubmitting = false);
      if (!mounted) return;

      issueController.clear();
      odoController.clear(); // ✅ clear ODO
      setState(() {
        selectedVin = null;
        selectedDate = DateTime.now();
      });

      _showDialog("Issue Reported! ⚠️", true);
    } catch (e) {
      setState(() => isSubmitting = false);
      debugPrint("ERROR: $e");
      if (!mounted) return;
      _showDialog("Failed to submit !", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Issue / Observation",
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

            // ✅ Label changed: "Select VIN" (not "Select Vehicle (VIN)")
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
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text("Select VIN",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  value: selectedVin,
                  items: vehicles.map<DropdownMenuItem<String>>((v) {
                    return DropdownMenuItem<String>(
                      value: v['vin'],
                      child: Text(v['vin'] ?? "No Vehicle",
                          style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => selectedVin = value),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date Picker
            const Text("Date",
                style: TextStyle(
                    fontSize: 13,
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
                        color: Color(0xFF1A2E2A), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1A1A2E)),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ NEW: ODO Entry
            const Text("ODO Entry",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2E2A))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: odoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "Current odometer reading",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.speed, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Issue Description
            const Text("Issue / Observation",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2E2A))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: issueController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText:
                      "Describe the issue or observation in detail...",
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
                onPressed: isSubmitting ? null : submitIssue,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white),
                label: const Text("Submit Issue",
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
          ],
        ),
      ),
    );
  }
}