import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PaymentSummariesScreen extends StatefulWidget {
  final String role; // Pass role ('Admin' or 'Driver') to customize view
  const PaymentSummariesScreen({super.key, required this.role});

  @override
  State<PaymentSummariesScreen> createState() => _PaymentSummariesScreenState();
}

class _PaymentSummariesScreenState extends State<PaymentSummariesScreen> {
  DateTimeRange? selectedDateRange;
  final TextEditingController vehicleFilterController = TextEditingController();
  
  String driverVehicleNo = '';
  bool isLoadingDriverVehicle = true;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'Driver') {
      _fetchDriverVehicleNumber();
    } else {
      setState(() {
        isLoadingDriverVehicle = false;
      });
    }
  }

  // Fetch the logged-in driver's assigned vehicle number from Firestore
  Future<void> _fetchDriverVehicleNumber() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            driverVehicleNo = userDoc.get('vehicleNo') ?? '';
            isLoadingDriverVehicle = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoadingDriverVehicle = false;
      });
    }
  }

  // Function for Admin to Edit Payment Rate / Notes
  Future<void> _showEditPaymentDialog(
      BuildContext context, String docId, String currentRate, String currentNotes) async {
    final TextEditingController rateController = TextEditingController(text: currentRate);
    final TextEditingController notesController = TextEditingController(text: currentNotes);
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Payment Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Rate per KM (LKR)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Admin Notes / Adjustments',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  onPressed: isUpdating ? null : () async {
                    setState(() {
                      isUpdating = true;
                    });

                    try {
                      await FirebaseFirestore.instance.collection('delivery_routes').doc(docId).update({
                        'ratePerKm': rateController.text.trim(),
                        'adminNotes': notesController.text.trim(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment Details Updated Successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setState(() {
                        isUpdating = false;
                      });
                    }
                  },
                  child: isUpdating 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor, 
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  @override
  void dispose() {
    vehicleFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color brandColor = Theme.of(context).primaryColor;

    if (isLoadingDriverVehicle) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Summary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.role == 'Admin' ? 'Drivers Payment Summaries' : 'My Vehicle Payment Summary'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('delivery_routes')
            .where('status', isEqualTo: 'Completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No completed payment records available.'));
          }

          List<QueryDocumentSnapshot> filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            bool matchesDate = true;
            bool matchesVehicle = true;

            // If user is a Driver, strictly filter by their assigned vehicle number
            if (widget.role == 'Driver') {
              String routeVehicle = data['vehicleNo']?.toString().trim() ?? '';
              if (routeVehicle != driverVehicleNo) {
                return false; // Skip routes that do not belong to this driver's vehicle
              }
            } else {
              // Admin filter search by vehicle
              if (vehicleFilterController.text.isNotEmpty) {
                String vehicleNo = data['vehicleNo']?.toString().toLowerCase() ?? '';
                matchesVehicle = vehicleNo.contains(vehicleFilterController.text.toLowerCase());
              }
            }

            // Check Date Range Filter
            if (selectedDateRange != null) {
              DateTime? routeDate = DateTime.tryParse(data['date'] ?? '');
              if (routeDate != null) {
                matchesDate = routeDate.isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                              routeDate.isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
              } else {
                matchesDate = false;
              }
            }

            return matchesDate && matchesVehicle;
          }).toList();

          double totalKm = 0.0;
          double totalEstimatedPayment = 0.0;

          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            double km = double.tryParse(data['totalKm']?.toString() ?? '0') ?? 0.0;
            double rate = double.tryParse(data['ratePerKm']?.toString() ?? '100') ?? 100.0;
            
            totalKm += km;
            totalEstimatedPayment += (km * rate);
          }

          return Column(
            children: [
              // Filter & Summary Header Card
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6, spreadRadius: 2)],
                ),
                child: Column(
                  children: [
                    // Show vehicle filter ONLY for Admin
                    if (widget.role == 'Admin') ...[
                      TextField(
                        controller: vehicleFilterController,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Vehicle (e.g. LL-1234)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Display driver's vehicle badge
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('Assigned Vehicle: $driverVehicleNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: Icon(Icons.date_range, color: brandColor),
                            label: Text(
                              selectedDateRange == null 
                                ? 'Select Date Range' 
                                : '${DateFormat('MMM d').format(selectedDateRange!.start)} - ${DateFormat('MMM d').format(selectedDateRange!.end)}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                        if (selectedDateRange != null) ...[
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () => setState(() => selectedDateRange = null),
                          )
                        ]
                      ],
                    ),
                    const Divider(height: 25, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total KM:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            Text('${totalKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Earnings:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            Text('Rs. ${totalEstimatedPayment.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandColor)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // List of Payments
              Expanded(
                child: filteredDocs.isEmpty 
                    ? const Center(child: Text('No payment records match your criteria.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data() as Map<String, dynamic>;
                          final String docId = filteredDocs[index].id;
                          
                          final String vehicleNo = data['vehicleNo'] ?? 'Unknown';
                          final String route = data['route'] ?? 'No Route';
                          final String date = data['date'] ?? 'No Date';
                          final String driverEmail = data['driverEmail'] ?? 'Unknown Driver';
                          double km = double.tryParse(data['totalKm']?.toString() ?? '0') ?? 0.0;
                          double rate = double.tryParse(data['ratePerKm']?.toString() ?? '100') ?? 100.0;
                          final String adminNotes = data['adminNotes'] ?? '';
                          
                          double totalPay = km * rate;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(
                                        'Rs. ${totalPay.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandColor),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20, thickness: 1),
                                  
                                  Row(
                                    children: [
                                      const Icon(Icons.local_shipping, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text('Vehicle: $vehicleNo', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.route, size: 18, color: Colors.blueAccent),
                                      const SizedBox(width: 8),
                                      Text('Route: $route (${km.toStringAsFixed(1)} km @ Rs. ${rate.toStringAsFixed(0)}/km)', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                    ],
                                  ),
                                  if (adminNotes.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Admin Note: $adminNotes', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.orange)),
                                  ],
                                  
                                  // Show Edit button ONLY for Admin
                                  if (widget.role == 'Admin') ...[
                                    const SizedBox(height: 10),
                                    const Divider(thickness: 1),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: brandColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                        onPressed: () => _showEditPaymentDialog(context, docId, rate.toString(), adminNotes),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit Payment Rate'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}