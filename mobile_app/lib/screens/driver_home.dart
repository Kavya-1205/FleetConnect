import 'package:flutter/material.dart';
import 'trip_screen.dart';
import 'fuel_screen.dart';
import 'issue_screen.dart';
import 'repair_screen.dart';
import 'attendance_screen.dart';
import 'package:mobile_app/login_screen.dart';
import '../services/api_service.dart';

class DriverHome extends StatefulWidget {
  final String driverName;
  final int driverId;
  final String employeeId;

  const DriverHome({
    super.key,
    required this.driverName,
    required this.driverId,
    required this.employeeId,
  });

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  String? assignedVin;
  String? assignedRoute;
  String? assignedShift;
  String? allocationStatus;
  int? allocationId;
  bool isLoading = true;
  Map<String, dynamic>? _todayAttendance;

  @override
  void initState() {
    super.initState();
    _fetchAllocation();
    _fetchAttendance();
  }

  Future<void> _fetchAllocation() async {
    try {
      final allocation = await ApiService.getAllocationForDriver(
        widget.driverId,
      );
      if (mounted) {
        setState(() {
          if (allocation != null) {
            assignedVin = allocation['vin'];
            assignedRoute = allocation['route_name'];
            assignedShift = allocation['shift'];
            allocationStatus = allocation['status'];
            allocationId = allocation['id'];
          } else {
            assignedVin = null;
            assignedRoute = null;
            assignedShift = null;
            allocationStatus = null;
            allocationId = null;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching allocation: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateAllocation(String status) async {
    if (allocationId == null) return;
    try {
      await ApiService.updateAllocationStatus(allocationId!, status);
      _fetchAllocation();
    } catch (e) {
      debugPrint("Error updating allocation: $e");
    }
  }

  Future<void> _fetchAttendance() async {
    try {
      final att = await ApiService.getTodayAttendance(widget.driverId);
      if (mounted) setState(() => _todayAttendance = att);
    } catch (e) {
      debugPrint("Error fetching attendance: $e");
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'[\s.]+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, name.length < 2 ? name.length : 2).toUpperCase();
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _openProfileDrawer(BuildContext context) {
    final initials = _getInitials(widget.driverName);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Profile",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, _) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return SlideTransition(
          position: slide,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                height: double.infinity,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A2E2A),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Personal Details",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A2E2A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      color: Color(0xFF1A2E2A),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Employee ID",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          widget.employeeId,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.directions_car,
                                      color: Color(0xFF1A2E2A),
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Role",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          "Driver",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Logout",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(widget.driverName);

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
          child: RefreshIndicator(
            onRefresh: _fetchAllocation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                height: 32,
                                width: 32,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "FLEETCONNECT",
                                style: TextStyle(
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "Welcome back, ${widget.driverName}",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _openProfileDrawer(context),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1A2E2A),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Current Vehicle Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2E2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Current Vehicle",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4CAF50,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                              child: Text(
                                allocationStatus == 'ACCEPTED' ? "assigned" : (allocationStatus == 'PENDING' ? "pending" : "none"),
                                style: TextStyle(
                                  color: allocationStatus == 'ACCEPTED' ? Colors.green : (allocationStatus == 'PENDING' ? Colors.blue : Colors.grey),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          assignedVin ?? "No Assignment",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          assignedVin != null
                              ? "$assignedShift, $assignedRoute"
                              : "No Shift/Route Assigned",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _navigate(
                            context,
                            TripScreen(driverId: widget.driverId),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Start New Trip",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── NEW TRIP ASSIGNED BANNER ──
                  if (allocationStatus == 'PENDING') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade800),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "New Trip Assigned! Please accept or decline.",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _updateAllocation('CANCELLED'),
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
                                  onPressed: () => _updateAllocation('ACCEPTED'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text("Accept", style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Attendance Banner Card ──
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceScreen(
                            driverId: widget.driverId,
                            driverName: widget.driverName,
                          ),
                        ),
                      );
                      _fetchAttendance();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _todayAttendance == null
                              ? [
                                  const Color(0xFFE53935),
                                  const Color(0xFFB71C1C),
                                ]
                              : _todayAttendance!['punch_out'] != null
                              ? [
                                  const Color(0xFF1565C0),
                                  const Color(0xFF0D47A1),
                                ]
                              : [
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF1B5E20),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_todayAttendance == null
                                        ? const Color(0xFFE53935)
                                        : _todayAttendance!['punch_out'] != null
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFF2E7D32))
                                    .withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              _todayAttendance == null
                                  ? Icons.fingerprint
                                  : _todayAttendance!['punch_out'] != null
                                  ? Icons.check_circle_outline
                                  : Icons.access_time_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ATTENDANCE',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _todayAttendance == null
                                      ? 'Tap to Punch In'
                                      : _todayAttendance!['punch_out'] != null
                                      ? 'Shift Completed ✓'
                                      : 'On Duty — Tap to Punch Out',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white60,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Center(
                    child: Text(
                      "Fleet Services",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4 cards — no Assets
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildCard(
                        context,
                        Icons.route,
                        "Trips",
                        TripScreen(driverId: widget.driverId),
                      ),
                      _buildCard(
                        context,
                        Icons.local_gas_station,
                        "Fuel",
                        FuelScreen(driverId: widget.driverId),
                      ),
                      _buildCard(
                        context,
                        Icons.warning_amber_rounded,
                        "Issues",
                        IssueScreen(driverId: widget.driverId),
                      ),
                      _buildCard(
                        context,
                        Icons.history,
                        "Repair",
                        RepairScreen(driverId: widget.driverId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      "Fleet Management System v2.4 • Secure Session",
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    IconData icon,
    String label,
    Widget screen,
  ) {
    return GestureDetector(
      onTap: () => _navigate(context, screen),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E2A).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: const Color(0xFF1A2E2A)),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
