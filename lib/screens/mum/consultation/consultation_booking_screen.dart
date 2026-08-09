import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/singapore_time.dart';
import '../../../utils/specialist_availability.dart';
import 'consultation_helpers.dart';

class ConsultationBookingScreen extends StatefulWidget {
  final Map<String, dynamic> provider;
  final String type;
  final Map<String, dynamic>? consultation;

  const ConsultationBookingScreen({
    super.key,
    required this.provider,
    required this.type,
    this.consultation,
  });

  @override
  State<ConsultationBookingScreen> createState() =>
      _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState extends State<ConsultationBookingScreen> {
  late DateTime _month;
  late DateTime _selectedDate;
  String? _selectedTime;

  final _purposeCtrl = TextEditingController();
  final Set<String> _bookedTimes = <String>{};
  bool _loadingBookedTimes = false;

  bool get _isReschedule => widget.consultation != null;

  static const List<String> _fallbackTimeSlots = [
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '1:00 PM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '5:00 PM',
    '6:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    final today = sgtNow();
    _selectedDate = sgtWallClock(today.year, today.month, today.day);
    _month = sgtWallClock(today.year, today.month, 1);
    _purposeCtrl.text = widget.consultation?['purpose'] as String? ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookedTimesForSelectedDate();
    });
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  WeeklySchedule get _providerSchedule =>
      weeklyScheduleFromJson(widget.provider['available_schedule']);

  bool _isProviderAvailableOnDate(DateTime date) {
    final schedule = _providerSchedule;
    if (schedule.isEmpty) return true;
    return isDateAvailableForSchedule(schedule, date);
  }

  List<String> _slotsForDate(DateTime date) {
    final schedule = _providerSchedule;
    if (schedule.isEmpty) return _fallbackTimeSlots;
    return slotsForDate(schedule, date);
  }

  bool _isPastDate(DateTime date) {
    final today = sgtNow();
    final todayStart = sgtWallClock(today.year, today.month, today.day);
    final dateStart = sgtWallClock(date.year, date.month, date.day);
    return dateStart.isBefore(todayStart);
  }

