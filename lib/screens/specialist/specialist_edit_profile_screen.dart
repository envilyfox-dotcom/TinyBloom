import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../mum/consultation/consultation_helpers.dart';
import 'package:go_router/go_router.dart';

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

  bool _saving = false;
  bool _loading = true;
  String? _photoUrl;
  bool _photoBusy = false;
  List<Map<String, dynamic>> _specialties = [];
  int? _specialtyId;

  String get _specialtyName {
    for (final s in _specialties) {
      if (s['id'] == _specialtyId) return s['name'] as String? ?? 'Unset';
    }
    return 'Unset';
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadProfile();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
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
    final ordered =
        defaultConsultationTimes.where(_selectedTimes.contains).toList();
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
        _photoUrl = profile['profile_picture_url'] as String?;
      }

      final specialist = widget.specialistProfile ?? {};
      _specialtyId = specialist['specialty_id'] as int?;
      _specialties = await SupabaseService.getSpecialties();

      final availableToday = specialist['available_today'];
      if (availableToday != null) {
        final selectedTimes = availableTimesOnly(availableToday);
        if (selectedTimes.isNotEmpty) {
          setState(() => _selectedTimes.addAll(selectedTimes));
        }
      }

      final availableHours = specialist['available_hours'];
      if (availableHours is String && availableHours.trim().isNotEmpty) {
        final days = availableDaysFromHours(availableHours);
        if (days.isNotEmpty) {
          setState(() => _selectedDays.addAll(days));
        }

        final lines = availableHours
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
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

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked == null) return;

    setState(() => _photoBusy = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final url = await SupabaseService.uploadProfilePicture(
          bytes, ext.length <= 4 ? ext : 'jpg');
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _confirmRemovePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text(
            'Are you sure you want to remove your profile photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _removePhoto();
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await SupabaseService.removeProfilePicture();
      if (mounted) setState(() => _photoUrl = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _dayError =
          _selectedDays.isEmpty ? 'Please select at least one day.' : null;
      _timeError =
          _selectedTimes.isEmpty ? 'Please select at least one time.' : null;
    });

    if (!_formKey.currentState!.validate() ||
        _dayError != null ||
        _timeError != null) {
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
              // ── Profile Photo ─────────────────────────────────────
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                      backgroundImage:
                          _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child: _photoBusy
                          ? const CircularProgressIndicator(
                              color: AppColors.rose)
                          : (_photoUrl == null
                              ? Text(
                                  _nameCtrl.text.isNotEmpty
                                      ? _nameCtrl.text[0].toUpperCase()
                                      : 'D',
                                  style: const TextStyle(
                                      color: AppColors.roseDeep,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700))
                              : null),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _photoBusy ? null : _pickPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.rose,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_photoUrl != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: _photoBusy ? null : _confirmRemovePhoto,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    label: const Text('Remove Photo',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Name ──────────────────────────────────────────────
              _label('Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // ── Email ─────────────────────────────────────────────
              _label('Email Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Specialty ─────────────────────────────────────────
              _label('Specialty'),
              const SizedBox(height: 4),
              const Text(
                'Determines which article review group(s) you belong to. ',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medical_information_outlined,
                        color: AppColors.textMid),
                    const SizedBox(width: 12),
                    Text(_specialtyName, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Edit Password ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/change-password'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    foregroundColor: AppColors.textDark,
                    side: BorderSide(
                        color: AppColors.teal.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, color: AppColors.textDark),
                          SizedBox(width: 8),
                          Text('Edit Password'),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textDark),
                    ],
                  ),
                ),
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
                    style: const TextStyle(color: AppColors.teal, fontSize: 12),
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
                    style: const TextStyle(color: AppColors.teal, fontSize: 12),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _timeError ?? 'No time slots selected yet.',
                    style: TextStyle(
                      color:
                          _timeError != null ? Colors.red : AppColors.textMid,
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      );
}
