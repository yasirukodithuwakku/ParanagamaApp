import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'delivery_routes_screen.dart';
import 'vehicle_status_screen.dart';
import 'register_screen.dart';
import 'payment_summaries_screen.dart';

class HomeScreen extends StatelessWidget {
  final String role; 
  const HomeScreen({super.key, required this.role});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> adminItems = [
      {'title': 'Vehicle Status', 'icon': Icons.admin_panel_settings_rounded, 'color': Colors.purple},
      {'title': 'Delivery Routes', 'icon': Icons.alt_route_rounded, 'color': Colors.blue},
      {'title': 'Add Driver', 'icon': Icons.person_add_rounded, 'color': Colors.green},
      {'title': 'Payment Summaries', 'icon': Icons.payments_rounded, 'color': Colors.deepOrange},
    ];

    final List<Map<String, dynamic>> driverItems = [
      {'title': 'Vehicle Status', 'icon': Icons.directions_car_rounded, 'color': Colors.purple},
      {'title': 'Delivery Routes', 'icon': Icons.alt_route_rounded, 'color': Colors.blue},
      {'title': 'Payment Summaries', 'icon': Icons.payments_rounded, 'color': Colors.deepOrange},
    ];

    final List<Map<String, dynamic>> currentItems = role == 'Admin' ? adminItems : driverItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'Admin' ? 'Admin Portal' : 'Driver Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.orange.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        role == 'Admin' ? Icons.security_rounded : Icons.local_shipping_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back,',
                            style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role == 'Admin' ? 'Super Administrator' : 'Assigned Driver',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              const Text(
                'Quick Navigation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 15),

              // Modern Grid View
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final item = currentItems[index];
                  return Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
  if (item['title'] == 'Delivery Routes') {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DeliveryRoutesScreen(role: role)));
  } else if (item['title'] == 'Vehicle Status') {
    Navigator.push(context, MaterialPageRoute(builder: (context) => VehicleStatusScreen(role: role)));
  } else if (item['title'] == 'Add Driver') {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
  } else if (item['title'] == 'Payment Summaries') {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentSummariesScreen(role: role)));
  }
},
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: item['color'].withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item['icon'],
                                size: 28,
                                color: item['color'],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item['title'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}