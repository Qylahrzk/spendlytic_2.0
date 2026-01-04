import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../../services/currency_service.dart';
import '../../services/db_service.dart';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key});

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String _currency = 'MYR (RM)';
  String _currencySymbol = 'RM';
  double _currencyRate = 1.0;

  Map<String, double> _budgets = {};
  Map<String, double> _expensesByCategory = {};
  Map<DateTime, double> _dailyExpenses = {};

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  DateTime _currentWeekStart = _findStartOfWeek(DateTime.now());

  static DateTime _findStartOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  List<String> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadUserCurrency();
    _loadData();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _flutterLocalNotificationsPlugin.initialize(settings);
  }

  Future<void> _showNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_channel',
      'Budget Alerts',
      channelDescription: 'Notifications for budget tracking status',
      importance: Importance.high,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await _flutterLocalNotificationsPlugin.show(
        0, 'Budget Alert', message, platformDetails);
  }

  Future<void> _loadUserCurrency() async {
    final user = await DBService().getUser();
    if (user != null) {
      final rate =
          CurrencyService.conversionRates[user.defaultCurrency] ?? 1.0;
      setState(() {
        _currency = user.defaultCurrency;
        _currencySymbol = CurrencyService.getSymbol(_currency);
        _currencyRate = rate;
      });
    }
  }

  Future<void> _loadData() async {
    final budgets = await DBService().getBudgets();
    final expenses = await DBService().getDailyExpenseSums();
    final categoryTotals = await DBService().getCategoryTotals();

    setState(() {
      _budgets = budgets;
      _dailyExpenses = expenses;
      _expensesByCategory = categoryTotals;
      _availableCategories =
          categoryTotals.keys.toList() + budgets.keys.toList();
      _availableCategories = _availableCategories.toSet().toList();
    });

    _checkAndNotifyStatus();
  }

  double _getTotalBudgetMYR() =>
      _budgets.values.fold(0, (a, b) => a + b);
  double _getTotalSpentMYR() =>
      _expensesByCategory.values.fold(0, (a, b) => a + b);
  double _convert(double amount) => amount * _currencyRate;

  void _checkAndNotifyStatus() {
    final budgetMYR = _getTotalBudgetMYR();
    final spentMYR = _getTotalSpentMYR();
    if (budgetMYR == 0) return;

    final status = spentMYR > budgetMYR ? 'Over Budget' : 'On Track';
    _showNotification(
      "$status\nBudget: $_currencySymbol ${_convert(budgetMYR).toStringAsFixed(2)}\n"
      "Spent: $_currencySymbol ${_convert(spentMYR).toStringAsFixed(2)}",
    );
  }

  Future<void> _showSetBudgetDialog() async {
    String? selectedCategory;
    final amountController = TextEditingController();

// Initialize the amount controller with an empty string
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Set New Budget"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: _availableCategories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (val) => selectedCategory = val,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Amount ($_currencySymbol)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (selectedCategory == null) return;
              final amount = double.tryParse(amountController.text);
              if (amount != null) {
                final amountMYR = amount / _currencyRate;
                await DBService()
                    .setBudget(selectedCategory!, amountMYR);
                await _loadData();
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMonthYearPicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedYear = picked.year;
        _selectedMonth = picked.month;
        _currentWeekStart = _findStartOfWeek(picked);
      });
    }
  }

  Future<void> _confirmDeleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete All Data?"),
        content: const Text(
            "This will clear all budgets, balances, and transactions."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirmed == true) {
      await DBService().clearUserData();
      await _loadData();
    }
  }

// Expense tracking for the current week
  List<DateTime> get _daysOfCurrentWeek =>
      List.generate(7, (i) => _currentWeekStart.add(Duration(days: i)));

  Map<DateTime, double> get _filteredExpenses {
    return _dailyExpenses.entries
        .where((e) =>
            e.key.year == _selectedYear &&
            e.key.month == _selectedMonth)
        .fold({}, (acc, e) {
      final key = DateTime(e.key.year, e.key.month, e.key.day);
      acc[key] = (acc[key] ?? 0) + e.value;
      return acc;
    });
  }

  bool _isDayOverbudget(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final amount = _filteredExpenses[date];
    if (amount == null) return false;
    return amount > _getTotalBudgetMYR();
  }

  bool _hasExpense(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _filteredExpenses.containsKey(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final colorScheme = Theme.of(context).colorScheme;
    final totalBudget = _convert(_getTotalBudgetMYR());
    final totalSpent = _convert(_getTotalSpentMYR());
    final isOver = totalSpent > totalBudget;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
              "BUDGET TRACKING",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: color.primary,
            foregroundColor: color.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDeleteData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSetBudgetDialog,
        child: const Icon(Icons.add_chart),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => setState(() {
                    _currentWeekStart =
                        _currentWeekStart.subtract(const Duration(days: 7));
                  }),
                ),
                const Text(
                  'Expense Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => setState(() {
                        _currentWeekStart =
                            _currentWeekStart.add(const Duration(days: 7));
                      }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: _showMonthYearPicker,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildWeeklyOverview(colorScheme),
            const SizedBox(height: 16),
            _buildSummaryCard(
                colorScheme, totalBudget, totalSpent, isOver),
            const SizedBox(height: 16),
            const Text('Category Overview:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _budgets.isEmpty
                  ? const Center(child: Text('No budgets set yet.'))
                  : ListView(
                      children: _budgets.keys.map((category) {
                        final spentMYR =
                            _expensesByCategory[category] ?? 0;
                        final budgetMYR = _budgets[category]!;
                        final spent = _convert(spentMYR);
                        final budget = _convert(budgetMYR);
                        return Card(
                          child: ListTile(
                            title: Text(category),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value:
                                      (spentMYR / budgetMYR).clamp(0, 1),
                                  backgroundColor:
                                      Colors.grey.shade300,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          spentMYR > budgetMYR
                                              ? Colors.red
                                              : Colors.green),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Spent: $_currencySymbol ${spent.toStringAsFixed(2)} / '
                                    'Budget: $_currencySymbol ${budget.toStringAsFixed(2)}'),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: _daysOfCurrentWeek
                .map((d) => Expanded(
                        child: Center(
                            child: Text(DateFormat.E().format(d)))))
                .toList(),
          ),
          const SizedBox(height: 4),
          Row(
            children: _daysOfCurrentWeek
                .map((d) => Expanded(
                        child: Center(child: Text('${d.day}'))))
                .toList(),
          ),
          const SizedBox(height: 4),
          Row(
            children: _daysOfCurrentWeek.map((d) {
              return Expanded(
                child: Center(
                  child: _hasExpense(d)
                      ? Icon(
                          Icons.show_chart,
                          size: 18,
                          color: _isDayOverbudget(d)
                              ? Colors.red
                              : Colors.green,
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      ColorScheme colorScheme,
      double totalBudget,
      double totalSpent,
      bool isOver,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),

      //Indicate the budget status
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Total Budget: $_currencySymbol ${totalBudget.toStringAsFixed(2)}'),
          Text(
              'Total Spent: $_currencySymbol ${totalSpent.toStringAsFixed(2)}'),
          Text(
            'Status: ${isOver ? 'Over Budget' : 'On Track'}',
            style: TextStyle(
                color: isOver ? Colors.red : Colors.green),
          ),
        ],
      ),
    );
  }
}
