import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';

class StaffHomePage extends StatefulWidget {
  const StaffHomePage({Key? key}) : super(key: key);

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool isCheckedIn = false;
  String? currentSessionId;
  List<Map<String, dynamic>> attendanceHistory = [];
  List<Map<String, dynamic>> fullHistory = [];

  DateTime? selectedDate;

  final String officePlaceName = "KLE Tech Campus";
  final double officeLat = 15.8361133;
  final double officeLng = 74.5176867;
  final double allowedRadius = 200.0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _getCurrentSession(user.uid);
      await _fetchAttendanceHistory(user.uid);
    }
  }

  Future<void> _getCurrentSession(String uid) async {
    final todayDoc = _firestore.collection('attendance').doc(uid);
    final sessionsSnapshot = await todayDoc
        .collection('sessions')
        .where('checkOutTimestamp', isNull: true)
        .orderBy('checkInTimestamp', descending: true)
        .limit(1)
        .get();

    setState(() {
      isCheckedIn = sessionsSnapshot.docs.isNotEmpty;
      currentSessionId = isCheckedIn ? sessionsSnapshot.docs.first.id : null;
    });
  }

  Future<void> _fetchAttendanceHistory(String uid) async {
    final sessionDocs = await _firestore
        .collection('attendance')
        .doc(uid)
        .collection('sessions')
        .orderBy('checkInTimestamp', descending: true)
        .get();

    final history = sessionDocs.docs.map((doc) {
      final data = doc.data();
      final checkIn = data['checkInTimestamp']?.toDate();
      final checkOut = data['checkOutTimestamp']?.toDate();
      final duration = data['duration'] ?? 0;

      return {
        'status': checkOut == null ? 'Checked In' : 'Checked Out',
        'timestamp': DateFormat('yMMMd – hh:mm a').format(checkOut ?? checkIn),
        'rawDate': checkIn,
        'duration': duration,
      };
    }).toList();

    setState(() {
      fullHistory = history;
      attendanceHistory = selectedDate != null
          ? _filterHistoryByDate(fullHistory, selectedDate!)
          : history;
    });
  }

  List<Map<String, dynamic>> _filterHistoryByDate(
      List<Map<String, dynamic>> history, DateTime date) {
    return history.where((record) {
      final rawDate = record['rawDate'] as DateTime?;
      return rawDate != null &&
          rawDate.year == date.year &&
          rawDate.month == date.month &&
          rawDate.day == date.day;
    }).toList();
  }

  Future<bool> _verifyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final distance = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );
      return distance <= allowedRadius;
    } catch (e) {
      _showMessage("Location error: ${e.toString()}");
      return false;
    }
  }

  Future<bool> _authenticate() async {
    final isBiometricAvailable = await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();
    if (!isBiometricAvailable) {
      _showMessage("Biometric authentication not available.");
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to mark attendance',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      _showMessage("Authentication error: ${e.toString()}");
      return false;
    }
  }

  Future<void> _handleAttendance() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final locationOk = await _verifyLocation();
    if (!locationOk) {
      _showMessage("You're not within the allowed location to check in/out.");
      return;
    }

    final authOk = await _authenticate();
    if (!authOk) {
      _showMessage("Authentication failed.");
      return;
    }

    final now = DateTime.now();
    final position = await Geolocator.getCurrentPosition();
    final attendanceRef = _firestore.collection('attendance').doc(user.uid);
    final sessionsRef = attendanceRef.collection('sessions');

    if (!isCheckedIn) {
      final newSession = await sessionsRef.add({
        'checkInTimestamp': now,
        'checkInLocation': officePlaceName,
      });
      setState(() {
        isCheckedIn = true;
        currentSessionId = newSession.id;
      });
      _showMessage("Check-in successful.");
    } else if (currentSessionId != null) {
      final docSnapshot = await sessionsRef.doc(currentSessionId!).get();
      final checkInTimestamp = docSnapshot['checkInTimestamp'].toDate();
      final checkOutDuration = now.difference(checkInTimestamp).inMinutes;

      await sessionsRef.doc(currentSessionId!).update({
        'checkOutTimestamp': now,
        'checkOutLocation': officePlaceName,
        'duration': checkOutDuration,
      });
      setState(() {
        isCheckedIn = false;
        currentSessionId = null;
      });
      _showMessage("Check-out successful.");
    }

    await _fetchAttendanceHistory(user.uid);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      setState(() {
        attendanceHistory = _filterHistoryByDate(fullHistory, picked);
      });
    }
  }

  void _clearFilter() {
    setState(() {
      selectedDate = null;
      attendanceHistory = fullHistory;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff - Attendance"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${_auth.currentUser?.email ?? "Staff"}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${DateFormat.yMMMMEEEEd().format(DateTime.now())}',
                              style: const TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      icon: Icon(isCheckedIn ? Icons.logout : Icons.login),
                      label: Text(
                        isCheckedIn ? 'Check Out' : 'Check In',
                        style: const TextStyle(
                          color: Colors.white, // <-- Ensure text is white
                          fontSize: 18,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckedIn ? Colors.red : Colors.indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _handleAttendance,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 10),
                  const Text(
                    'Attendance History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.filter_alt),
                        label: const Text("Filter by Date"),
                        onPressed: () => _selectDate(context),
                      ),
                      if (selectedDate != null)
                        TextButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text("Clear Filter"),
                          onPressed: _clearFilter,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: attendanceHistory.isEmpty
                        ? const Center(child: Text("No attendance records."))
                        : ListView.builder(
                            itemCount: attendanceHistory.length,
                            itemBuilder: (context, index) {
                              final record = attendanceHistory[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(
                                    record['status'] == 'Checked In'
                                        ? Icons.login
                                        : Icons.logout,
                                    color: record['status'] == 'Checked In'
                                        ? Colors.indigo
                                        : Colors.red,
                                  ),
                                  title: Text(record['timestamp']),
                                  subtitle: Text(
                                    "Status: ${record['status']} | Duration: ${record['duration']} min",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              );
                            },
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
}
