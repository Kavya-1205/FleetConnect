import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'screens/driver_home.dart';
import 'screens/admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedRole = "Driver";
  bool _obscurePassword = true;
  bool _isLoading = false;
  final TextEditingController empIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void login() async {
    if (empIdController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      empIdController.text,
      passwordController.text,
      selectedRole,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result != null) {
      // ✅ Save session to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_name', result["name"] ?? '');
      await prefs.setString('session_emp_id', result["employee_id"] ?? '');
      await prefs.setString('session_role', result["role"] ?? '');
      await prefs.setInt('session_id', result["id"] ?? 0);

      if (!mounted) return;

      final String name = result["name"] ?? "Driver";
      final int userId = result["id"] ?? 0;
      final String employeeId = result["employee_id"] ?? "";

      if (selectedRole == "Driver") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverHome(
              driverName: name,
              driverId: userId,
              employeeId: employeeId,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Login ❌")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECF0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.directions_car,
                      size: 44, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text("FleetConnect",
                    style: TextStyle(fontSize: 28,
                        fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text("Manage your journey with precision",
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ),
              const SizedBox(height: 36),
              const Text("Select your role",
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => selectedRole = "Driver"),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: selectedRole == "Driver"
                            ? const Color(0xFF1A2E2A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300)),
                      child: Column(children: [
                        Icon(Icons.person,
                            color: selectedRole == "Driver"
                                ? Colors.white : Colors.grey, size: 28),
                        const SizedBox(height: 6),
                        Text("Driver", style: TextStyle(
                            color: selectedRole == "Driver"
                                ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => selectedRole = "Admin"),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: selectedRole == "Admin"
                            ? const Color(0xFF1A2E2A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300)),
                      child: Column(children: [
                        Icon(Icons.admin_panel_settings,
                            color: selectedRole == "Admin"
                                ? Colors.white : Colors.grey, size: 28),
                        const SizedBox(height: 6),
                        Text("Admin", style: TextStyle(
                            color: selectedRole == "Admin"
                                ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 24),
              const Text("Employee ID",
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  controller: empIdController,
                  decoration: const InputDecoration(
                    hintText: "e.g. CCT034",
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Password",
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A2E2A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Login", style: TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
