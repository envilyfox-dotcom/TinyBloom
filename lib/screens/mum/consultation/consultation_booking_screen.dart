import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_theme.dart';

// ── Consultation Booking ──────────────────────────────────────────
class ConsultationBookingScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final String type;
  const ConsultationBookingScreen(
      {super.key, required this.provider, required this.type});
  @override
  State<ConsultationBookingScreen> createState() =>
      _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState
    extends State<ConsultationBookingScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  String? _selectedTime;
  final _purposeCtrl = TextEditingController();

  // Derived from the provider's own "Available Today" times (shown on their
  // selection card), each turned into a full hour-long start–end range, so
  // the slots offered here always match what was advertised on that card.
  List<String> get _timeSlots {
    final available = (widget.provider['available_today'] as List?)
        ?.map((e) => e.toString())
        .toList();
    if (available == null || available.isEmpty) {
      return const ['9:00 AM - 10:00 AM', '2:00 PM - 3:00 PM', '5:00 PM - 6:00 PM'];
    }
    return available.map(_toRange).toList();
  }

  String _toRange(String start) {
    try {
      final time = DateFormat('h:mm a').parse(start);
      final end = time.add(const Duration(hours: 1));
      return '$start - ${DateFormat('h:mm a').format(end)}';
    } catch (_) {
      return start;
    }
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _continue() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a date and time.')));
      return;
    }
    context.push('/consultation/confirm', extra: {
      'provider': widget.provider,
      'type': widget.type,
      'date': _selectedDate,
      'time': _selectedTime,
      'purpose': _purposeCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.provider['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ?? 'this provider';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consultation Booking',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            Text('Select your preferred date and time with $name.',
                style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
            const SizedBox(height: 20),
            const Text('1. Date',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            _buildCalendar(),
            const SizedBox(height: 20),
            const Text('2. Available Time Slots',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((t) {
                  final sel = _selectedTime == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTime = t),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: sel
                              ? AppColors.sage
                              : AppColors.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(t,
                          style: TextStyle(
                              color: sel ? Colors.white : AppColors.sage,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  );
                }).toList()),
            const SizedBox(height: 20),
            const Text('3. Consultation Purpose',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purposeCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'e.g. Discuss morning sickness & fatigue'),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Continue',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstDayOfMonth.weekday % 7; // Sun=0 .. Sat=6
    final totalCells = leadingBlanks + daysInMonth;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMMM yyyy').format(_month),
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month - 1))),
                IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1))),
              ]),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'])
                Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600))),
              for (int i = 0; i < totalCells; i++)
                if (i < leadingBlanks)
                  const SizedBox.shrink()
                else
                  _dayCell(i - leadingBlanks + 1, todayMidnight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int day, DateTime todayMidnight) {
    final date = DateTime(_month.year, _month.month, day);
    final isPast = date.isBefore(todayMidnight);
    final isSelected = _selectedDate != null && _isSameDay(_selectedDate!, date);
    return GestureDetector(
      onTap: isPast ? null : () => setState(() => _selectedDate = date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.rose : Colors.transparent),
        alignment: Alignment.center,
        child: Text('$day',
            style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : (isPast
                        ? AppColors.textLight.withValues(alpha: 0.5)
                        : AppColors.textDark),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}
