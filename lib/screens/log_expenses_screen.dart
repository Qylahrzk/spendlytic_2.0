import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../services/db_service.dart';
import '../../services/currency_service.dart';
// ignore: unused_import
import '../../models/user_model.dart';

class LogExpensesScreen extends StatefulWidget {
  const LogExpensesScreen({super.key});

  @override
  State<LogExpensesScreen> createState() => _LogExpensesScreenState();
}

class _LogExpensesScreenState extends State<LogExpensesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedCategory = 'General';

  final List<String> _categories = [
    'General',
    'Food',
    'Transportation',
    'Shopping',
  ];

  double _totalExpensesMYR = 0;
  Map<String, double> _categoryTotalsMYR = {};
  List<Map<String, dynamic>> _expenses = [];

  // Currency info
  String _currency = 'MYR (RM)';
  String _currencySymbol = 'RM';
  double _currencyRate = 1.0;

  final Map<String, IconData> _categoryIcons = {
    'General': Icons.category,
    'Food': Icons.fastfood,
    'Transportation': Icons.directions_car,
    'Shopping': Icons.shopping_bag,
  };

  @override
  void initState() {
    super.initState();
    _loadUserCurrency();
    _fetchExpenses();
  }

  /// Loads user's currency preference from DB
  Future<void> _loadUserCurrency() async {
    final user = await DBService().getUser();

    if (user != null) {
      final rate = CurrencyService.conversionRates[user.defaultCurrency] ?? 1.0;
      setState(() {
        _currency = user.defaultCurrency;
        _currencyRate = rate;
        _currencySymbol = CurrencyService.getSymbol(_currency);
      });
    }
  }

  /// Loads all expenses from the transactions table
  Future<void> _fetchExpenses() async {
    final db = await DBService().database;

    final data = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: ['expense'],
      orderBy: 'date DESC',
    );

    double total = 0;
    Map<String, double> catTotals = {};

    for (var exp in data) {
      final amount = exp['amount'] as num?;
      total += amount?.toDouble() ?? 0;
      final cat = exp['category'] as String? ?? 'General';
      catTotals[cat] = (catTotals[cat] ?? 0) + (amount?.toDouble() ?? 0);
    }

    setState(() {
      _expenses = data;
      _totalExpensesMYR = total;
      _categoryTotalsMYR = catTotals;
    });
  }

  /// Adds a new expense record to the DB
  Future<void> _addExpense(String title, double amount, String category) async {
    final db = await DBService().database;

    final expense = {
      'title': title,
      'amount': amount,
      'category': category,
      'type': 'expense',
      'date': DateTime.now().toIso8601String(),
    };

    await db.insert('transactions', expense);
    await _fetchExpenses();
  }

  /// Deletes all expenses
  Future<void> _clearExpenses() async {
    final db = await DBService().database;

    await db.delete(
      'transactions',
      where: 'type = ?',
      whereArgs: ['expense'],
    );

    await _fetchExpenses();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All expenses have been cleared!')),
    );
  }

  /// Opens a dialog to manually add an expense
  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount ($_currencySymbol)',
              ),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = _titleController.text.trim();
              final amountText = _amountController.text.trim();
              if (title.isNotEmpty && amountText.isNotEmpty) {
                final amount = double.tryParse(amountText);
                if (amount != null) {
                  final amountInMYR = amount / _currencyRate;
                  _addExpense(title, amountInMYR, _selectedCategory);
                  _titleController.clear();
                  _amountController.clear();
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid amount entered!')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Picks an image from gallery and scans text
  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      String scannedText = recognizedText.text;
      textRecognizer.close();
      _showScannedTextDialog(scannedText);
    }
  }

  /// Shows scanned text in a dialog for confirmation
  void _showScannedTextDialog(String scannedText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanned Receipt'),
        content: SingleChildScrollView(child: Text(scannedText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _processScannedText(scannedText);
              Navigator.pop(context);
            },
            child: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }

  /// Attempts to extract title and amount from scanned text
  void _processScannedText(String text) {
    final title = _extractTitleFromText(text);
    final amount = _extractAmountFromText(text);
    if (title != null && amount != null) {
      // Save as amount in MYR
      final amountInMYR = amount / _currencyRate;
      _addExpense(title, amountInMYR, 'General');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to extract title or amount.')),
      );
    }
  }

  String? _extractTitleFromText(String text) {
    final lines = text.split('\n');
    return lines.isNotEmpty ? lines[0].trim() : null;
  }

  /// Extracts an RM amount from scanned text
  double? _extractAmountFromText(String text) {
    final regex = RegExp(r'RM\s?\d+(\.\d{1,2})?');
    final match = regex.firstMatch(text);
    if (match != null) {
      final clean = match.group(0)?.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(clean ?? '');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final colorScheme = Theme.of(context).colorScheme;

//AppBar with title and actions
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
              "LOG EXPENSES",
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
            onPressed: _clearExpenses,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _pickReceiptImage,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTotalExpensesCard(colorScheme),
            _buildCategoryOverview(colorScheme),
            _buildExpenseList(colorScheme),
          ],
        ),
      ),
    );
  }

  /// Displays the total expenses converted to user's preferred currency
  Widget _buildTotalExpensesCard(ColorScheme colorScheme) {
    final convertedTotal = _totalExpensesMYR * _currencyRate;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),

      // This is the total expenses card (Gradient)
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Total Expenses",
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "$_currencySymbol ${convertedTotal.toStringAsFixed(2)}",
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays categories as icons with totals converted to user's currency
  Widget _buildCategoryOverview(ColorScheme colorScheme) {
    if (_categoryTotalsMYR.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          "No expenses to display.",
          style: TextStyle(color: colorScheme.onSurface),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _categoryTotalsMYR.entries.map((entry) {
          final icon = _categoryIcons[entry.key] ?? Icons.category;
          final convertedTotal = entry.value * _currencyRate;

          return Container(
            width: 100,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "- $_currencySymbol ${convertedTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Displays the list of all expense records converted to user's currency
  Widget _buildExpenseList(ColorScheme colorScheme) {
    if (_expenses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No expenses logged yet."),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final exp = _expenses[index];
        final convertedAmount =
            (exp['amount'] as double? ?? 0) * _currencyRate;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: ListTile(
            leading: Icon(
              _categoryIcons[exp['category']] ?? Icons.category,
              color: colorScheme.primary,
            ),
            title: Text(
              exp['title'] ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${exp['category']} - ${DateFormat.yMMMd().format(DateTime.parse(exp['date']))}",
              style: TextStyle(color: colorScheme.onSurface),
            ),
            trailing: Text(
              '$_currencySymbol ${convertedAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
