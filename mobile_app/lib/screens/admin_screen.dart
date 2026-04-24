import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_app/login_screen.dart';
import '../services/api_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html'
    if (dart.library.io) 'package:mobile_app/stub_html.dart'
    as html;

// ─────────────────────────────────────────────
// EXCEL DOWNLOAD HELPER (uses share_plus)
// ─────────────────────────────────────────────
Future<void> downloadAsXlsx(
  BuildContext context,
  String sheetName,
  List<String> headers,
  List<List<String>> rows,
) async {
  try {
    final excel = Excel.createExcel();
    // Use the default sheet if it exists, otherwise create/rename
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    final sheet = excel[sheetName];

    // Header row
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // Data rows
    for (final row in rows) {
      sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${sheetName}_$timestamp.xlsx';

    final bytes = excel.encode();
    debugPrint("EXCEL_BYTES: ${bytes?.length ?? 0}");
    if (bytes != null) {
      if (kIsWeb) {
        // ✅ Web download: create an anchor tag and click it
        debugPrint("EXCEL: Triggering Web download for $fileName");
        final blob = html.Blob([
          Uint8List.fromList(bytes),
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        anchor.remove();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ $fileName downloading to your device..."),
            ),
          );
        }
        return;
      }

      // ✅ Mobile APK logic — share sheet so user can save to Downloads
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      debugPrint("EXCEL: Saved to ${file.path}, sharing now...");
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Download $sheetName',
        text: '$sheetName Report',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ $fileName — save it from the share sheet!"),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint("Excel error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Download failed: $e")));
    }
  }
}

// Global time helper
String _formatTime(dynamic val) {
  if (val == null) return "00:00";
  try {
    DateTime dt;
    if (val is DateTime) {
      dt = val.toLocal();
    } else {
      dt = DateTime.parse(val.toString()).toLocal();
    }
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  } catch (e) {
    return "00:00";
  }
}

String _formatDate(dynamic val) {
  if (val == null) return "";
  try {
    final s = val.toString();
    if (s.contains('T')) return s.split('T')[0];
    return s;
  } catch (e) {
    return "";
  }
}

