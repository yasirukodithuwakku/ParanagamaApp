import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_route_screen.dart';
import 'package:intl/intl.dart';

class DeliveryRoutesScreen extends StatefulWidget {
  final String role; // Accept Role
  const DeliveryRoutesScreen({super.key, required this.role});

  @override
  State<DeliveryRoutesScreen> createState() => _DeliveryRoutesScreenState();
}

class _DeliveryRoutesScreenState extends State<DeliveryRoutesScreen> {
  DateTimeRange? selectedDateRange;
  final TextEditingController vehicleFilterController = TextEditingController();

  Future<void> _showEditRouteDialog(BuildContext context, String docId, String currentRoute, String currentStart, String currentEnd, String currentStatus) async {
    final TextEditingController routeController = TextEditingController(text: currentRoute);
    final TextEditingController startMeterController = TextEditingController(text: currentStart);
    final TextEditingController endMeterController = TextEditingController(text: currentEnd);
    String selectedStatus = currentStatus;
    bool isUpdating = false;

    final List<String> statusOptions = ['In Transit', 'Completed', 'Pending'];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Delivery Route'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: routeController, decoration: const InputDecoration(labelText: 'Route Name')),
                    const SizedBox(height: 15),
                    TextField(controller: startMeterController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Start Meter (km)')),
                    const SizedBox(height: 15),
                    TextField(controller: endMeterController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'End Meter (km)')),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: statusOptions.contains(selectedStatus) ? selectedStatus : 'In Transit',
                      items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => selectedStatus = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  onPressed: isUpdating ? null : () async {
                    setState(() => isUpdating = true);
                    double start = double.tryParse(startMeterController.text) ?? 0.0;
                    double end = double.tryParse(endMeterController.text) ?? 0.0;
                    double totalKm = (end > start) ? end - start : 0.0;

                    try {
                      await FirebaseFirestore.instance.collection('delivery_routes').doc(docId).update({
                        'route': routeController.text.trim(),
                        'startMeter': startMeterController.text.trim(),
                        'endMeter': endMeterController.text.trim(),
                        'totalKm': totalKm.toStringAsFixed(1),
                        'status': endMeterController.text.isEmpty ? 'In Transit' : selectedStatus,
                      });
                      if (context.mounted) Navigator.pop(context);
                    } finally {
                      setState(() => isUpdating = false);
                    }
                  },
                  child: isUpdating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator()) : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndDeleteRoute(BuildContext context, String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('delivery_routes').doc(docId).delete();
    }
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => selectedDateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final Color brandColor = Theme.of(context).primaryColor;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text(widget.role == 'Admin' ? 'All Delivery Routes' : 'My Delivery Routes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('delivery_routes').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No routes available.'));

          List<QueryDocumentSnapshot> filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            bool matchesDate = true;
            bool matchesVehicle = true;

            // Strict filter for Driver
            if (widget.role == 'Driver') {
              if (data['driverId'] != currentUserId) return false;
            } else {
              // Search filter for Admin
              if (vehicleFilterController.text.isNotEmpty) {
                matchesVehicle = (data['vehicleNo'] ?? '').toString().toLowerCase().contains(vehicleFilterController.text.toLowerCase());
              }
            }

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

          double totalFilteredKm = filteredDocs.fold(0, (sum, doc) => sum + (double.tryParse((doc.data() as Map)['totalKm'] ?? '0') ?? 0.0));

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    if (widget.role == 'Admin') ...[
                      TextField(
                        controller: vehicleFilterController,
                        decoration: const InputDecoration(labelText: 'Filter by Vehicle', prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: Icon(Icons.date_range, color: brandColor),
                            label: Text(selectedDateRange == null ? 'Select Date Range' : '${DateFormat('MMM d').format(selectedDateRange!.start)} - ${DateFormat('MMM d').format(selectedDateRange!.end)}'),
                          ),
                        ),
                        if (selectedDateRange != null) IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setState(() => selectedDateRange = null))
                      ],
                    ),
                    const Divider(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total KM:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${totalFilteredKm.toStringAsFixed(1)} km', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandColor)),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: filteredDocs.isEmpty 
                    ? const Center(child: Text('No routes match.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data() as Map<String, dynamic>;
                          final String docId = filteredDocs[index].id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(data['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(data['status'] ?? '', style: TextStyle(color: (data['status'] == 'Completed') ? Colors.green : Colors.blue, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Divider(),
                                  Text('Vehicle: ${data['vehicleNo']}'),
                                  Text('Route: ${data['route']}'),
                                  Text('Start: ${data['startMeter']} km  |  End: ${data['endMeter']} km'),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(onPressed: () => _confirmAndDeleteRoute(context, docId), icon: const Icon(Icons.delete, color: Colors.red), label: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ElevatedButton.icon(
                                        onPressed: () => _showEditRouteDialog(context, docId, data['route'], data['startMeter'], data['endMeter'] ?? '', data['status']),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit', style: TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: brandColor),
                                      ),
                                    ],
                                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddRouteScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}