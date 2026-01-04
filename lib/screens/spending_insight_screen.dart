// [Your imports remain unchanged]
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/db_service.dart';

class SpendingInsightScreen extends StatefulWidget {
  const SpendingInsightScreen({super.key});

  @override
  State<SpendingInsightScreen> createState() => _SpendingInsightScreenState();
}

class _SpendingInsightScreenState extends State<SpendingInsightScreen> {
  String _selectedMode = 'Expense';
  DateTime _selectedMonth = DateTime.now();
  double _monthlyTotal = 0;
  Map<String, double> _categoryTotals = {};
  Map<String, Map<String, double>> _dayCategoryAmounts = {}; // ✅ New map: {dateString: {category: amount}}
  List<Map<String, dynamic>> _recentTransactions = [];

  final Map<String, Color> _categoryColors = {
    'Food': Colors.blue,
    'Shopping': Colors.orange,
    'Presents': Colors.red,
    'General': Colors.purple,
    'Transportation': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    final db = await DBService().database;

    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));

    final data = await db.query(
      'transactions',
      where: 'type = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        _selectedMode.toLowerCase(),
        firstDay.toIso8601String(),
        lastDay.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );

    double total = 0;
    Map<String, double> catTotals = {};
    Map<String, Map<String, double>> dayCatAmounts = {}; // ✅ New structure
    List<Map<String, dynamic>> recent = [];

    for (var tx in data) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      final category = tx['category'] as String? ?? 'General';
      final rawDate = tx['date'];
      final date = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;

      if (date != null) {
        final key = DateFormat('yyyy-MM-dd').format(date);
        total += amount;
        catTotals[category] = (catTotals[category] ?? 0) + amount;

        dayCatAmounts[key] ??= {};
        dayCatAmounts[key]![category] = (dayCatAmounts[key]![category] ?? 0) + amount;
      }
    }

    recent = data.take(1).toList();

    setState(() {
      _monthlyTotal = total;
      _categoryTotals = catTotals;
      _dayCategoryAmounts = dayCatAmounts;
      _recentTransactions = recent;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: "Select Month",
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _fetchInsights();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
              "SPENDING INSIGHTS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: color.primary,
            foregroundColor: color.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildToggle(colorScheme),
            _buildMonthAndTotal(colorScheme),
            _buildBarChart(),
            _buildCategoryCards(),
            _buildRecentTransaction(colorScheme),
          ],
        ),
      ),
    );
  }

//Toggle between Expense and Savings
  Widget _buildToggle(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ['Expense', 'Savings'].map((mode) {
          final isSelected = _selectedMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMode = mode;
                  _fetchInsights();
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  border: Border.all(color: colorScheme.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

//Month Picker and Total Display 
  Widget _buildMonthAndTotal(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat.yMMMM().format(_selectedMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '- RM ${_monthlyTotal.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, color: colorScheme.error),
          ),
        ],
      ),
    );
  }

// Bar Chart Display
  Widget _buildBarChart() {
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day < 1 || day > 31) return const SizedBox();
                  return Text('$day', style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _dayCategoryAmounts.entries.map((entry) {
            final dateStr = entry.key;
            final categories = entry.value;
            final date = DateTime.tryParse(dateStr);
            if (date == null) return BarChartGroupData(x: 0, barRods: []);

            double runningTotal = 0;
            final rods = categories.entries.map((catEntry) {
              final fromY = runningTotal;
              final toY = runningTotal + catEntry.value;
              final rod = BarChartRodStackItem(
                fromY,
                toY,
                _categoryColors[catEntry.key] ?? Colors.grey,
              );
              runningTotal = toY;
              return rod;
            }).toList();

            return BarChartGroupData(
              x: date.day,
              barRods: [
                BarChartRodData(
                  toY: runningTotal,
                  rodStackItems: rods,
                  width: 10,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

// Category Cards Display
  Widget _buildCategoryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categoryTotals.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _categoryColors[entry.key] ?? Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: const TextStyle(color: Colors.white)),
                  Text(
                    '- RM ${entry.value.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

// Recent Transaction Display
  Widget _buildRecentTransaction(ColorScheme colorScheme) {
    if (_recentTransactions.isEmpty) return const SizedBox();
    final tx = _recentTransactions.first;
    final rawDate = tx['date'];
    final date = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;

    return ListTile(
      leading: const Icon(Icons.fastfood),
      title: Text(tx['title'] ?? 'N/A'),
      subtitle: Text(
        date != null
            ? '${tx['category']} - ${DateFormat.Hm().format(date)}'
            : tx['category'] ?? 'Uncategorized',
      ),
      trailing: Text(
        '- RM ${tx['amount'].toStringAsFixed(2)}',
        style: TextStyle(color: colorScheme.error),
      ),
    );
  }
}
