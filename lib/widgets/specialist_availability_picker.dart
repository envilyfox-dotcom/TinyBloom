import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/specialist_availability.dart';

// Day-chip selector + per-day Start/End/"Available all day" cards for
// building a specialist's WeeklySchedule. Shared by both the onboarding
// flow and the edit-profile flow so they look and behave identically.
class WeeklyAvailabilityPicker extends StatelessWidget {
  final WeeklySchedule value;
  final ValueChanged<WeeklySchedule> onChanged;
  final String? errorText;

  const WeeklyAvailabilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  void _toggleDay(String day) {
    final updated = Map<String, DayAvailability>.from(value);
    if (updated.containsKey(day)) {
      updated.remove(day);
    } else {
      updated[day] = const DayAvailability(start: 9, end: 17);
    }
    onChanged(updated);
  }

  void _updateDay(String day, DayAvailability availability) {
    onChanged({...value, day: availability});
  }

  @override
  Widget build(BuildContext context) {
    final selectedDays = weekDayOrder.where(value.containsKey).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weekDayOrder.map((day) {
            return _DayChip(
              label: day,
              selected: value.containsKey(day),
              onTap: () => _toggleDay(day),
            );
          }).toList(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        for (final day in selectedDays)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _DayAvailabilityCard(
              day: day,
              availability: value[day]!,
              onChanged: (availability) => _updateDay(day, availability),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
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

class _DayAvailabilityCard extends StatelessWidget {
  final String day;
  final DayAvailability availability;
  final ValueChanged<DayAvailability> onChanged;

  const _DayAvailabilityCard({
    required this.day,
    required this.availability,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startOptions = [for (var h = 0; h < 24; h++) h];
    final endOptions = [for (var h = availability.start + 1; h <= 24; h++) h];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textLight.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Availability',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _HourDropdown(
                  label: 'Start',
                  value: availability.start,
                  options: startOptions,
                  enabled: !availability.allDay,
                  onChanged: (h) {
                    final newEnd = availability.end > h ? availability.end : h + 1;
                    onChanged(DayAvailability.of(start: h, end: newEnd));
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                child:
                    Icon(Icons.arrow_forward, size: 14, color: AppColors.textLight),
              ),
              Expanded(
                child: _HourDropdown(
                  label: 'End',
                  value: availability.end,
                  options: endOptions,
                  enabled: !availability.allDay,
                  onChanged: (h) {
                    onChanged(DayAvailability.of(start: availability.start, end: h));
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Checkbox(
                  value: availability.allDay,
                  activeColor: AppColors.rose,
                  onChanged: (checked) {
                    onChanged((checked ?? false)
                        ? DayAvailability.allDayAvailability()
                        : const DayAvailability(start: 9, end: 17));
                  },
                ),
              ),
              const Text(
                'Available all day',
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> options;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _HourDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Guard against the current value momentarily falling outside the
    // filtered options list (e.g. End options are recomputed from Start on
    // every rebuild) - DropdownButtonFormField requires its value to match
    // exactly one item.
    final items = options.contains(value) ? options : [value, ...options];

    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map((h) => DropdownMenuItem(value: h, child: Text(hourLabel(h))))
          .toList(),
      onChanged: enabled
          ? (h) {
              if (h != null) onChanged(h);
            }
          : null,
    );
  }
}
