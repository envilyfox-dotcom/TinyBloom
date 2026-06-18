import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/app_theme.dart';

const moodOptions = [
  {'emoji': '😊', 'label': 'Happy', 'color': AppColors.sage},
  {'emoji': '😐', 'label': 'Neutral', 'color': AppColors.textLight},
  {'emoji': '😢', 'label': 'Sad', 'color': AppColors.teal},
  {'emoji': '😴', 'label': 'Tired', 'color': AppColors.rose},
  {'emoji': '😰', 'label': 'Anxious', 'color': AppColors.gold},
  {'emoji': '🥰', 'label': 'Loved', 'color': AppColors.roseDeep},
];

String moodEmoji(String? mood) {
  if (mood == null || mood.isEmpty) return '📋';
  for (final m in moodOptions) {
    if (m['label'] == mood) return m['emoji'] as String;
  }
  return '📋';
}

Color moodColor(String? mood) {
  for (final m in moodOptions) {
    if (m['label'] == mood) return m['color'] as Color;
  }
  return AppColors.textLight;
}

// Accepts either a Postgres array (returned as a List) or a legacy
// comma-separated string from older rows, and normalizes to a string list.
List<String> asStringList(Object? value) {
  if (value == null) return const [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return value.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

// Small "back + logout" app bar shared by the logs screens.
PreferredSizeWidget logsAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
    ),
  );
}

// Solid filled pill (light pink "View", dark fills for Edit/Delete).
Widget pillButton(String label,
    {required Color bg, required Color fg, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

const viewColor = AppColors.rose;
const editColor = Color(0xFF6B5B56);
const deleteColor = Color(0xFF7A1F1F);
