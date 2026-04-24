import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ActiveStatusScreen extends StatefulWidget {
  const ActiveStatusScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "SYSTEM STATUS",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          backgroundColor: const Color(0xFF1A2E2A),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "Active Trips"),
              Tab(text: "Denied Allocations"),
              Tab(text: "Active Vehicles"),
              Tab(text: "Active Drivers"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isLaptop = constraints.maxWidth > 600;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _topStatBox(0, "Active Trips", data?["active_trips"]?.length ?? 0, Icons.directions_car, Colors.green)),
                                const SizedBox(width: 10),
                                Expanded(child: _topStatBox(1, "Denied Alloc.", data?["denied_allocations"]?.length ?? 0, Icons.cancel_outlined, Colors.red)),
                                if (isLaptop) ...[
                                  const SizedBox(width: 10),
                                  Expanded(child: _topStatBox(2, "Active Vehicles", data?["active_vehicles"]?.length ?? 0, Icons.local_shipping, Colors.orange)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _topStatBox(3, "Active Drivers", data?["active_drivers"]?.length ?? 0, Icons.people, Colors.blue)),
                                ],
                              ],
                            ),
                            if (!isLaptop) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _topStatBox(2, "Active Vehicles", data?["active_vehicles"]?.length ?? 0, Icons.local_shipping, Colors.orange)),
                                  const SizedBox(width: 10),
                                  Expanded(child: _topStatBox(3, "Active Drivers", data?["active_drivers"]?.length ?? 0, Icons.people, Colors.blue)),
                                ],
                              ),
                            ],
                          ],
                        );
                      }
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildList("active_trips"),
                        _buildList("denied_allocations"),
                        _buildList("active_vehicles"),
                        _buildList("active_drivers"),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _topStatBox(int index, String label, int count, IconData icon, Color color) {
    return Builder(
      builder: (context) {
        final isSelected = DefaultTabController.of(context).index == index;
        return GestureDetector(
          onTap: () => DefaultTabController.of(context).animateTo(index),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(
                  count.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildList(String key) {
    final List items = data?[key] ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No items found", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
        final item = items[index];
        if (key == "active_trips") {
          return _statusCard(
            title: item['vin'] ?? "Unknown VIN",
            subtitle: "Driver: ${item['driver_name']}\nRoute: ${item['route_name']}",
            trailing: "STARTED",
            color: Colors.green,
          );
        } else if (key == "denied_allocations") {
          return _statusCard(
            title: item['vin'] ?? "Unknown VIN",
            subtitle: "Driver: ${item['driver_name']}\nRoute: ${item['route_name']}",
            trailing: "DENIED",
            color: Colors.red,
          );
        } else if (key == "active_vehicles") {
          return _statusCard(
            title: item['vin'] ?? "Unknown VIN",
            subtitle: "${item['brand']} ${item['variant']}",
            trailing: "IN TRIP",
            color: Colors.orange,
          );
        } else {
          // active_drivers
          return _statusCard(
            title: item['name'] ?? "Unknown Driver",
            subtitle: "Emp ID: ${item['employee_id']}",
            trailing: "ON TRIP",
            color: Colors.blue,
          );
        }
      },
    );
  }

  Widget _statusCard({
    required String title,
    required String subtitle,
    required String trailing,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(
              trailing,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
