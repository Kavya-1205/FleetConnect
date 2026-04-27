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
      case 'trips':
        return "ACTIVE TRIPS";
      case 'denied':
        return "DENIED ALLOCATIONS";
      case 'vehicles':
        return "ACTIVE VEHICLES";
      case 'drivers':
        return "ACTIVE DRIVERS";
      default:
        return "SYSTEM STATUS";
    }
  }

  List<dynamic> _getList() {
    if (data == null) return [];
    switch (widget.statusType) {
      case 'trips':
        return data!["active_trips"] ?? [];
      case 'denied':
        return data!["denied_allocations"] ?? [];
      case 'vehicles':
        return data!["active_vehicles"] ?? [];
      case 'drivers':
        return data!["active_drivers"] ?? [];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _getList();

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
              // ── Custom AppBar — same style as all other screens ──
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
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Color(0xFF1A1A2E),
                      ),
                      onPressed: _loadData,
                      tooltip: "Refresh",
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1A2E2A),
                        ),
                      )
                    : list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No items found",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(dynamic item) {
    String title = "";
    String subtitle = "";
    String badge = "";
    Color badgeColor = Colors.blue;
    IconData leadingIcon = Icons.info_outline;

    if (widget.statusType == 'trips') {
      title = "Trip ID: ${item['id']}";
      subtitle = "Driver: ${item['driver_name']}   •   VIN: ${item['vin']}";
      badge = "ON TRIP";
      badgeColor = Colors.blue;
      leadingIcon = Icons.directions_car;
    } else if (widget.statusType == 'denied') {
      title = "Allocation ID: ${item['id']}";
      subtitle =
          "Driver: ${item['driver_name']}   •   Reason: ${item['reason'] ?? 'Not specified'}";
      badge = "DENIED";
      badgeColor = Colors.red;
      leadingIcon = Icons.cancel_outlined;
    } else if (widget.statusType == 'vehicles') {
      // ── Only show VIN — no "Type: null | Reg: null" ──
      title = item['vin'] ?? 'Unknown VIN';
      subtitle = ""; // intentionally blank
      badge = "ACTIVE";
      badgeColor = Colors.green;
      leadingIcon = Icons.local_shipping;
    } else if (widget.statusType == 'drivers') {
      title = item['name'] ?? 'Unknown Driver';
      subtitle = "Employee ID: ${item['employee_id']}";
      badge = "ON TRIP";
      badgeColor = Colors.lightBlue;
      leadingIcon = Icons.person;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Coloured left accent bar
            Container(
              width: 4,
              height: subtitle.isNotEmpty ? 44 : 24,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(leadingIcon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Badge chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
