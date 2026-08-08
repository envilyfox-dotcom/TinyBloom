import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../mum/consultation/consultation_helpers.dart';

class SpecialistOnboardingScreen extends StatefulWidget {
  const SpecialistOnboardingScreen({super.key});

  @override
  State<SpecialistOnboardingScreen> createState() =>
      _SpecialistOnboardingScreenState();
}

class _SpecialistOnboardingScreenState
    extends State<SpecialistOnboardingScreen> {
  final Set<String> _selectedDays = {};
  final Set<String> _selectedTimes = {};
  bool _saving = false;
  String? _error;

  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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

  String _formatSelectedTimes() => formatSelectedTimeRanges(_selectedTimes);

  String _availableHoursSummary() {
    final days = _formatSelectedDays();
    final times = _formatSelectedTimes();
    if (days.isEmpty && times.isEmpty) return '';
    if (days.isEmpty) return times;
    if (times.isEmpty) return days;
    return '$days\n$times';
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_selectedDays.isEmpty) {
      setState(() => _error = 'Please select at least one available day.');
      return;
    }
    if (_selectedTimes.isEmpty) {
      setState(() => _error = 'Please select at least one available time.');
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.updateSpecialistProfile({
        'available_today': _selectedTimes.toList(),
        'available_hours': _availableHoursSummary(),
      });

      if (mounted) {
        await context.read<AuthProvider>().refreshProfile();
        if (mounted) context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Something went wrong. Please check your connection and try again.');
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoCard(
                      icon: '📅',
                      title: 'Available Days',
                      subtitle:
                          'Choose the days mums can book a consultation with you.',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _weekDays.map((day) {
                            final selected = _selectedDays.contains(day);
                            return _PrettyChip(
                              label: day,
                              selected: selected,
                              onTap: () => setState(() {
                                selected
                                    ? _selectedDays.remove(day)
                                    : _selectedDays.add(day);
                              }),
                            );
                          }).toList(),
                        ),
                        if (_selectedDays.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Selected: ${_formatSelectedDays()}',
                            style: const TextStyle(
                                color: AppColors.teal, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      icon: '⏰',
                      title: 'Available Time Slots',
                      subtitle:
                          'Choose the times you are typically free to consult.',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: defaultConsultationTimes.map((slot) {
                            final selected = _selectedTimes.contains(slot);
                            return _PrettyChip(
                              label: slot,
                              selected: selected,
                              onTap: () => setState(() {
                                selected
                                    ? _selectedTimes.remove(slot)
                                    : _selectedTimes.add(slot);
                              }),
                            );
                          }).toList(),
                        ),
                        if (_selectedTimes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Selected: ${_formatSelectedTimes()}',
                            style: const TextStyle(
                                color: AppColors.teal, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.blush,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.rose.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Text('💡', style: TextStyle(fontSize: 26)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can always update your availability later from your profile.',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.blush,
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🌸', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'TinyBloom Setup',
                  style: TextStyle(
                    color: AppColors.roseDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Set Your Availability',
            style: TextStyle(
              color: AppColors.roseDeep,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Let mums know when they can book a consultation with you.',
            style: TextStyle(color: AppColors.textMid, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: const Icon(Icons.close, color: Colors.red, size: 16),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Complete Setup',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.textLight.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _PrettyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PrettyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blush : AppColors.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.rose
                : AppColors.textLight.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: AppColors.roseDeep),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.roseDeep : AppColors.textMid,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
