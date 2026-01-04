import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/db_service.dart';
import '../main.dart'; // To access AppGradients

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double totalSpend = 0;
  double totalBudget = 0;

  @override
  void initState() {
    super.initState();
    _saveFcmToken();
    _refreshData();
  }

  Future<void> _saveFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (token != null && userId != null) {
        // Save token to Supabase profiles table
        await Supabase.instance.client.from('profiles').upsert({
          'id': userId, 
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint("Error saving FCM Token: $e");
    }
  }

  Future<void> _refreshData() async {
    final s = await DBService().getTotalSpend();
    final b = await DBService().getTotalBudget();
    setState(() { totalSpend = s; totalBudget = b; });
  }

  Future<void> _addTransaction() async {
    // ✅ FIXED: Using Named Parameters to match DBService
    await DBService().addTransaction(
      title: "Test Expense", 
      amount: 500.0, 
      category: "Food", 
      type: "expense", // Required parameter
      date: DateTime.now(),
    );
    _refreshData(); // Refresh UI
  }

  Future<void> _setBudget() async {
    await DBService().setBudget("Food", 1000.0);
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    // Handle null safety for theme extension
    final gradients = Theme.of(context).extension<AppGradients>();
    final primaryGradient = gradients?.primaryGradient ?? 
        const LinearGradient(colors: [Colors.blue, Colors.purple]);

    return Scaffold(
      body: Column(
        children: [
          // Gradient Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              gradient: primaryGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Welcome Back", style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 10),
                Text("RM ${totalSpend.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                Text("Budget: RM ${totalBudget.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _setBudget, child: const Text("Set Budget (RM 1000)")),
          ElevatedButton(onPressed: _addTransaction, child: const Text("Add Expense (RM 500)")),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Tap 'Add Expense' twice to exceed budget and trigger notification!", textAlign: TextAlign.center),
          )
        ],
      ),
    );
  }
}