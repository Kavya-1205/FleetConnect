import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int driverId;
  final String driverName;

  const AttendanceScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // State
  bool isLoading = true;
  bool isProcessing = false;
  Map<String, dynamic>? attendance;

  // Live clock
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendance();

    // Live clock
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    try {
      setState(() => isLoading = true);
      final result = await ApiService.getTodayAttendance(widget.driverId);
      if (mounted)
        setState(() {
          attendance = result;
          isLoading = false;
        });
    } catch (e) {
      debugPrint("Error loading attendance: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool get _isPunchedIn =>
      attendance != null && attendance!['punch_in'] != null;
  bool get _isPunchedOut =>
      attendance != null && attendance!['punch_out'] != null;

  String _fmt(dynamic val) {
    if (val == null) return '--:--';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _totalHours() {
    if (attendance == null) return '--';
    final inTime = attendance!['punch_in'];
    final outTime = attendance!['punch_out'];
    if (inTime == null) return '--';
    final start = DateTime.parse(inTime.toString()).toLocal();
    final end = outTime != null
        ? DateTime.parse(outTime.toString()).toLocal()
        : _now;
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Future<void> _handlePunch() async {
    try {
      setState(() => isProcessing = true);
      Map<String, dynamic>? result;
      if (!_isPunchedIn) {
        result = await ApiService.punchIn(widget.driverId);
      } else if (!_isPunchedOut) {
        result = await ApiService.punchOut(widget.driverId);
      }
      if (result != null) {
        setState(() {
          attendance = result;
          isProcessing = false;
        });
        _showSnack(
          _isPunchedOut
              ? '✅ Punched Out Successfully'
              : '✅ Punched In Successfully',
        );
      } else {
        setState(() => isProcessing = false);
        _showSnack('⚠️ Action failed. Try again.');
      }
    } catch (e) {
      debugPrint("Punch error: $e");
      setState(() => isProcessing = false);
      _showSnack('⚠️ Connection error. Try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1A2E2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'[\s.]+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, name.length < 2 ? name.length : 2).toUpperCase();
  }

  String _weekday() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[_now.weekday - 1];
  }

  String _dateStr() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${_weekday()}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  String _timeStr() {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Button state helpers ──
  Color get _btnColor {
    if (_isPunchedOut) return Colors.grey.shade400;
    if (_isPunchedIn) return const Color(0xFFE53935);
    return const Color(0xFF2E7D32);
  }

  IconData get _btnIcon {
    if (_isPunchedOut) return Icons.check_circle_outline;
    if (_isPunchedIn) return Icons.logout;
    return Icons.login;
  }

  String get _btnLabel {
    if (_isPunchedOut) return 'COMPLETED';
    if (_isPunchedIn) return 'PUNCH-OUT';
    return 'PUNCH-IN';
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
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1A2E2A)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top Bar
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Color(0xFF1A1A2E),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            "ATTENDANCE",
                            style: TextStyle(
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
                            onPressed: _loadAttendance,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ── Hero Date/Time Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1A2E2A), Color(0xFF2D5016)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1A2E2A,
                              ).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _dateStr(),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _timeStr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Text(
                                    _getInitials(widget.driverName),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Colors.white60,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.driverName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isPunchedOut
                                    ? Colors.blueGrey.withValues(alpha: 0.25)
                                    : _isPunchedIn
                                    ? const Color(
                                        0xFF4CAF50,
                                      ).withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isPunchedOut
                                      ? Colors.blueGrey
                                      : _isPunchedIn
                                      ? const Color(0xFF4CAF50)
                                      : Colors.red.shade300,
                                ),
                              ),
                              child: Text(
                                _isPunchedOut
                                    ? '✅ Shift Completed'
                                    : _isPunchedIn
                                    ? '🟢 Currently Punched In'
                                    : '🔴 Not Punched In',
                                style: TextStyle(
                                  color: _isPunchedOut
                                      ? Colors.blueGrey.shade200
                                      : _isPunchedIn
                                      ? const Color(0xFF4CAF50)
                                      : Colors.red.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Login Button ──
                      if (!_isPunchedOut) ...[
                        SizedBox(
                          width: 200,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : _handlePunch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _btnColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(_btnIcon, color: Colors.white),
                            label: Text(
                              _btnLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isPunchedIn ? 'Tap to punch out' : 'Tap to punch in',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                      ] else ...[
                        // Completed state icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade50,
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            color: Colors.green.shade600,
                            size: 52,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Shift Completed for Today',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Today's Timeline Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Summary",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Login row
                            _timelineRow(
                              icon: Icons.login_rounded,
                              iconColor: Colors.green.shade600,
                              label: 'Punch-In Time',
                              time: _fmt(attendance?['punch_in']),
                              bg: Colors.green.shade50,
                            ),
                            const SizedBox(height: 8),
                            // Vertical connector
                            Padding(
                              padding: const EdgeInsets.only(left: 23),
                              child: Container(
                                width: 2,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Logout row
                            _timelineRow(
                              icon: Icons.logout_rounded,
                              iconColor: Colors.red.shade600,
                              label: 'Punch-Out Time',
                              time: _fmt(attendance?['punch_out']),
                              bg: Colors.red.shade50,
                            ),
                            const Divider(height: 28, color: Color(0xFFF0F0F0)),
                            // Total hours
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: const Color(0xFF1A2E2A),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Total Hours',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A2E2A),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _totalHours(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _timelineRow({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required String label,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