  String _normaliseTime(String? value) {
    if (value == null || value.trim().isEmpty) return '';

    var clean = value.trim();

    if (clean.toLowerCase().startsWith('today')) {
      clean = clean.substring(5).trim();
    }

    if (clean.contains('-')) {
      clean = clean.split('-').first.trim();
    }

    try {
      clean = timeOnly(clean).trim();
    } catch (_) {}

    clean = clean
        .toUpperCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final formats = <DateFormat>[
      DateFormat('h:mm a'),
      DateFormat('h a'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
    ];

    for (final format in formats) {
      try {
        final parsed = format.parseStrict(clean);
        return DateFormat('h:mm a').format(parsed);
      } catch (_) {}
    }

    return clean;
  }

  DateTime? _slotDateTime(DateTime date, String time) {
    final clean = _normaliseTime(time);

    final formats = <DateFormat>[
      DateFormat('h:mm a'),
      DateFormat('h a'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
    ];

    for (final format in formats) {
      try {
        final parsed = format.parseStrict(clean);
        return sgtWallClock(
          date.year,
          date.month,
          date.day,
          parsed.hour,
          parsed.minute,
        );
      } catch (_) {}
    }

    return null;
  }

  List<String> get _providerIdCandidates {
    final ids = <String>{};

    void addValue(dynamic value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isNotEmpty) ids.add(text);
    }

    addValue(widget.provider['user_id']);
    addValue(widget.provider['id']);

    final profile = widget.provider['profiles'];
    if (profile is Map<String, dynamic>) {
      addValue(profile['id']);
      addValue(profile['user_id']);
    }

    return ids.toList();
  }

  Future<void> _loadBookedTimesForSelectedDate() async {
    final providerIds = _providerIdCandidates;

    setState(() {
      _loadingBookedTimes = true;
      _bookedTimes.clear();
      _selectedTime = null;
    });

    if (providerIds.isEmpty) {
      if (mounted) {
        setState(() => _loadingBookedTimes = false);
      }
      return;
    }

    try {
      final rawBooked = await SupabaseService.getBookedConsultationSlots(
        providerIds,
        _selectedDate,
      );

      final booked = <String>{
        for (final time in rawBooked)
          if (_normaliseTime(time).isNotEmpty) _normaliseTime(time),
      };

      if (mounted) {
        setState(() {
          _bookedTimes
            ..clear()
            ..addAll(booked);
          _loadingBookedTimes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bookedTimes.clear();
          _loadingBookedTimes = false;
        });
      }
    }
  }

  List<String> get _visibleTimeSlots {
    if (_isPastDate(_selectedDate)) return [];
    if (!_isProviderAvailableOnDate(_selectedDate)) return [];

    final now = sgtNow();

    return _slotsForDate(_selectedDate).where((time) {
      final normalised = _normaliseTime(time);

      if (_bookedTimes.contains(normalised)) return false;

      if (_isSameDay(_selectedDate, now)) {
        final slot = _slotDateTime(_selectedDate, normalised);
        if (slot == null) return true;
        return slot.isAfter(now);
      }

      return true;
    }).toList();
  }

  bool _isTooCloseToBook(String normalisedTime) {
    final now = sgtNow();
    if (!_isSameDay(_selectedDate, now)) return false;
    final slot = _slotDateTime(_selectedDate, normalisedTime);
    if (slot == null) return false;
    return slot.difference(now) <= minBookingNotice;
  }

  Future<void> _selectDate(DateTime date) async {
    if (_isPastDate(date)) return;

    setState(() {
      _selectedDate = sgtWallClock(date.year, date.month, date.day);
      _selectedTime = null;
    });

    await _loadBookedTimesForSelectedDate();
  }

  void _continue() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a date and time.')),
      );
      return;
    }

    context.push('/consultation/confirm', extra: {
      'provider': widget.provider,
      'type': widget.type,
      'date': _selectedDate,
      'time': _selectedTime,
      'purpose': _purposeCtrl.text.trim(),
      'consultationId': widget.consultation?['id'],
      'previousScheduledDate': widget.consultation?['scheduled_date'],
      'previousScheduledTime': widget.consultation?['scheduled_time'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.provider['profiles'] as Map<String, dynamic>? ?? {};
    final name = profile['full_name'] as String? ??
        widget.provider['name'] as String? ??
        'this provider';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isReschedule ? 'Reschedule Consultation' : 'Book Consultation',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isReschedule
                  ? 'Reschedule Consultation'
                  : 'Consultation Booking',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              _isReschedule
                  ? 'Choose a new date and time with $name.'
                  : 'Select your preferred date and time with $name.',
              style: const TextStyle(color: AppColors.textMid, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text(
              '1. Date',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildCalendar(),
            const SizedBox(height: 20),
            const Text(
              '2. Available Time Slots',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEE, d MMM yyyy').format(_selectedDate),
              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_loadingBookedTimes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.rose),
                ),
              )
            else if (_visibleTimeSlots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No available timings for this date. Please choose another date.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _visibleTimeSlots.map((time) {
                  final normalised = _normaliseTime(time);
                  final selected = _selectedTime == normalised;
                  final tooClose = _isTooCloseToBook(normalised);

                  return GestureDetector(
                    onTap: tooClose
                        ? null
                        : () => setState(() => _selectedTime = normalised),
                    child: Opacity(
                      opacity: tooClose ? 0.4 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.sage
                              : AppColors.sage.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          normalised,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.sage,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
            const Text(
              '3. Consultation Purpose',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purposeCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Discuss morning sickness & fatigue',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = sgtWallClock(_month.year, _month.month, 1);
    final daysInMonth = sgtWallClock(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstDayOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final today = sgtNow();
    final todayOnly = sgtWallClock(today.year, today.month, today.day);

    final previousMonthDisabled = firstDayOfMonth.isBefore(
      sgtWallClock(today.year, today.month, 1),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_month),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: previousMonthDisabled
                          ? AppColors.textLight.withValues(alpha: 0.4)
                          : AppColors.textDark,
                    ),
                    onPressed: previousMonthDisabled
                        ? null
                        : () {
                            setState(() {
                              _month = sgtWallClock(
                                  _month.year, _month.month - 1, 1);
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _month = sgtWallClock(_month.year, _month.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'])
                Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (int i = 0; i < totalCells; i++)
                if (i < leadingBlanks)
                  const SizedBox.shrink()
                else
                  _dayCell(i - leadingBlanks + 1, todayOnly),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int day, DateTime todayOnly) {
    final date = sgtWallClock(_month.year, _month.month, day);
    final isPast = date.isBefore(todayOnly);
    final isAvailable = _isProviderAvailableOnDate(date);
    final isSelected = _isSameDay(_selectedDate, date);

    return GestureDetector(
      onTap: (isPast || !isAvailable) ? null : () => _selectDate(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.rose : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? Colors.white
                : isPast || !isAvailable
                    ? AppColors.textLight.withValues(alpha: 0.5)
                    : AppColors.textDark,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
