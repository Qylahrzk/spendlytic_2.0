import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class ExpenseCalendar extends StatefulWidget {
  final Map<DateTime, double> expensesByDay;
  final void Function(DateTime day)? onDaySelected;

  const ExpenseCalendar({
    required this.expensesByDay,
    this.onDaySelected,
    super.key,
  });

  @override
  State<ExpenseCalendar> createState() => _ExpenseCalendarState();
}

class _ExpenseCalendarState extends State<ExpenseCalendar> {
  late DateTime _focusedDay;
  late DateTime _weekStartDate;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _weekStartDate = _getStartOfWeek(_focusedDay);
  }

  DateTime _getStartOfWeek(DateTime day) {
    final diff = day.weekday - DateTime.monday;
    return DateTime(day.year, day.month, day.day - diff);
  }

  DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _goToPrevWeek() {
    setState(() {
      _weekStartDate = _weekStartDate.subtract(const Duration(days: 7));
      _focusedDay = _weekStartDate;
    });
  }

  void _goToNextWeek() {
    setState(() {
      _weekStartDate = _weekStartDate.add(const Duration(days: 7));
      _focusedDay = _weekStartDate;
    });
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _focusedDay = picked;
        _weekStartDate = _getStartOfWeek(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = _weekStartDate.add(const Duration(days: 6));
    final monthLabel = DateFormat.yMMM().format(_weekStartDate);

    return Column(
      children: [
        // Header with arrows and month label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goToPrevWeek,
            ),
            TextButton(
              onPressed: _pickMonthYear,
              child: Text(
                monthLabel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _goToNextWeek,
            ),
          ],
        ),
        // Days of week (Mon–Sun)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (i) {
            final day = _weekStartDate.add(Duration(days: i));
            return Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat.E().format(day),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    day.day.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        // Calendar showing entire month, but with colored dots
        SizedBox(
          height: 300,
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            headerVisible: false,
            calendarFormat: CalendarFormat.month,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final normalizedDay = _normalize(day);
                final amount =
                    widget.expensesByDay[normalizedDay] ?? 0;
                final color = _getDayColor(amount);

                return Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: color == Colors.transparent
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                );
              },
            ),
            selectedDayPredicate: (day) {
              if (widget.onDaySelected == null) return false;
              return widget.expensesByDay
                  .containsKey(_normalize(day));
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              if (widget.onDaySelected != null) {
                widget.onDaySelected!(_normalize(selectedDay));
              }
            },
          ),
        ),
      ],
    );
  }

  Color _getDayColor(double amount) {
    if (amount == 0) return Colors.transparent;
    if (amount < 50) return Colors.lightGreen.withOpacity(0.5);
    if (amount < 200) return Colors.orange.withOpacity(0.5);
    return Colors.red.withOpacity(0.5);
  }
}
