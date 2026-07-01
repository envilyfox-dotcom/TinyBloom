import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/app_theme.dart';

const moodOptions = [
  {'emoji': '😊', 'label': 'Happy', 'color': AppColors.sage},
  {'emoji': '🥰', 'label': 'Excited', 'color': AppColors.roseDeep},
  {'emoji': '😌', 'label': 'Calm', 'color': AppColors.teal},
  {'emoji': '😴', 'label': 'Tired', 'color': AppColors.rose},
  {'emoji': '😔', 'label': 'Sad', 'color': AppColors.teal},
  {'emoji': '😟', 'label': 'Worried', 'color': AppColors.gold},
  {'emoji': '😣', 'label': 'Stressed', 'color': AppColors.gold},
  {'emoji': '😤', 'label': 'Irritable', 'color': AppColors.roseDeep},
  {'emoji': '😢', 'label': 'Emotional', 'color': AppColors.teal},
  {'emoji': '🤢', 'label': 'Unwell', 'color': AppColors.sage},
  {'emoji': '😐', 'label': 'Neutral', 'color': AppColors.textLight},
  {'emoji': '😍', 'label': 'Grateful', 'color': AppColors.roseDeep},
  {'emoji': '🥺', 'label': 'Overwhelmed', 'color': AppColors.gold},
  {'emoji': '😬', 'label': 'Anxious', 'color': AppColors.gold},
  {'emoji': '😇', 'label': 'Hopeful', 'color': AppColors.sage},
  {'emoji': '🤗', 'label': 'Loved', 'color': AppColors.roseDeep},
  {'emoji': '😩', 'label': 'Exhausted', 'color': AppColors.rose},
  {'emoji': '🤕', 'label': 'Sick', 'color': AppColors.teal},
  {'emoji': '😡', 'label': 'Frustrated', 'color': AppColors.roseDeep},
  {'emoji': '🤍', 'label': 'Peaceful', 'color': AppColors.sage},
  {'emoji': '🥳', 'label': 'Energetic', 'color': AppColors.gold},
  {'emoji': '😵', 'label': 'Dizzy', 'color': AppColors.teal},
  {'emoji': '🤰', 'label': 'Blessed', 'color': AppColors.rose},
  {'emoji': '😎', 'label': 'Confident', 'color': AppColors.sage},
  {'emoji': '💪', 'label': 'Strong', 'color': AppColors.teal},
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

  // Already a Dart List
  if (value is List) {
    return value
        .map((e) => e.toString())
        .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  var text = value.toString().trim();

  if (text.isEmpty) return const [];

  // PostgreSQL array: {A,B}
  if (text.startsWith('{') && text.endsWith('}')) {
    text = text.substring(1, text.length - 1);
  }

  // JSON array: ["A","B"]
  if (text.startsWith('[') && text.endsWith(']')) {
    text = text.substring(1, text.length - 1);
  }

  return text
      .split(',')
      .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
      .where((e) => e.isNotEmpty)
      .toList();
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    ),
  );
}

const viewColor = AppColors.rose;
const editColor = Color(0xFF6B5B56);
const deleteColor = Color(0xFF7A1F1F);
