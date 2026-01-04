import 'package:flutter/material.dart';
import 'package:spendlytic_v2/screens/account_screen.dart';
import 'package:spendlytic_v2/screens/spending_insight_screen.dart';
import 'package:spendlytic_v2/screens/home_screen.dart';
import 'package:spendlytic_v2/screens/log_expenses_screen.dart';
import 'package:spendlytic_v2/screens/budget_tracking.dart';

// TO-DO: Replace the following with your actual screen imports
// Example placeholder widgets for now
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class AppNavigationLayout extends StatefulWidget {
  const AppNavigationLayout({super.key});

  @override
  State<AppNavigationLayout> createState() => _AppNavigationLayoutState();
}

class _AppNavigationLayoutState extends State<AppNavigationLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LogExpensesScreen(),
    BudgetTrackingScreen(),
    SpendingInsightScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'Log Expense',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Budget'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
