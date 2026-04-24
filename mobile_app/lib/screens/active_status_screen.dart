import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ActiveStatusScreen extends StatefulWidget {
  final String statusType; // 'trips', 'denied', 'vehicles', 'drivers'
  const ActiveStatusScreen({super.key, required this.statusType});

  @override
  State<ActiveStatusScreen> createState() => _ActiveStatusScreenState();
}

class _ActiveStatusScreenState extends State<ActiveStatusScreen> {
  Map<String, dynamic>? data;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.getActiveStatus();
      setState(() {
        data = res;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading active status: $e");
      setState(() => isLoading = false);
    }
  }

  String _getTitle() {
    switch (widget.statusType) {
      case 'trips': return "ACTIVE TRIPS";
      case 'denied': return "DENIED ALLOCATIONS";
      case 'vehicles': return "ACTIVE VEHICLES";
      case 'drivers': return "ACTIVE DRIVERS";
      default: return "SYSTEM STATUS";
    }
  }

  List<dynamic> _getList() {
    if (data == null) return [];
    switch (widget.statusType) {
      case 'trips': return data!["active_trips"] ?? [];
      case 'denied': return data!["denied_allocations"] ?? [];
      case 'vehicles': return data!["active_vehicles"] ?? [];
      case 'drivers': return data!["active_drivers"] ?? [];
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _getList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No items found", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return _buildListItem(item);
                  },
                ),
    );
  }

  Widget _buildListItem(dynamic item) {
    String title = "";
    String subtitle = "";
    String badge = "";
    Color badgeColor = Colors.blue;

    if (widget.statusType == 'trips') {
      title = "Trip ID: ${item['id']}";
      subtitle = "Driver: ${item['driver_name']} | Vehicle: ${item['vin']}";
      badge = "ON TRIP";
      badgeColor = Colors.blue;
    } else if (widget.statusType == 'denied') {
      title = "Allocation ID: ${item['id']}";
      subtitle = "Driver: ${item['driver_name']} | Reason: ${item['reason'] ?? 'Not specified'}";
      badge = "DENIED";
      badgeColor = Colors.red;
    } else if (widget.statusType == 'vehicles') {
      title = "Vehicle: ${item['vin']}";
      subtitle = "Type: ${item['vehicle_type']} | Reg: ${item['registration_number']}";
      badge = "ACTIVE";
      badgeColor = Colors.green;
    } else if (widget.statusType == 'drivers') {
      title = item['name'] ?? 'Unknown Driver';
      subtitle = "Emp ID: ${item['employee_id']}";
      badge = "ON TRIP";
      badgeColor = Colors.lightBlue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
