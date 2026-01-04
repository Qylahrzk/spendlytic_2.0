import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚀 Supabase for Auth
import 'package:easy_localization/easy_localization.dart';

import '../providers/theme_notifier.dart';
import '../services/db_service.dart';
import '../widgets/auth_layout.dart'; // To navigate back after logout

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  
  // 🗑️ Clear All Data (Local & Logout)
  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset App?"),
        content: const Text("This will log you out and clear local data. Your cloud data will remain safe."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 1. Clear Local Database tables
      final db = await DBService().database;
      await db.delete('transactions');
      await db.delete('budgets');
      
      // 2. Sign Out from Supabase
      await Supabase.instance.client.auth.signOut();

      // 3. Navigate to Login (Check mounted!)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthLayout()),
          (route) => false,
        );
      }
    }
  }

  // 🚪 Logout Function
  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error logging out: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          // 🎨 Theme Settings
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: themeNotifier.isDarkMode,
              onChanged: (value) {
                themeNotifier.toggleTheme(value);
              },
            ),
          ),
          
          const Divider(),

          // 🌐 Language Settings
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: Text(context.locale.toString()),
            onTap: () {
              // Toggle between English and Malay for example
              if (context.locale.languageCode == 'en') {
                context.setLocale(const Locale('ms'));
              } else {
                context.setLocale(const Locale('en'));
              }
            },
          ),

          const Divider(),

          // 🗑️ Clear Data
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.orange),
            title: const Text("Reset Local Data"),
            onTap: _resetApp,
          ),

          // 🚪 Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}