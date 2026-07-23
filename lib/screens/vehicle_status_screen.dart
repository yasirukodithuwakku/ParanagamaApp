import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_vehicle_status_screen.dart';

class VehicleStatusScreen extends StatefulWidget {
  final String role; // Accepts the role from HomeScreen
  const VehicleStatusScreen({super.key, required this.role});

  @override
  State<VehicleStatusScreen> createState() => _VehicleStatusScreenState();
}

class _VehicleStatusScreenState extends State<VehicleStatusScreen> {
  
  Future<void> _showUpdateStatusDialog(
      BuildContext context, String docId, String currentStatus, String currentNotes) async {
    String? selectedStatus = currentStatus;
    final TextEditingController notesController = TextEditingController(text: currentNotes);
    bool isUpdating = false;

    final List<String> statusOptions = ['Good Condition', 'Breakdown', 'Service Required', 'Leave Request'];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Vehicle Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select New Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: statusOptions.contains(selectedStatus) ? selectedStatus : statusOptions[0],
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: statusOptions.map((String status) {
                        return DropdownMenuItem<String>(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (String? newValue) => setState(() => selectedStatus = newValue),
                    ),
                    const SizedBox(height: 15),
                    const Text('Update Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
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
                    try {
                      await FirebaseFirestore.instance.collection('vehicle_statuses').doc(docId).update({
                        'status': selectedStatus,
                        'notes': notesController.text.trim(),
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated Successfully!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    } finally {
                      setState(() => isUpdating = false);
                    }
                  },
                  child: isUpdating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color brandColor = Theme.of(context).primaryColor;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.role == 'Admin' ? 'All Vehicle Statuses' : 'My Vehicle Status'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicle_statuses').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No vehicle status updates available.'));

          // Filter documents based on role
          List<QueryDocumentSnapshot> filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (widget.role == 'Driver') {
              if (data['driverId'] != currentUserId) return false; // Show only driver's own records
            }
            return true;
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('You have no status records yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final statusData = filteredDocs[index].data() as Map<String, dynamic>;
              final String docId = filteredDocs[index].id;
              
              final String vehicleNo = statusData['vehicleNo'] ?? 'Unknown';
              final String driverEmail = statusData['driverEmail'] ?? 'Unknown Driver';
              final String status = statusData['status'] ?? 'Unknown Status';
              final String date = statusData['date'] ?? 'No Date';
              final String notes = statusData['notes'] ?? 'No notes.';
              final statusColor = _getStatusColor(status);
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(vehicleNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                            child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Driver: $driverEmail', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500))),
                          Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: Text('Notes: $notes', style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic)),
                      ),
                      const SizedBox(height: 10),
                      const Divider(thickness: 1),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _showUpdateStatusDialog(context, docId, status, notes),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Update Status'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddVehicleStatusScreen()));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Good Condition': return Colors.green;
      case 'Breakdown': return Colors.red;
      case 'Service Required': return Colors.orange;
      case 'Leave Request': return Colors.indigo;
      default: return Colors.grey;
    }
  }
}