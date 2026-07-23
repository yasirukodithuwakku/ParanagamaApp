import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddVehicleStatusScreen extends StatefulWidget {
  const AddVehicleStatusScreen({super.key});

  @override
  State<AddVehicleStatusScreen> createState() => _AddVehicleStatusScreenState();
}

class _AddVehicleStatusScreenState extends State<AddVehicleStatusScreen> {
  final TextEditingController vehicleController = TextEditingController(); 
  final TextEditingController notesController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  
  String? selectedStatus;
  bool isLoading = true;
  bool isSaving = false;

  final List<String> statusOptions = [
    'Good Condition',
    'Breakdown',
    'Service Required',
    'Leave Request'
  ];

  @override
  void initState() {
    super.initState();
    _fetchVehicleNumber();
  }

  Future<void> _fetchVehicleNumber() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            vehicleController.text = userDoc.get('vehicleNo') ?? 'Unknown Vehicle';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _submitStatus() async {
    if (selectedStatus == null || dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select status and date!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('vehicle_statuses').add({
        'driverId': user?.uid,
        'driverEmail': user?.email,
        'vehicleNo': vehicleController.text,
        'status': selectedStatus,
        'date': dateController.text,
        'notes': notesController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status Updated Successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
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
    vehicleController.dispose();
    notesController.dispose();
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Update Vehicle Status'),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Report Status / Request Leave',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 25),

                  TextField(
                    controller: vehicleController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Your Assigned Vehicle',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Select Current Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    items: statusOptions.map((String status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedStatus = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Effective Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(), 
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
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes (Reason for leave, breakdown etc.)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: isSaving ? null : _submitStatus,
                    child: isSaving 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}