// ─────────────────────────────────────────────
// MAIN ADMIN HOME
// ─────────────────────────────────────────────
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String adminName = "Admin";
  String adminEmpId = "";
  Map<String, dynamic> stats = {
    "active_drivers": 0,
    "active_vehicles": 0,
    "active_admins": 0,
    "active_routes": 0,
    "active_trips": 0,
    "trip_allocations": 0,
  };
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadStats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadStats(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      adminName = prefs.getString('session_name') ?? 'Admin';
      adminEmpId = prefs.getString('session_emp_id') ?? '';
    });
  }

  void _loadStats() async {
    final s = await ApiService.getStats();
    if (mounted) {
      setState(() => stats = s);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s.]+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, name.length < 2 ? name.length : 2).toUpperCase();
  }

  void _openProfileDrawer() {
    final initials = _initials(adminName);
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
                            // ✅ Admin name from session (no subtitle)
                            Text(
                              adminName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── Employee ID card ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Employee ID",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    adminEmpId.isNotEmpty ? adminEmpId : "—",
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
                      ),
                      const SizedBox(height: 12),
                      // ── Role card ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.admin_panel_settings,
                                color: Color(0xFF1A2E2A),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Role",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const Text(
                                    "Administrator",
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
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
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
                            icon: const Icon(Icons.logout, color: Colors.white),
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

  void _goto(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadStats(); // Reload stats when returning to dashboard
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(adminName);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Top bar with admin name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/renault_diamond.jpg',
                              height: 34,
                              width: 34,
                              colorBlendMode: BlendMode.darken,
                              color: const Color(0xFFF5F5F5), // Match the scaffold background
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "FLEETCONNECT",
                              style: TextStyle(
                                fontSize: 18,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "Welcome, $adminName",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _openProfileDrawer,
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

                // ✅ Overview card with Active Drivers + Active Vehicles
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
                            "System Overview",
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
                            child: const Text(
                              "Live",
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Fleet Operations",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ✅ Active Drivers + Active Vehicles from /stats
                      Row(
                        children: [
                          Expanded(
                            child: _statPill(
                              Icons.people,
                              "Active Drivers",
                              stats["active_drivers"].toString(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statPill(
                              Icons.local_shipping,
                              "Active Vehicles",
                              stats["active_vehicles"].toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statPill(
                              Icons.assignment_turned_in,
                              "Trip Allocations",
                              stats["trip_allocations"].toString(),
                              onTap: () => _goto(const TripAllocationScreen()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _statPill(
                              Icons.directions_car,
                              "Active Trips",
                              stats["active_trips"].toString(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Attendance Banner Container ──
                GestureDetector(
                  onTap: () => _goto(const AdminAttendanceScreen()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A2E2A), Color(0xFF0D3D2B)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A2E2A).withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.how_to_reg_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ATTENDANCE RECORDS',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'View Driver Punch-In & Out',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
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
                                child: const Text(
                                  'Live Tracking',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    "Management Modules",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _moduleCard(
                      Icons.admin_panel_settings,
                      "Admins",
                      stats["active_admins"].toString(),
                      () => _goto(const AdminsScreen()),
                    ),
                    _moduleCard(
                      Icons.person_search,
                      "Drivers",
                      stats["active_drivers"].toString(),
                      () => _goto(const DriversScreen()),
                    ),
                    _moduleCard(
                      Icons.local_shipping,
                      "Vehicles",
                      stats["active_vehicles"].toString(),
                      () => _goto(const VehiclesScreen()),
                    ),
                    _moduleCard(
                      Icons.alt_route,
                      "Routes",
                      stats["active_routes"].toString(),
                      () => _goto(const RoutesScreen()),
                    ),
                    _moduleCard(
                      Icons.credit_card,
                      "Fuel Cards",
                      stats["active_fuel_cards"]?.toString() ?? "",
                      () => _goto(const FuelCardsScreen()),
                    ),
                    _moduleCard(
                      Icons.assignment_turned_in,
                      "Trips Allocation",
                      stats["trip_allocations"].toString(),
                      () => _goto(const TripAllocationScreen()),
                    ),
                    _moduleCard(
                      Icons.monitor,
                      "Driver Interface",
                      "",
                      () => _goto(const AdminReportsScreen()),
                    ),
                    _moduleCard(
                      Icons.track_changes,
                      "Asset Tracking",
                      "",
                      () => _goto(const AssetTrackingScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statPill(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: pill);
    }

    return pill;
  }

  Widget _moduleCard(
    IconData icon,
    String label,
    String count,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
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
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // ✅ Count badge
            if (count.isNotEmpty && count != "0")
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2E2A),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A2E2A).withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────
Widget _topCountCard(
  String title,
  int count, {
  IconData icon = Icons.bar_chart,
}) {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1A2E2A),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _adminAvatar(String name) {
  final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
  return CircleAvatar(
    radius: 22,
    backgroundColor: const Color(0xFF1A2E2A).withValues(alpha: 0.1),
    child: Text(
      letter,
      style: const TextStyle(
        color: Color(0xFF1A2E2A),
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _iconBox(IconData icon) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: const Color(0xFF1A2E2A).withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Icon(icon, color: const Color(0xFF1A2E2A), size: 22),
);

Widget _statusBadge(bool active) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: active ? Colors.green.shade50 : Colors.red.shade50,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    active ? "Active" : "Inactive",
    style: TextStyle(
      fontSize: 11,
      color: active ? Colors.green.shade700 : Colors.red.shade700,
    ),
  ),
);

void _confirmDelete(BuildContext ctx, String name, VoidCallback onConfirm) {
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Confirm Delete",
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2E2A)),
      ),
      content: Text('Delete "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("Delete", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

// ✅ Bottom bar with real Download XLSX
Widget _bottomBar(
  BuildContext context, {
  required String addLabel,
  required VoidCallback onAdd,
  required VoidCallback onRefresh,
  required String xlsxSheetName,
  required List<String> xlsxHeaders,
  required List<List<String>> Function() xlsxRows,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: Text(
              addLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2E2A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _barBtn(Icons.refresh, "Refresh", onRefresh),
        const SizedBox(width: 8),
        // ✅ Real XLSX download
        _barBtn(Icons.download, "Download XLSX", () async {
          final rows = xlsxRows();
          await downloadAsXlsx(context, xlsxSheetName, xlsxHeaders, rows);
        }),
      ],
    ),
  );
}

Widget _barBtn(IconData icon, String tip, VoidCallback onTap) => Tooltip(
  message: tip,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(icon, color: const Color(0xFF1A2E2A), size: 20),
    ),
  ),
);

Widget _dField(
  TextEditingController ctrl,
  String label,
  IconData icon, {
  TextInputType type = TextInputType.text,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return TextField(
    controller: ctrl,
    keyboardType: type,
    readOnly: readOnly,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    ),
  );
}

Widget _itemCard({
  required Widget leading,
  required String title,
  required String subtitle,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  Widget? badge,
}) {
  return Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              if (badge != null) ...[const SizedBox(height: 4), badge],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.edit_outlined,
            color: Color(0xFF1A2E2A),
            size: 20,
          ),
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: onDelete,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// ADMINS SCREEN
// ─────────────────────────────────────────────
class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});
  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  List data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => loading = true);
    final d = await ApiService.getAdmins();
    setState(() {
      data = d;
      loading = false;
    });
  }

  void _showForm({Map? item}) {
    final e = TextEditingController(text: item?['employee_id'] ?? '');
    final n = TextEditingController(text: item?['name'] ?? '');
    final p = TextEditingController(text: item?['password'] ?? '');
    String role = item?['role'] ?? 'admin';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item == null ? "Add Admin" : "Edit Admin",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2E2A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dField(e, "Employee ID", Icons.badge_outlined),
                const SizedBox(height: 10),
                _dField(n, "Name", Icons.person_outline),
                const SizedBox(height: 10),
                _dField(p, "Password", Icons.lock_outline),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: ["admin", "driver"]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setS(() => role = v!),
                  decoration: InputDecoration(
                    labelText: "Role",
                    prefixIcon: const Icon(
                      Icons.admin_panel_settings,
                      size: 20,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (item == null) {
                    await ApiService.addUser(e.text, n.text, p.text, role);
                  } else {
                    await ApiService.updateUser(
                      item['id'],
                      e.text,
                      n.text,
                      p.text,
                      role,
                    );
                  }
                  if (mounted) Navigator.pop(ctx);
                  _load();
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${err.toString()}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2E2A),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          "Admins",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : data.isEmpty
                ? const Center(child: Text("No admins found"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final a = data[i];
                      return _itemCard(
                        leading: _adminAvatar(a['name'] ?? ''),
                        title: a['name'] ?? '',
                        subtitle: "${a['employee_id']} • ${a['role']}",
                        onEdit: () => _showForm(item: a),
                        onDelete: () =>
                            _confirmDelete(context, a['name'], () async {
                              await ApiService.deleteUser(a['id']);
                              _load();
                            }),
                      );
                    },
                  ),
          ),
          _bottomBar(
            context,
            addLabel: "Add New Admin",
            onAdd: () => _showForm(),
            onRefresh: _load,
            xlsxSheetName: "Admins",
            xlsxHeaders: ["Employee ID", "Name", "Role"],
            xlsxRows: () => data
                .map<List<String>>(
                  (a) => [
                    a['employee_id'] ?? '',
                    a['name'] ?? '',
                    a['role'] ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DRIVERS SCREEN
// ─────────────────────────────────────────────
class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});
  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  List data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => loading = true);
    final d = await ApiService.getDrivers();
    setState(() {
      data = d;
      loading = false;
    });
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try { if (controller.text.isNotEmpty) initial = DateTime.parse(controller.text); } catch (_) {}
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) controller.text = picked.toString().split(' ')[0];
  }

  void _showForm({Map? item}) {
    final e = TextEditingController(text: item?['employee_id'] ?? '');
    final n = TextEditingController(text: item?['name'] ?? '');
    final p = TextEditingController(text: item?['password'] ?? '');
    final ex = TextEditingController(
      text: item?['experience']?.toString() ?? '',
    );
    final l = TextEditingController(text: item?['dl_number'] ?? '');
    final le = TextEditingController(text: _formatDate(item?['dl_expiry']));
    final jd = TextEditingController(text: _formatDate(item?['joining_date']));
    bool active = item?['active'] ?? true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item == null ? "Add Driver" : "Edit Driver",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2E2A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dField(e, "Employee ID", Icons.badge_outlined),
                const SizedBox(height: 10),
                _dField(n, "Name", Icons.person_outline),
                const SizedBox(height: 10),
                _dField(p, "Password", Icons.lock_outline),
                const SizedBox(height: 10),
                _dField(
                  ex,
                  "Experience (years)",
                  Icons.star_outline,
                  type: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _dField(l, "License Number", Icons.credit_card),
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                _dField(
                  le,
                  "License Expiry (YYYY-MM-DD)",
                  Icons.event,
                  readOnly: true,
                  onTap: () => _selectDate(context, le),
                ),
                const SizedBox(height: 10),
                _dField(
                  jd,
                  "Joining Date (YYYY-MM-DD)",
                  Icons.calendar_today,
                  readOnly: true,
                  onTap: () => _selectDate(context, jd),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Active", style: TextStyle(fontSize: 14)),
                    Switch(
                      value: active,
                      activeTrackColor: const Color(0xFF1A2E2A),
                      onChanged: (v) => setS(() => active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (item == null) {
                    await ApiService.addDriver(
                      empId: e.text,
                      name: n.text,
                      password: p.text,
                      experience: double.tryParse(ex.text) ?? 0,
                      dlNumber: l.text,
                      dlExpiry: le.text,
                      joiningDate: jd.text,
                    );
                  } else {
                    await ApiService.updateDriver(
                      id: item['id'],
                      empId: e.text,
                      name: n.text,
                      password: p.text,
                      experience: double.tryParse(ex.text) ?? 0,
                      dlNumber: l.text,
                      dlExpiry: le.text,
                      active: active,
                      joiningDate: jd.text,
                    );
                  }
                  if (mounted) Navigator.pop(ctx);
                  _load();
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${err.toString()}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2E2A),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          "Drivers",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : data.isEmpty
                ? const Center(child: Text("No drivers found"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final d = data[i];
                      return _itemCard(
                        leading: _adminAvatar(d['name'] ?? ''),
                        title: d['name'] ?? '',
                        subtitle: "Employee ID: ${d['employee_id']}",
                        badge: Row(
                          children: [
                            _statusBadge(d['active'] ?? true),
                            if (d['in_active_trip'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "In Trip",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onEdit: () => _showForm(item: d),
                        onDelete: () =>
                            _confirmDelete(context, d['name'], () async {
                              await ApiService.deleteUser(d['id']);
                              _load();
                            }),
                      );
                    },
                  ),
          ),
          _bottomBar(
            context,
            addLabel: "Add New Driver",
            onAdd: () => _showForm(),
            onRefresh: _load,
            xlsxSheetName: "Drivers",
            xlsxHeaders: [
              "Employee ID",
              "Name",
              "Experience",
              "License No",
              "License Expiry",
              "Joining Date",
              "Active",
            ],
            xlsxRows: () => data
                .map<List<String>>(
                  (d) => [
                    d['employee_id'] ?? '',
                    d['name'] ?? '',
                    d['experience']?.toString() ?? '',
                    d['dl_number'] ?? '',
                    d['dl_expiry'] ?? '',
                    d['joining_date'] ?? '',
                    d['active']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// VEHICLES SCREEN
// ─────────────────────────────────────────────
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => loading = true);
    final d = await ApiService.getVehiclesAll();
    setState(() {
      data = d;
      loading = false;
    });
  }

  void _showForm({Map? item}) {
    final vin = TextEditingController(text: item?['vin'] ?? '');
    final br = TextEditingController(text: item?['brand'] ?? '');
    final va = TextEditingController(text: item?['variant'] ?? '');
    final en = TextEditingController(text: item?['engine_type'] ?? '');
    final gb = TextEditingController(text: item?['gearbox_type'] ?? '');
    final pc = TextEditingController(text: item?['project_code'] ?? '');
    final bt = TextEditingController(text: item?['batch'] ?? '');
    final sv = TextEditingController(text: item?['sv_number'] ?? '');
    final pt = TextEditingController(text: item?['powertrain_type'] ?? '');
    bool active = item?['active'] ?? true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item == null ? "Add Vehicle" : "Edit Vehicle",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2E2A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dField(vin, "VIN", Icons.directions_car),
                const SizedBox(height: 10),
                _dField(br, "Brand", Icons.branding_watermark),
                const SizedBox(height: 10),
                _dField(va, "Variant", Icons.category),
                const SizedBox(height: 10),
                _dField(en, "Engine Type", Icons.settings),
                const SizedBox(height: 10),
                _dField(gb, "Gearbox Type", Icons.settings_input_component),
                const SizedBox(height: 10),
                _dField(pc, "Project Code", Icons.code),
                const SizedBox(height: 10),
                _dField(bt, "Batch", Icons.batch_prediction),
                const SizedBox(height: 10),
                _dField(sv, "SV Number", Icons.numbers),
                const SizedBox(height: 10),
                _dField(pt, "Powertrain Type", Icons.bolt),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Active", style: TextStyle(fontSize: 14)),
                    Switch(
                      value: active,
                      activeTrackColor: const Color(0xFF1A2E2A),
                      onChanged: (v) => setS(() => active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (item == null) {
                    await ApiService.addVehicle(
                      vin.text,
                      br.text,
                      va.text,
                      en.text,
                      gb.text,
                      pc.text,
                      bt.text,
                      sv.text,
                      pt.text,
                    );
                  } else {
                    await ApiService.updateVehicle(
                      item['id'],
                      vin.text,
                      br.text,
                      va.text,
                      en.text,
                      gb.text,
                      active,
                      pc.text,
                      bt.text,
                      sv.text,
                      pt.text,
                    );
                  }
                  if (mounted) Navigator.pop(ctx);
                  _load();
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${err.toString()}"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2E2A),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          "Vehicles",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : data.isEmpty
                ? const Center(child: Text("No vehicles found"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final v = data[i];
                      return _itemCard(
                        leading: _iconBox(Icons.directions_car),
                        title: v['vin'] ?? '',
                        subtitle:
                            "${v['brand'] ?? ''} ${v['variant'] ?? ''} • ${v['engine_type'] ?? ''}",
                        badge: _statusBadge(v['active'] ?? true),
                        onEdit: () => _showForm(item: v),
                        onDelete: () =>
                            _confirmDelete(context, v['vin'], () async {
                              await ApiService.deleteVehicle(v['id']);
                              _load();
                            }),
                      );
                    },
                  ),
          ),
          _bottomBar(
            context,
            addLabel: "Add New Vehicle",
            onAdd: () => _showForm(),
            onRefresh: _load,
            xlsxSheetName: "Vehicles",
            xlsxHeaders: [
              "ID",
              "VIN",
              "Brand",
              "Variant",
              "Engine",
              "Gearbox",
              "Project Code",
              "Batch",
              "SV No",
              "Powertrain",
              "Active",
            ],
            xlsxRows: () => data
                .map<List<String>>(
                  (v) => [
                    v['id']?.toString() ?? '',
                    v['vin'] ?? '',
                    v['brand'] ?? '',
                    v['variant'] ?? '',
                    v['engine_type'] ?? '',
                    v['gearbox_type'] ?? '',
                    v['project_code'] ?? '',
                    v['batch'] ?? '',
                    v['sv_number'] ?? '',
                    v['powertrain_type'] ?? '',
                    v['active']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ROUTES SCREEN
// ─────────────────────────────────────────────
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});
  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  List data = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => loading = true);
    final d = await ApiService.getRoutesAll();
    setState(() {
      data = d;
      loading = false;
    });
  }

  void _showForm({Map? item}) {
    final nm = TextEditingController(text: item?['route_name'] ?? '');
    final km = TextEditingController(
      text: item?['kms_coverage']?.toString() ?? '',
    );
    String circuit = item?['circuit_type'] ?? 'Highway';
    bool active = item?['active'] ?? true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item == null ? "Add Route" : "Edit Route",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2E2A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dField(nm, "Route Name", Icons.route),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: circuit,
                  items: ["Highway", "Hill", "Rough", "City"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setS(() => circuit = v!),
                  decoration: InputDecoration(
                    labelText: "Circuit Type",
                    prefixIcon: const Icon(
                      Icons.map,
                      size: 20,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _dField(
                  km,
                  "KMS Coverage",
                  Icons.social_distance,
                  type: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Active", style: TextStyle(fontSize: 14)),
                    Switch(
                      value: active,
                      activeTrackColor: const Color(0xFF1A2E2A),
                      onChanged: (v) => setS(() => active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (item == null) {
                  await ApiService.addRoute(
                    nm.text,
                    circuit,
                    int.tryParse(km.text) ?? 0,
                  );
                } else {
                  await ApiService.updateRoute(
                    item['id'],
                    nm.text,
                    circuit,
                    int.tryParse(km.text) ?? 0,
                    active,
                  );
                }
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2E2A),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          "Routes",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : data.isEmpty
                ? const Center(child: Text("No routes found"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final r = data[i];
                      return _itemCard(
                        leading: _iconBox(Icons.route),
                        title: r['route_name'] ?? '',
                        subtitle:
                            "${r['circuit_type'] ?? ''} • ${r['kms_coverage'] ?? 0} km",
                        badge: _statusBadge(r['active'] ?? true),
                        onEdit: () => _showForm(item: r),
                        onDelete: () =>
                            _confirmDelete(context, r['route_name'], () async {
                              await ApiService.deleteRoute(r['id']);
                              _load();
                            }),
                      );
                    },
                  ),
          ),
          _bottomBar(
            context,
            addLabel: "Add New Route",
            onAdd: () => _showForm(),
            onRefresh: _load,
            xlsxSheetName: "Routes",
            xlsxHeaders: [
              "ID",
              "Route Name",
              "Circuit Type",
              "KMS Coverage",
              "Active",
            ],
            xlsxRows: () => data
                .map<List<String>>(
                  (r) => [
                    r['id']?.toString() ?? '',
                    r['route_name'] ?? '',
                    r['circuit_type'] ?? '',
                    r['kms_coverage']?.toString() ?? '',
                    r['active']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FUEL CARDS SCREEN
// ─────────────────────────────────────────────
class FuelCardsScreen extends StatefulWidget {
  const FuelCardsScreen({super.key});
  @override
  State<FuelCardsScreen> createState() => _FuelCardsScreenState();
}

class _FuelCardsScreenState extends State<FuelCardsScreen> {
  List data = [], vehicles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => loading = true);
    final fc = await ApiService.getFuelCardsAll();
    final v = await ApiService.getVehiclesAll();
    setState(() {
      data = fc;
      vehicles = v;
      loading = false;
    });
  }

  void _showForm({Map? item}) {
    final fc = TextEditingController(text: item?['fc_number'] ?? '');
    int? selV = item?['vehicle_id'];
    bool active = item?['active'] ?? true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            item == null ? "Add Fuel Card" : "Edit Fuel Card",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2E2A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dField(fc, "FC Number", Icons.credit_card),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: selV,
                  hint: const Text("Assign to Vehicle (optional)"),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Unassigned"),
                    ),
                    ...vehicles.map(
                      (v) => DropdownMenuItem<int?>(
                        value: v['id'],
                        child: Text(v['vin'] ?? ''),
                      ),
                    ),
                  ],
                  onChanged: (v) => setS(() => selV = v),
                  decoration: InputDecoration(
                    labelText: "Vehicle VIN",
                    prefixIcon: const Icon(
                      Icons.directions_car,
                      size: 20,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Active", style: TextStyle(fontSize: 14)),
                    Switch(
                      value: active,
                      activeTrackColor: const Color(0xFF1A2E2A),
                      onChanged: (v) => setS(() => active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (item == null) {
                  await ApiService.addFuelCard(fc.text, selV);
                } else {
                  await ApiService.updateFuelCard(
                    item['id'],
                    fc.text,
                    selV,
                    active,
                  );
                }
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2E2A),
              ),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          "Fuel Cards",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : data.isEmpty
                ? const Center(child: Text("No fuel cards found"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final f = data[i];
                      return _itemCard(
                        leading: _iconBox(Icons.credit_card),
                        title: f['fc_number'] ?? '',
                        subtitle: f['vin'] != null
                            ? "Assigned: ${f['vin']}"
                            : "Unassigned",
                        badge: _statusBadge(f['active'] ?? true),
                        onEdit: () => _showForm(item: f),
                        onDelete: () =>
                            _confirmDelete(context, f['fc_number'], () async {
                              await ApiService.deleteFuelCard(f['id']);
                              _load();
                            }),
                      );
                    },
                  ),
          ),
          _bottomBar(
            context,
            addLabel: "Add Fuel Card",
            onAdd: () => _showForm(),
            onRefresh: _load,
            xlsxSheetName: "FuelCards",
            xlsxHeaders: ["FC Number", "VIN", "Active"],
            xlsxRows: () => data
                .map<List<String>>(
                  (f) => [
                    f['fc_number'] ?? '',
                    f['vin'] ?? 'Unassigned',
                    f['active']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRIP ALLOCATION SCREEN
// ─────────────────────────────────────────────
class TripAllocationScreen extends StatefulWidget {
  const TripAllocationScreen({super.key});
  @override
  State<TripAllocationScreen> createState() => _TripAllocationScreenState();
}

class _TripAllocationScreenState extends State<TripAllocationScreen> {
  List data = [], drivers = [], vehicles = [], routes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => loading = true);
    final al = await ApiService.getTripAllocations();
    final dr = await ApiService.getDrivers();
    final ve = await ApiService.getVehiclesAll();
    final ro = await ApiService.getRoutesAll();
    setState(() {
      data = al;
      drivers = dr;
      vehicles = ve;
      routes = ro;
      loading = false;
    });
  }

  void _showForm() {
    int? sd1, sd2, sd3, sv, sr;
    int numDrivers = 1;
    String? ss;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final availableDrivers = drivers.where((d) => d['in_active_trip'] != true).toList();
          
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Assign Trip",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2E2A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: numDrivers,
                    items: [1, 2, 3]
                        .map((n) => DropdownMenuItem(value: n, child: Text("$n Driver${n > 1 ? 's' : ''}")))
                        .toList(),
                    onChanged: (v) => setS(() => numDrivers = v!),
                    decoration: InputDecoration(
                      labelText: "Number of Drivers",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Driver 1
                  DropdownButtonFormField<int>(
                    value: sd1,
                    hint: const Text("Select Driver 1"),
                    items: availableDrivers.map((d) => DropdownMenuItem<int>(
                      value: d['id'],
                      child: Text("${d['employee_id']} - ${d['name']}"),
                    )).toList(),
                    onChanged: (v) => setS(() => sd1 = v),
                    decoration: InputDecoration(
                      labelText: "Driver 1",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  
                  if (numDrivers >= 2) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: sd2,
                      hint: const Text("Select Driver 2"),
                      items: availableDrivers.where((d) => d['id'] != sd1).map((d) => DropdownMenuItem<int>(
                        value: d['id'],
                        child: Text("${d['employee_id']} - ${d['name']}"),
                      )).toList(),
                      onChanged: (v) => setS(() => sd2 = v),
                      decoration: InputDecoration(
                        labelText: "Driver 2",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  
                  if (numDrivers >= 3) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: sd3,
                      hint: const Text("Select Driver 3"),
                      items: availableDrivers.where((d) => d['id'] != sd1 && d['id'] != sd2).map((d) => DropdownMenuItem<int>(
                        value: d['id'],
                        child: Text("${d['employee_id']} - ${d['name']}"),
                      )).toList(),
                      onChanged: (v) => setS(() => sd3 = v),
                      decoration: InputDecoration(
                        labelText: "Driver 3",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: sv,
                    hint: const Text("Select Vehicle"),
                    items: vehicles.map((v) => DropdownMenuItem<int>(
                      value: v['id'],
                      child: Text(v['vin'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setS(() => sv = v),
                    decoration: InputDecoration(
                      labelText: "Vehicle VIN",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: sr,
                    hint: const Text("Select Route"),
                    items: routes.map((r) => DropdownMenuItem<int>(
                      value: r['id'],
                      child: Text(r['route_name'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setS(() => sr = v),
                    decoration: InputDecoration(
                      labelText: "Route",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: ss,
                    hint: const Text("Select Shift"),
                    items: ["Shift-1", "Shift-2"]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setS(() => ss = v),
                    decoration: InputDecoration(
                      labelText: "Shift",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (sd1 == null || sv == null || sr == null || ss == null) return;
                  if (numDrivers >= 2 && sd2 == null) return;
                  if (numDrivers >= 3 && sd3 == null) return;
                  
                  Navigator.pop(ctx);
                  try {
                    await ApiService.assignTrip(
                      driverId: sd1!,
                      driverId2: sd2,
                      driverId3: sd3,
                      vehicleId: sv!,
                      routeId: sr!,
                      shift: ss!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Trip assigned successfully!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    _load();
                  } catch (e) {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Assignment Failed"),
                          content: Text(e.toString().replaceAll("Exception: ", "")),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Dismiss"),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                ),
                child: const Text("Assign", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
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
        title: const Text(
          "Trip Allocation",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No allocations yet",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: data.length,
                    itemBuilder: (_, i) {
                      final a = data[i];
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            _iconBox(Icons.assignment),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        a['driver_name'] ?? '—',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      if (a['in_active_trip'] == true) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            "ACTIVE",
                                            style: TextStyle(
                                              color: Colors.orange.shade900,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    "${a['employee_id'] ?? ''} • ${a['vin'] ?? '—'} • ${a['route_name'] ?? '—'} • ${a['shift'] ?? ''}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: a['status'] == 'ACCEPTED'
                                    ? Colors.green.shade50
                                    : (a['status'] == 'CANCELLED' ? Colors.red.shade50 : Colors.blue.shade50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                a['status']?.toUpperCase() ?? "ASSIGNED",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: a['status'] == 'ACCEPTED'
                                      ? Colors.green
                                      : (a['status'] == 'CANCELLED' ? Colors.red : Colors.blue),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _confirmDelete(
                                context,
                                "${a['driver_name']} - ${a['vin']}",
                                () async {
                                  await ApiService.deleteAllocation(a['id']);
                                  _load();
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _bottomBar(
            context,
            addLabel: "Assign Trip",
            onAdd: _showForm,
            onRefresh: _load,
            xlsxSheetName: "TripAllocations",
            xlsxHeaders: [
              "Driver",
              "Employee ID",
              "VIN",
              "Route",
              "Shift",
              "Date",
            ],
            xlsxRows: () => data
                .map<List<String>>(
                  (a) => [
                    a['driver_name'] ?? '',
                    a['employee_id'] ?? '',
                    a['vin'] ?? '',
                    a['route_name'] ?? '',
                    a['shift'] ?? '',
                    a['date']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REPORTS SCREEN
// ─────────────────────────────────────────────
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final List<String> _tabs = ["Trips", "Fuel", "Issues", "Repair"];
  List trips = [], fuel = [], issues = [], repairs = [], assets = [];
  bool loading = true;
  int _currentIndex = 0;

  // Track visibility of old entries for each tab
  bool showOldTrips = false;
  bool showOldFuel = false;
  bool showOldIssues = false;
  bool showOldRepairs = false;
  bool showOldAssets = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() => _currentIndex = _tab.index);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _load() async {
    setState(() => loading = true);
    final t = await ApiService.getAllTrips();
    final f = await ApiService.getAllFuel();
    final i = await ApiService.getAllIssues();
    final r = await ApiService.getAllRepairs();
    final a = await ApiService.getAllAssets();

    if (mounted) {
      debugPrint("DEBUG: Trips count: ${t.length}");
      debugPrint("DEBUG: Fuel count: ${f.length}");
      debugPrint("DEBUG: Issues count: ${i.length}");
      debugPrint("DEBUG: Repairs count: ${r.length}");
      debugPrint("DEBUG: Assets count: ${a.length}");
      setState(() {
        trips = t;
        fuel = f;
        issues = i;
        repairs = r;
        assets = a;
        loading = false;
      });
    }
  }

  void _downloadCurrent() {
    switch (_currentIndex) {
      case 0:
        _downloadTab(
          "Trips",
          [
            "Date",
            "Start Time",
            "End Time",
            "Driver",
            "Emp ID",
            "VIN",
            "Route",
            "Shift",
            "Start ODO",
            "End ODO",
            "Status",
          ],
          trips
              .map<List<String>>(
                (t) => [
                  t['report_date'] ?? '',
                  _formatTime(t['start_time']),
                  _formatTime(t['end_time']),
                  t['driver_name'] ?? '',
                  t['employee_id'] ?? '',
                  t['vin'] ?? '',
                  t['route_name'] ?? '',
                  t['shift'] ?? '',
                  t['start_odo']?.toString() ?? '',
                  t['end_odo']?.toString() ?? '',
                  t['trip_status'] ?? '',
                ],
              )
              .toList(),
        );
        break;
      case 1:
        _downloadTab(
          "Fuel",
          [
            "Date",
            "Time",
            "Driver",
            "Emp ID",
            "VIN",
            "FC Used",
            "Litres",
            "Amount",
            "Type",
          ],
          fuel
              .map<List<String>>(
                (f) => [
                  f['report_date'] ?? '',
                  _formatTime(f['created_at']),
                  f['driver_name'] ?? '',
                  f['employee_id'] ?? '',
                  f['vin'] ?? '',
                  f['fuel_card_number'] ?? '',
                  f['litres']?.toString() ?? '',
                  f['amount']?.toString() ?? '',
                  f['fuel_type'] ?? '',
                ],
              )
              .toList(),
        );
        break;
      case 2:
        _downloadTab(
          "Issues",
          ["Date", "Time", "Driver", "Emp ID", "VIN", "ODO", "Description"],
          issues
              .map<List<String>>(
                (i) => [
                  i['report_date'] ?? '',
                  _formatTime(i['created_at']),
                  i['driver_name'] ?? '',
                  i['employee_id'] ?? '',
                  i['vehicle_vin'] ?? '',
                  i['odo_entry']?.toString() ?? '',
                  i['description'] ?? '',
                ],
              )
              .toList(),
        );
        break;
      case 3:
        _downloadTab(
          "Repairs",
          [
            "Date",
            "Time",
            "VIN",
            "Logged By",
            "Requested By",
            "Performed By",
            "Current ODO",
            "Details",
            "Additional Details",
          ],
          repairs
              .map<List<String>>(
                (r) => [
                  r['report_date'] ?? '',
                  _formatTime(r['created_at']),
                  r['vin'] ?? '',
                  r['driver_name'] ?? '',
                  r['requested_by'] ?? '',
                  r['performed_by'] ?? '',
                  r['odo_reading']?.toString() ?? '',
                  r['repair_details'] ?? '',
                  r['notes'] ?? '',
                ],
              )
              .toList(),
        );
        break;
    }
  }

  void _downloadTab(
    String name,
    List<String> headers,
    List<List<String>> rows,
  ) {
    downloadAsXlsx(context, name, headers, rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Driver Interface v1.1",
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "Activity & Performance Reports",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: const Color(0xFF1A2E2A),
          unselectedLabelColor: Colors.grey.shade400,
          indicatorColor: const Color(0xFF1A2E2A),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
            )
          : TabBarView(
              controller: _tab,
              children: [
                _smartList(
                  trips,
                  _tripCard,
                  showOldTrips,
                  (v) => setState(() => showOldTrips = v),
                ),
                _smartList(
                  fuel,
                  _fuelCard,
                  showOldFuel,
                  (v) => setState(() => showOldFuel = v),
                ),
                _smartList(
                  issues,
                  _issueCard,
                  showOldIssues,
                  (v) => setState(() => showOldIssues = v),
                ),
                _smartList(
                  repairs,
                  _repairCard,
                  showOldRepairs,
                  (v) => setState(() => showOldRepairs = v),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text(
                  "Refresh Data",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _barBtn(Icons.download, "Download XLSX", _downloadCurrent),
          ],
        ),
      ),
    );
  }

  Widget _smartList(
    List data,
    Widget Function(Map) fn,
    bool showOld,
    Function(bool) onToggle,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              "No data available",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Sort data by date descending
    final sortedData = List.from(data)
      ..sort((a, b) {
        final da = b['report_date'] ?? '';
        final db = a['report_date'] ?? '';
        return da.toString().compareTo(db.toString());
      });

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final todayEntries = sortedData.where((item) {
      final dr = item['report_date'] ?? '';
      return dr.toString().contains(todayStr);
    }).toList();

    // Union of Today's entries and the Last 5 overall entries
    final last5 = sortedData.take(5).toList();
    final visibleSet = <dynamic>{...todayEntries, ...last5};
    final visibleEntries = visibleSet.toList();

    // Sort visible ones again to ensure chronological order
    visibleEntries.sort((a, b) {
      final da = b['report_date'] ?? '';
      final db = a['report_date'] ?? '';
      return da.toString().compareTo(db.toString());
    });

    final oldEntries = sortedData
        .where((item) => !visibleSet.contains(item))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (visibleEntries.isNotEmpty) ...[
          _sectionHeader(
            "RECENT ACTIVITY",
            visibleEntries.length,
            isToday: true,
          ),
          const SizedBox(height: 12),
          ...visibleEntries.map((e) => fn(e as Map)),
          const SizedBox(height: 20),
        ],

        if (oldEntries.isNotEmpty) ...[
          if (!showOld) ...[
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => onToggle(true),
                icon: const Icon(Icons.history, size: 18),
                label: Text("VIEW HISTORY (${oldEntries.length})"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A2E2A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader("ARCHIVE", oldEntries.length, isToday: false),
                TextButton(
                  onPressed: () => onToggle(false),
                  child: const Text(
                    "HIDE ARCHIVE",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...oldEntries.map((e) => fn(e as Map)),
            const SizedBox(height: 30),
          ],
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count, {required bool isToday}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: isToday ? const Color(0xFF1A2E2A) : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: isToday ? const Color(0xFF1A1A2E) : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fancyCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? headerCorner,
    Widget? bottomWidget,
    required Map<String, String> fields,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2E2A).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF1A2E2A), size: 18),
                ),
                const SizedBox(width: 12),
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
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                ?headerCorner,
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: fields.entries.map((e) {
                    bool isFullWidth =
                        e.key.toLowerCase().contains("description") ||
                        e.key.toLowerCase().contains("details") ||
                        e.key.toLowerCase().contains("route");
                    return SizedBox(
                      width: isFullWidth
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          if (bottomWidget != null) bottomWidget,
        ],
      ),
    );
  }

  Widget _tripCard(Map t) => _fancyCard(
    icon: Icons.person,
    title: t['driver_name'] ?? 'Unknown Driver',
    subtitle: "Emp ID: ${t['employee_id'] ?? '—'}",
    headerCorner: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t['trip_status'] == 'STARTED'
            ? Colors.green.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        t['trip_status'] ?? '—',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: t['trip_status'] == 'STARTED'
              ? Colors.green.shade700
              : Colors.blue.shade700,
        ),
      ),
    ),
    fields: {
      "Date": t['report_date'] ?? '—',
      "Start Time": _formatTime(t['start_time']),
      "End Time": _formatTime(t['end_time']),
      "VIN": t['vin'] ?? '—',
      "Route": t['route_name'] ?? '—',
      "Shift": t['shift'] ?? '—',
      "Start ODO": t['start_odo']?.toString() ?? '—',
      "End ODO": t['end_odo']?.toString() ?? '—',
    },
  );

  Widget _fuelCard(Map f) => _fancyCard(
    icon: Icons.local_gas_station,
    title: f['driver_name'] ?? 'Unknown Driver',
    subtitle: "Emp ID: ${f['employee_id'] ?? '—'}",
    fields: {
      "Record Date":
          "${f['report_date'] ?? '—'} ${_formatTime(f['created_at'])}",
      "VIN": f['vin'] ?? '—',
      "FC Used": f['fuel_card_number'] ?? '—',
      "Litres": f['litres']?.toString() ?? '—',
      "Amount": "Rs. ${f['amount'] ?? '—'}",
      "Type": f['fuel_type'] ?? '—',
    },
    bottomWidget:
        (f['bill_image'] != null && f['bill_image'].toString().isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "FUEL RECEIPT",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _viewFullImage(f['bill_image']),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      image: DecorationImage(
                        image: MemoryImage(base64Decode(f['bill_image'])),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Tap to View",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : null,
  );

  void _viewFullImage(String base64) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.memory(base64Decode(base64)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueCard(Map i) => _fancyCard(
    icon: Icons.report_problem,
    title: i['driver_name'] ?? 'Unknown Driver',
    subtitle: "Emp ID: ${i['employee_id'] ?? '—'}",
    fields: {
      "Reported At":
          "${i['report_date'] ?? '—'} ${_formatTime(i['created_at'])}",
      "VIN": i['vehicle_vin'] ?? '—',
      "ODO": i['odo_entry']?.toString() ?? '—',
      "Issue Description": i['description'] ?? '—',
    },
  );

  Widget _repairCard(Map r) => _fancyCard(
    icon: Icons.build,
    title: "Vehicle Repair",
    subtitle: "VIN: ${r['vin'] ?? '—'}",
    fields: {
      "Service Date":
          "${r['report_date'] ?? '—'} ${_formatTime(r['created_at'])}",
      "Logged By": r['driver_name'] ?? '—',
      "Requested By": r['requested_by'] ?? '—',
      "Performed By": r['performed_by'] ?? '—',
      "Current Odo": "${r['odo_reading'] ?? '—'} km",
      "Repair Details": r['repair_details'] ?? '—',
      "Additional Details": r['notes'] ?? '—',
      "Part Replace": r['part_replacement'] == true ? 'Yes' : 'No',
      "Part Removal": r['part_removal_refit'] == true ? 'Yes' : 'No',
      "SW Flash": r['software_flashing'] == true ? 'Yes' : 'No',
    },
  );

  Widget _assetCard(Map a) => _fancyCard(
    icon: Icons.track_changes,
    title: a['category'] ?? 'Asset Track',
    subtitle: "VIN: ${a['vin'] ?? '—'}",
    fields: {
      "Date": "${a['report_date'] ?? '—'} ${_formatTime(a['created_at'])}",
      "Asset No": a['asset_number'] ?? '—',
      "Requested By": a['requested_by'] ?? '—',
      "Fitted By": a['fitted_by'] ?? '—',
      "ODO at Installation": "${a['odo_reading'] ?? '—'} km",
    },
  );
}

// ─────────────────────────────────────────────
// ASSET TRACKING SCREEN  (category list)
// ─────────────────────────────────────────────
class AssetTrackingScreen extends StatelessWidget {
  const AssetTrackingScreen({super.key});

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Asset Tracking",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
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
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isTCPlate = cat['isTCPlate'] == true;
                  return GestureDetector(
                    onTap: () {
                      if (isTCPlate) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminTCPlateScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminAssetFormScreen(
                              categoryTitle: cat['title'],
                              categoryIcon: cat['icon'] as IconData,
                              categoryColor: cat['color'] as Color,
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
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (cat['color'] as Color).withValues(
                                alpha: 0.1,
                              ),
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
    );
  }
}

// ─────────────────────────────────────────────
// ADMIN ASSET FORM SCREEN  (6 standard categories)
// ─────────────────────────────────────────────
class AdminAssetFormScreen extends StatefulWidget {
  final String categoryTitle;
  final IconData categoryIcon;
  final Color categoryColor;

  const AdminAssetFormScreen({
    super.key,
    required this.categoryTitle,
    required this.categoryIcon,
    required this.categoryColor,
  });

  @override
  State<AdminAssetFormScreen> createState() => _AdminAssetFormScreenState();
}

class _AdminAssetFormScreenState extends State<AdminAssetFormScreen> {
  List vehicles = [];
  List assets = [];
  List openAssets = [];
  int? selectedVehicle;
  int adminId = 0;
  bool isSubmitting = false;
  bool loadingHistory = true;
  bool isLoadingOpen = false;
  DateTime? selectedDate = DateTime.now();

  final TextEditingController requestedByController = TextEditingController();
  final TextEditingController fittedByController = TextEditingController();
  final TextEditingController assetNumberController = TextEditingController();
  final TextEditingController odoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSession();
    _refresh();
  }

  void _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        adminId = prefs.getInt('session_id') ?? 0;
      });
    }
  }

  void _refresh() {
    _loadVehicles();
    _loadHistory();
    _loadOpenAssets();
  }

  void _loadVehicles() async {
    final v = await ApiService.getVehicles();
    if (mounted) setState(() => vehicles = v);
  }

  void _loadOpenAssets() async {
    setState(() => isLoadingOpen = true);
    try {
      final all = await ApiService.getAllAssets();
      if (mounted) {
        setState(() {
          openAssets = all
              .where((a) =>
                  a['category'] == widget.categoryTitle && a['status'] == 'OPEN')
              .toList();
          isLoadingOpen = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading open assets: $e");
      if (mounted) setState(() => isLoadingOpen = false);
    }
  }

  void _loadHistory() async {
    setState(() => loadingHistory = true);
    final all = await ApiService.getAllAssets();
    // Filter by this category
    final mine =
        all.where((a) => a['category'] == widget.categoryTitle).toList();
    if (mounted) {
      setState(() {
        assets = mine;
        loadingHistory = false;
      });
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

  void _showResultDialog(String title, bool isSuccess) {
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

  void _closeAsset(int id) async {
    try {
      await ApiService.closeAsset(id);
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Asset Closed successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to close: $e")),
      );
    }
  }

  void submitAsset() async {
    if (selectedVehicle == null) {
      _showResultDialog("Please select a VIN !", false);
      return;
    }
    if (assetNumberController.text.trim().isEmpty) {
      _showResultDialog("Please enter asset number !", false);
      return;
    }
    if (selectedDate == null) {
      _showResultDialog("Please select installation date !", false);
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await ApiService.addAsset(
        driverId: adminId,
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
      _refresh();
      _showResultDialog("Asset Logged! 📦", true);
    } catch (e) {
      setState(() => isSubmitting = false);
      if (!mounted) return;
      _showResultDialog(e.toString().replaceAll("Exception: ", ""), false);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.blue),
            onPressed: () {
              downloadAsXlsx(
                context,
                widget.categoryTitle,
                [
                  "Date",
                  "Time",
                  "VIN",
                  "Asset No",
                  "Requested By",
                  "Fitted By",
                  "ODO",
                ],
                assets
                    .map<List<String>>(
                      (a) => [
                        a['report_date'] ?? '',
                        _formatTime(a['created_at']),
                        a['vin'] ?? '',
                        a['asset_number'] ?? '',
                        a['requested_by'] ?? '',
                        a['fitted_by'] ?? '',
                        a['odo_reading']?.toString() ?? '',
                      ],
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── OPEN ASSETS SECTION ──
            if (openAssets.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in,
                      color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Active Assignments (OPEN)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...openAssets.map((asset) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "VIN: ${asset['vin'] ?? 'Unknown'}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              "Asset #: ${asset['asset_number']}",
                              style: TextStyle(
                                  color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _closeAsset(asset['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 32),
                        ),
                        child: const Text("CLOSE",
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 32),
            ],

            const Text(
              "New Allocation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 20),

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
                  items: vehicles
                      .map<DropdownMenuItem<int>>(
                        (v) => DropdownMenuItem<int>(
                          value: v['id'],
                          child: Text(
                            v['vin'] ?? "",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 40),
            const Text(
              "Recent History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            if (loadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (assets.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No records found",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final a = assets[idx];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              a['vin'] ?? "—",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "${a['report_date']} ${_formatTime(a['created_at'])}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _hRow("Asset No", a['asset_number'] ?? "—"),
                        _hRow("Req By", a['requested_by'] ?? "—"),
                        _hRow("Fitted By", a['fitted_by'] ?? "—"),
                        _hRow("ODO", "${a['odo_reading'] ?? '—'} km"),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _hRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// ADMIN TC PLATE SCREEN
// ─────────────────────────────────────────────
class AdminTCPlateScreen extends StatefulWidget {
  const AdminTCPlateScreen({super.key});
  @override
  State<AdminTCPlateScreen> createState() => _AdminTCPlateScreenState();
}

class _AdminTCPlateScreenState extends State<AdminTCPlateScreen> {
  List vehicles = [];
  List assets = [];
  List openAssets = [];
  int? selectedVehicle;
  int adminId = 0;
  bool isSubmitting = false;
  bool loadingHistory = true;
  bool isLoadingOpen = false;
  DateTime? selectedDate = DateTime.now();
  final TextEditingController tcPlateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSession();
    _refresh();
  }

  void _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        adminId = prefs.getInt('session_id') ?? 0;
      });
    }
  }

  void _refresh() {
    _loadVehicles();
    _loadHistory();
    _loadOpenAssets();
  }

  void _loadVehicles() async {
    final v = await ApiService.getVehicles();
    if (mounted) setState(() => vehicles = v);
  }

  void _loadOpenAssets() async {
    setState(() => isLoadingOpen = true);
    try {
      final all = await ApiService.getAllAssets();
      if (mounted) {
        setState(() {
          openAssets = all
              .where((a) =>
                  a['category'] == "TC Plate Allocation" && a['status'] == 'OPEN')
              .toList();
          isLoadingOpen = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading open assets: $e");
      if (mounted) setState(() => isLoadingOpen = false);
    }
  }

  void _loadHistory() async {
    setState(() => loadingHistory = true);
    final all = await ApiService.getAllAssets();
    final mine =
        all.where((a) => a['category'] == "TC Plate Allocation").toList();
    if (mounted) {
      setState(() {
        assets = mine;
        loadingHistory = false;
      });
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

  void _showResultDialog(String title, bool isSuccess) {
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

  void _closeAsset(int id) async {
    try {
      await ApiService.closeAsset(id);
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("TC Plate Allocation Closed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to close: $e")),
      );
    }
  }

  void submitTCPlate() async {
    if (tcPlateController.text.trim().isEmpty) {
      _showResultDialog("Please enter TC Plate number !", false);
      return;
    }
    if (selectedVehicle == null) {
      _showResultDialog("Please select a VIN !", false);
      return;
    }
    if (selectedDate == null) {
      _showResultDialog("Please select allocation date !", false);
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await ApiService.addAsset(
        driverId: adminId,
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
      _refresh();
      _showResultDialog("TC Plate Allocated! ✅", true);
    } catch (e) {
      setState(() => isSubmitting = false);
      if (!mounted) return;
      _showResultDialog(e.toString().replaceAll("Exception: ", ""), false);
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.orange),
            onPressed: () {
              downloadAsXlsx(
                context,
                "TC Plate Allocation",
                ["Date", "Time", "VIN", "TC Plate No"],
                assets
                    .map<List<String>>(
                      (a) => [
                        a['report_date'] ?? '',
                        _formatTime(a['created_at']),
                        a['vin'] ?? '',
                        a['asset_number'] ?? '',
                      ],
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── OPEN ASSETS SECTION ──
            if (openAssets.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in,
                      color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Active TC Plates (OPEN)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...openAssets.map((asset) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "VIN: ${asset['vin'] ?? 'Unknown'}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              "TC Plate: ${asset['asset_number']}",
                              style: TextStyle(
                                  color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _closeAsset(asset['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(60, 32),
                        ),
                        child: const Text("CLOSE",
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 32),
            ],

            Row(
              children: [
                Container(width: 4, height: 20, color: const Color(0xFFE65100)),
                const SizedBox(width: 8),
                const Text(
                  "New Allocation",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                  items: vehicles
                      .map<DropdownMenuItem<int>>(
                        (v) => DropdownMenuItem<int>(
                          value: v['id'],
                          child: Text(
                            v['vin'] ?? "",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedVehicle = value),
                ),
              ),
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 40),
            const Text(
              "Recent Allocation History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            if (loadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (assets.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No records found",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final a = assets[idx];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              a['vin'] ?? "—",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "${a['report_date']} ${_formatTime(a['created_at'])}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _hRow("TC Plate No", a['asset_number'] ?? "—"),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _hRow(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// ADMIN ATTENDANCE SCREEN
// ─────────────────────────────────────────────
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<dynamic> attendanceRecords = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final dateStr =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final data = await ApiService.getAllAttendance(date: dateStr);
    setState(() {
      attendanceRecords = data;
      isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
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
              onSurface: Color(0xFF1A2E2A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadData();
    }
  }

  String _fmtTime(dynamic val) {
    if (val == null) return "—";
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "—";
    }
  }

  void _downloadReport() {
    final headers = [
      "Driver Name",
      "Employee ID",
      "Punch In",
      "Punch Out",
      "Date",
    ];
    final rows = attendanceRecords
        .map<List<String>>(
          (rec) => [
            rec['driver_name'] ?? "Unknown",
            rec['employee_id'] ?? "--",
            _fmtTime(rec['punch_in']),
            _fmtTime(rec['punch_out']),
            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
          ],
        )
        .toList();
    downloadAsXlsx(context, "Attendance", headers, rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          "Attendance Records",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _selectDate(context),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Stats summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _statItem(
                  "Present",
                  attendanceRecords.length.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _statItem(
                  "Date",
                  "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  const Color(0xFF1A2E2A),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                  )
                : attendanceRecords.isEmpty
                ? const Center(child: Text("No attendance records found"))
                : ListView.builder(
                    itemCount: attendanceRecords.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final rec = attendanceRecords[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(
                                0xFF1A2E2A,
                              ).withValues(alpha: 0.1),
                              child: Text(
                                rec['driver_name']?[0] ?? "D",
                                style: const TextStyle(
                                  color: Color(0xFF1A2E2A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rec['driver_name'] ?? "Unknown",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    "ID: ${rec['employee_id'] ?? '--'}",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _timeBadge(
                                  "IN",
                                  _fmtTime(rec['punch_in']),
                                  Colors.green,
                                ),
                                const SizedBox(height: 4),
                                _timeBadge(
                                  "OUT",
                                  _fmtTime(rec['punch_out']),
                                  Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text(
                  "Refresh Reports v1.1",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2E2A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _barBtn(Icons.download, "Download XLSX", _downloadReport),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBadge(String label, String time, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
