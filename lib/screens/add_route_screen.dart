import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final TextEditingController dateController = TextEditingController();
  final TextEditingController routeController = TextEditingController();
  final TextEditingController startMeterController = TextEditingController();
  final TextEditingController endMeterController = TextEditingController();

  String calculatedKm = '0.0';
  String vehicleNo = 'Unknown';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    startMeterController.addListener(_calculateDistance);
    endMeterController.addListener(_calculateDistance);
    _fetchVehicleNumber();
  }

  Future<void> _fetchVehicleNumber() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          vehicleNo = userDoc.get('vehicleNo') ?? 'Unknown';
        });
      }
    }
  }

  void _calculateDistance() {
    double start = double.tryParse(startMeterController.text) ?? 0.0;
    double end = double.tryParse(endMeterController.text) ?? 0.0;

    if (end > start) {
      setState(() {
        calculatedKm = (end - start).toStringAsFixed(1);
      });
    } else {
      setState(() {
        calculatedKm = '0.0';
      });
    }
  }

  Future<void> _saveRoute() async {
    if (dateController.text.isEmpty || routeController.text.isEmpty || startMeterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Date, Route, and Start Meter!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String status = endMeterController.text.isEmpty ? 'In Transit' : 'Completed';

      await FirebaseFirestore.instance.collection('delivery_routes').add({
        'driverId': user?.uid,
        'driverEmail': user?.email,
        'vehicleNo': vehicleNo,
        'date': dateController.text,
        'route': routeController.text,
        'startMeter': startMeterController.text,
        'endMeter': endMeterController.text,
        'totalKm': calculatedKm,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route Saved Successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    startMeterController.dispose();
    endMeterController.dispose();
    dateController.dispose();
    routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color brandColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Update Delivery Route'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vehicle: $vehicleNo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      dateController.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              TextField(
                controller: routeController,
                decoration: const InputDecoration(
                  labelText: 'Delivery Route (e.g. Colombo - Galle)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alt_route),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: startMeterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Start Meter (km)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: endMeterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'End Meter (km) - Optional initially',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                  helperText: 'Leave blank if the route is still in progress.',
                ),
              ),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brandColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: brandColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Distance:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$calculatedKm km', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandColor)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: isSaving ? null : _saveRoute,
                child: isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}