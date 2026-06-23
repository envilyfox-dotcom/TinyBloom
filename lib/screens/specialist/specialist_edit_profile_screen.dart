import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class SpecialistEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? specialistProfile;

  const SpecialistEditProfileScreen({
    super.key,
    this.specialistProfile,
  });

  @override
  State<SpecialistEditProfileScreen> createState() =>
      _SpecialistEditProfileScreenState();
}

class _SpecialistEditProfileScreenState
    extends State<SpecialistEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _videoCallFeeCtrl;
  late TextEditingController _inPersonFeeCtrl;

  // Calendar state — keys are date-only DateTimes (midnight local)
  Set<DateTime> _selectedDates = {};

  // Calendar focus day (for the widget's internal state)
  DateTime _focusedDay = DateTime.now();

  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadProfile();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _videoCallFeeCtrl = TextEditingController();
    _inPersonFeeCtrl = TextEditingController();
  }

  /// Normalise a DateTime to midnight-local so Set equality works reliably.
  DateTime _normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSelected(DateTime day) =>
      _selectedDates.contains(_normalise(day));

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile();
      if (profile != null) {
        _nameCtrl.text = profile['full_name'] ?? '';
        _emailCtrl.text = profile['email'] ?? '';
      }

      final specialist = widget.specialistProfile ?? {};
      _videoCallFeeCtrl.text =
          (specialist['video_call_fee'] ?? '0').toString();
      _inPersonFeeCtrl.text =
          (specialist['in_person_fee'] ?? '0').toString();

      // Parse stored available_today string back into selected dates.
      // Format produced by _saveChanges: "2025-07-01, 2025-07-03, …"
      // We also gracefully ignore the old "Mon, Tue, …" format.
      final stored =
          (specialist['available_today'] as String? ?? '').trim();
      if (stored.isNotEmpty) {
        final Set<DateTime> parsed = {};
        for (final part in stored.split(',')) {
          final trimmed = part.trim();
          // Try ISO date first
          final dt = DateTime.tryParse(trimmed);
          if (dt != null) parsed.add(_normalise(dt));
        }
        if (parsed.isNotEmpty) {
          setState(() => _selectedDates = parsed);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _videoCallFeeCtrl.dispose();
    _inPersonFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Update base profile (name + email)
      await SupabaseService.updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });

      // Serialise selected dates as ISO strings so they can be parsed back.
      final sortedDates = _selectedDates.toList()..sort();
      final availableHoursStr = sortedDates
          .map((d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}')
          .join(', ');

      await SupabaseService.updateSpecialistProfile({
        'video_call_fee': double.parse(_videoCallFeeCtrl.text),
        'in_person_fee': double.parse(_inPersonFeeCtrl.text),
        'available_today': availableHoursStr,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving changes: $e'),
              backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: TBLoading());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name ──────────────────────────────────────────────
              _label('Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Email ─────────────────────────────────────────────
              _label('Email Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'your@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Video Call Fee ────────────────────────────────────
              _label('Video Call Fee (\$)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _videoCallFeeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'e.g., 50.00',
                  prefixIcon: Icon(Icons.videocam_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Fee is required';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── In-Person Fee ─────────────────────────────────────
              _label('In-Person Consultation Fee (\$)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _inPersonFeeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'e.g., 75.00',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Fee is required';
                  if (double.tryParse(v) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Available Days Calendar ───────────────────────────
              _label('Available Days for Consultation'),
              const SizedBox(height: 4),
              const Text(
                'Tap dates to mark yourself available. Tap again to deselect.',
                style: TextStyle(color: AppColors.textMid, fontSize: 12),
              ),
              const SizedBox(height: 12),

              TBCard(
                child: TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay:
                      DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  selectedDayPredicate: _isSelected,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      final key = _normalise(selectedDay);
                      if (_selectedDates.contains(key)) {
                        _selectedDates.remove(key);
                      } else {
                        _selectedDates.add(key);
                      }
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDay = focusedDay);
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),

              // Selected dates summary
              if (_selectedDates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Builder(builder: (context) {
                    final sorted = _selectedDates.toList()..sort();
                    final labels = sorted.map((d) =>
                        '${d.day}/${d.month}/${d.year}');
                    return Text(
                      '${_selectedDates.length} day${_selectedDates.length == 1 ? '' : 's'} selected: ${labels.join(', ')}',
                      style: const TextStyle(
                          color: AppColors.teal, fontSize: 12),
                    );
                  }),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No dates selected yet.',
                    style:
                        TextStyle(color: AppColors.textMid, fontSize: 12),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Save ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      );
}