import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_attendance_app/services/auth_service.dart';
import 'package:staff_attendance_app/pages/sign_in_page.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:media_store_plus/media_store_plus.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;
  DateTime? _selectedDate;

  bool _isLoading = false;
  bool _obscurePassword = true; // Add this to your _AdminHomePageState
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  Future<void> _signUpStaff() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final role = _selectedRole!;

    try {
      User? user = await _authService.signUpWithEmailPassword(email, password);

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': role,
          'fingerprintRegistered': false,
        });

        if (context.mounted) Navigator.of(context).pop();
        _showSnackBar('Staff member added successfully!');
        _clearFields();
      } else {
        _showSnackBar('Error creating staff member.');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }

    setState(() => _isLoading = false);
  }

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() => _selectedRole = null);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    }
  }

  void _showAddStaffModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Staff Member',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter email';
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    return emailRegex.hasMatch(value) ? null : 'Enter valid email';
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  ],
                  onChanged: (value) => setState(() => _selectedRole = value),
                  decoration: const InputDecoration(labelText: 'Select Role'),
                  validator: (value) => value == null ? 'Select a role' : null,
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _signUpStaff,
                          child: const Text('Sign Up Staff'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Home"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'Filter by Date',
            onPressed: _pickDateFilter,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            tooltip: 'Clear Filter',
            onPressed: _clearFilters,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download Report',
            onPressed: _downloadReport,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.white),
            tooltip: 'Download Weekly Report',
            onPressed: _downloadWeeklyReport,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Staff",
          style: TextStyle(color: Colors.white), // <-- Ensure text is white
        ),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: const Color(0xFFF5F6FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _buildAttendanceList(),
      ),
    );
  }

  Widget _buildAttendanceList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No staff data found'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  user['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text(
                  user['role'],
                  style: const TextStyle(color: Colors.indigo),
                ),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .doc(user.id)
                        .collection('sessions')
                        .orderBy('checkInTimestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final sessions = snapshot.data!.docs;
                      final filtered = _selectedDate == null
                          ? sessions
                          : sessions.where((session) {
                              final ts = session['checkInTimestamp'].toDate();
                              return ts.year == _selectedDate!.year &&
                                  ts.month == _selectedDate!.month &&
                                  ts.day == _selectedDate!.day;
                            }).toList();

                      if (filtered.isEmpty) {
                        return const ListTile(title: Text('No attendance found.'));
                      }

                      return Column(
                        children: filtered.map((session) {
                          final inTime = session['checkInTimestamp'].toDate();
                          final outTime = session['checkOutTimestamp']?.toDate();
                          final inLoc = session['checkInLocation'];
                          final outLoc = session['checkOutLocation'];
                          final data = session.data() as Map<String, dynamic>;
                          String durationText;
                          if (data.containsKey('duration') && data['duration'] != null) {
                            durationText = '${data['duration']} min';
                          } else {
                            durationText = 'N/A';
                          }

                          return ListTile(
                            leading: Icon(Icons.access_time, color: Colors.indigo),
                            title: Text(
                              'Check-In: ${DateFormat.yMd().add_jm().format(inTime)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Check-In Location: ($inLoc)'),
                                if (outTime != null)
                                  Text('Check-Out: ${DateFormat.yMd().add_jm().format(outTime)}'),
                                if (outLoc != null)
                                  Text('Check-Out Location: ($outLoc)'),
                                Text('Duration: $durationText'),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _pickDateFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearFilters() {
    setState(() => _selectedDate = null);
  }

  Future<void> _downloadReport() async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      _showSnackBar('Storage permission is required.');
      return;
    }

    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final buffer = StringBuffer();
    buffer.writeln('Name,Role,Check-In Time,Check-Out Time,Duration');

    for (var user in usersSnapshot.docs) {
      final userId = user.id;
      final name = user['name'];
      final role = user['role'];

      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(userId)
          .collection('sessions')
          .orderBy('checkInTimestamp', descending: true)
          .get();

      for (var session in sessionsSnapshot.docs) {
        final data = session.data() as Map<String, dynamic>;
        final checkIn = session['checkInTimestamp'].toDate();
        final checkOut = session['checkOutTimestamp']?.toDate();
        final durationStr = data.containsKey('duration') && data['duration'] != null
            ? '${data['duration']} min'
            : 'N/A';

        if (_selectedDate != null) {
          if (checkIn.year != _selectedDate!.year ||
              checkIn.month != _selectedDate!.month ||
              checkIn.day != _selectedDate!.day) {
            continue;
          }
        }

        final checkInStr = DateFormat.yMd().add_jm().format(checkIn);
        final checkOutStr = checkOut != null ? DateFormat.yMd().add_jm().format(checkOut) : 'N/A';

        buffer.writeln('$name,$role,$checkInStr,$checkOutStr,$durationStr');
      }
    }

    final directory = Directory('/storage/emulated/0/Download');
    final filePath = '${directory!.path}/attendance_report.csv';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    _showSnackBar('Report saved to Downloads.');
  }

  Future<void> _downloadWeeklyReport() async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      _showSnackBar('Storage permission is required.');
      return;
    }

    // Let admin pick any date in the week
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      helpText: 'Select any date in the week',
    );
    if (picked == null) return;

    // Calculate week start (Monday) and end (Saturday)
    final weekStart = picked.subtract(Duration(days: picked.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 5, hours: 23, minutes: 59, seconds: 59)); // Up to Saturday 23:59

    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final buffer = StringBuffer();
    buffer.writeln('Name,Role,Total Duration (hrs),Status');

    for (var user in usersSnapshot.docs) {
      final userId = user.id;
      final name = user['name'];
      final role = user['role'];

      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(userId)
          .collection('sessions')
          .where('checkInTimestamp', isGreaterThanOrEqualTo: weekStart)
          .where('checkInTimestamp', isLessThanOrEqualTo: weekEnd)
          .get();

      double totalMinutes = 0;
      for (var session in sessionsSnapshot.docs) {
        final data = session.data();
        if (data.containsKey('duration') && data['duration'] != null) {
          totalMinutes += (data['duration'] as num).toDouble();
        }
      }
      final totalHours = totalMinutes / 60.0;
      final status = totalHours < 35 ? 'Shortage' : 'Good';

      buffer.writeln('$name,$role,${totalHours.toStringAsFixed(2)},$status');
    }

    final directory = Directory('/storage/emulated/0/Download');
    final filePath = '${directory.path}/weekly_attendance_report.csv';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    _showSnackBar('Weekly CSV report saved to Downloads.');
  }
}