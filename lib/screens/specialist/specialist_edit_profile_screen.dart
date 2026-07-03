import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../mum/consultation/consultation_helpers.dart';

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

  final Set<String> _selectedDays = {};
  final Set<String> _selectedTimes = {};
  String? _dayError;
  String? _timeError;

  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const Map<String, String> _weekDayAliases = {
    'mon': 'Monday',
    'monday': 'Monday',
    'tue': 'Tuesday',
    'tues': 'Tuesday',
    'tuesday': 'Tuesday',
    'wed': 'Wednesday',
    'weds': 'Wednesday',
    'wednesday': 'Wednesday',
    'thu': 'Thursday',
    'thurs': 'Thursday',
    'thursday': 'Thursday',
    'fri': 'Friday',
    'friday': 'Friday',
    'sat': 'Saturday',
    'saturday': 'Saturday',
    'sun': 'Sunday',
    'sunday': 'Sunday',
  };

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

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is num) return value.toString();
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _parseWeekDay(String text) {
    final clean = text.trim().toLowerCase();
    if (_weekDayAliases.containsKey(clean)) return _weekDayAliases[clean]!;
    return '';
  }

  String _formatSelectedDays() {
    if (_selectedDays.isEmpty) return '';

    final selectedIndexes = _weekDays
        .asMap()
        .entries
        .where((entry) => _selectedDays.contains(entry.value))
        .map((entry) => entry.key)
        .toList();

    if (selectedIndexes.length == 1) {
      return _weekDays[selectedIndexes.first];
    }

    final parts = <String>[];
    int rangeStart = selectedIndexes.first;
    int rangeEnd = rangeStart;

    void addRange() {
      if (rangeStart == rangeEnd) {
        parts.add(_weekDays[rangeStart]);
      } else {
        parts.add('${_weekDays[rangeStart]} - ${_weekDays[rangeEnd]}');
      }
    }

    for (var i = 1; i < selectedIndexes.length; i++) {
      final current = selectedIndexes[i];
      if (current == rangeEnd + 1) {
        rangeEnd = current;
      } else {
        addRange();
        rangeStart = rangeEnd = current;
      }
    }

    addRange();
    return parts.join(', ');
  }

  String _formatSelectedTimes() {
    if (_selectedTimes.isEmpty) return '';
    final ordered = defaultConsultationTimes
        .where(_selectedTimes.contains)
        .toList();
    if (ordered.isEmpty) {
      final fallback = _selectedTimes.toList()..sort();
      return fallback.length == 1 ? fallback.first : fallback.join(', ');
    }
    return ordered.length == 1 ? ordered.first : ordered.join(', ');
  }

  String _availableHoursSummary() {
    final days = _formatSelectedDays();
    final times = _formatSelectedTimes();
    if (days.isEmpty && times.isEmpty) return '';
    if (days.isEmpty) return times;
    if (times.isEmpty) return days;
    return '$days\n$times';
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile();
      if (profile != null) {
        _nameCtrl.text = profile['full_name'] ?? '';
        _emailCtrl.text = profile['email'] ?? '';
      }

      final specialist = widget.specialistProfile ?? {};
      _videoCallFeeCtrl.text = _stringValue(
          specialist['video_call_fee'],
          fallback: '0');
      _inPersonFeeCtrl.text = _stringValue(
          specialist['in_person_fee'],
          fallback: '0');

      final availableToday = specialist['available_today'];
      if (availableToday != null) {
        final selectedTimes = availableTimesOnly(availableToday);
        if (selectedTimes.isNotEmpty) {
          setState(() => _selectedTimes.addAll(selectedTimes));
        }
      }

      final availableHours = specialist['available_hours'];
      if (availableHours is String && availableHours.trim().isNotEmpty) {
        final lines = availableHours
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          final dayLine = lines.first;
          final days = dayLine
              .split(RegExp(r'[,-]'))
              .map((part) => _parseWeekDay(part))
              .where((day) => day.isNotEmpty)
              .toSet();
          if (days.isNotEmpty) {
            setState(() => _selectedDays.addAll(days));
          }
        }
        if (lines.length > 1) {
          final timeLine = lines.sublist(1).join(', ');
          final parsedTimes = availableTimesOnly(timeLine);
          if (parsedTimes.isNotEmpty) {
            setState(() => _selectedTimes.addAll(parsedTimes));
          }
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
    setState(() {
      _dayError = _selectedDays.isEmpty ? 'Please select at least one day.' : null;
      _timeError = _selectedTimes.isEmpty ? 'Please select at least one time.' : null;
    });

    if (!_formKey.currentState!.validate() || _dayError != null || _timeError != null) {
      return;
    }

    setState(() => _saving = true);

    try {
      // Update base profile (name + email)
      await SupabaseService.updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });

      await SupabaseService.updateSpecialistProfile({
        'video_call_fee': double.parse(_videoCallFeeCtrl.text),
        'in_person_fee': double.parse(_inPersonFeeCtrl.text),
        'available_today': _selectedTimes.toList(),
        'available_hours': _availableHoursSummary(),
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

              // ── Available Days ─────────────────────────────────
              _label('Available Days for Consultation'),
              const SizedBox(height: 4),
              const Text(
                'Select the days you are available for consultation.',
                style: TextStyle(color: AppColors.textMid, fontSize: 12),
              ),
              const SizedBox(height: 12),

              TBCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekDays.map((day) {
                      final selected = _selectedDays.contains(day);
                      return ChoiceChip(
                        label: Text(day),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                            _dayError = _selectedDays.isEmpty
                                ? 'Please select at least one day.'
                                : null;
                          });
                        },
                        selectedColor: AppColors.teal.withValues(alpha: 0.18),
                        backgroundColor: AppColors.blush,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.teal : AppColors.textDark,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              if (_selectedDays.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Selected: ${_formatSelectedDays()}',
                    style:
                        const TextStyle(color: AppColors.teal, fontSize: 12),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _dayError ?? 'No days selected yet.',
                    style: TextStyle(
                      color: _dayError != null ? Colors.red : AppColors.textMid,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Available Time Slots ───────────────────────────
              _label('Available Time Slots for Consultation'),
              const SizedBox(height: 4),
              const Text(
                'Select the times you are available for consultation.',
                style: TextStyle(color: AppColors.textMid, fontSize: 12),
              ),
              const SizedBox(height: 12),

              TBCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: defaultConsultationTimes.map((slot) {
                      final selected = _selectedTimes.contains(slot);
                      return ChoiceChip(
                        label: Text(slot),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedTimes.add(slot);
                            } else {
                              _selectedTimes.remove(slot);
                            }
                            _timeError = _selectedTimes.isEmpty
                                ? 'Please select at least one time.'
                                : null;
                          });
                        },
                        selectedColor: AppColors.teal.withValues(alpha: 0.18),
                        backgroundColor: AppColors.blush,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.teal : AppColors.textDark,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              if (_selectedTimes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Selected: ${_formatSelectedTimes()}',
                    style:
                        const TextStyle(color: AppColors.teal, fontSize: 12),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _timeError ?? 'No time slots selected yet.',
                    style: TextStyle(
                      color: _timeError != null ? Colors.red : AppColors.textMid,
                      fontSize: 12,
                    ),
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