import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _notifications = [];

  final filters = const [
    'All',
    'Emergency',
    'Consultation',
    'Milestone',
    'Education',
    'Reminder',
    'AI',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  String _normaliseType(dynamic rawType) {
    final type = (rawType ?? 'general').toString().trim().toLowerCase();
    final clean = type.replaceAll(RegExp(r'[\s_-]+'), '');

    if ([
      'appointment',
      'appointments',
      'consultation',
      'consultations',
      'booking',
      'bookings',
    ].contains(clean)) {
      return 'consultation';
    }

    if ([
      'emergency',
      'emergencies',
      'emergencys',
      'urgent',
      'alert',
      'activealert',
      'emergencyalert',
    ].contains(clean)) {
      return 'emergency';
    }

    if ([
      'reminder',
      'reminders',
      'dailyreminder',
      'healthreminder',
      'waterreminder',
      'hydration',
    ].contains(clean)) {
      return 'reminder';
    }

    if ([
      'milestone',
      'milestones',
      'pregnancymilestone',
      'babydevelopment',
      'development',
    ].contains(clean)) {
      return 'milestone';
    }

    if ([
      'education',
      'educational',
      'article',
      'articles',
      'learn',
      'learning',
      'resource',
      'resources',
      'faq',
      'faqs',
    ].contains(clean)) {
      return 'education';
    }

    if ([
      'ai',
      'aitip',
      'aiadvice',
      'airecommendation',
      'airecommendations',
    ].contains(clean)) {
      return 'ai';
    }

    return type.isEmpty ? 'general' : type;
  }

  DateTime _createdAt(Map<String, dynamic> item) {
    return DateTime.tryParse(item['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }



  int _currentPregnancyWeek(Map<String, dynamic>? pregnancyProfile) {
    if (pregnancyProfile == null) return 0;

    final dueDateStr = pregnancyProfile['due_date']?.toString();
    if (dueDateStr != null && dueDateStr.isNotEmpty) {
      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate != null) {
        final pregnancyStart = dueDate.subtract(const Duration(days: 280));
        final week = DateTime.now().difference(pregnancyStart).inDays ~/ 7;
        return week.clamp(1, 42);
      }
    }

    final storedWeek = pregnancyProfile['current_week'] ??
        pregnancyProfile['pregnancy_week'];
    if (storedWeek is num) return storedWeek.toInt().clamp(1, 42);
    if (storedWeek != null) {
      final parsed = int.tryParse(storedWeek.toString());
      if (parsed != null) return parsed.clamp(1, 42);
    }

    return 0;
  }

  Future<bool> _openWebsite(dynamic rawUrl) async {
    final value = rawUrl?.toString().trim();
    if (value == null || value.isEmpty) return false;

    final fixedUrl = value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';
    final uri = Uri.tryParse(fixedUrl);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open website: $e');
      return false;
    }
  }

  bool _isPremiumProfile(Map<String, dynamic>? profile) {
    final plan = profile?['subscription_plan']?.toString().toLowerCase();
    final role = profile?['role']?.toString().toLowerCase();

    return plan == 'premium' ||
        plan == 'premium_user' ||
        role == 'premium_user' ||
        role == 'admin';
  }

  String _notificationReadReceiptKey(String sourceTable, String sourceId) {
    return '$sourceTable::$sourceId';
  }

  Future<Set<String>> _loadNotificationReadReceiptKeys(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('notification_read_receipts')
          .select('source_table,source_id')
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(data).map((item) {
        return _notificationReadReceiptKey(
          item['source_table']?.toString() ?? '',
          item['source_id']?.toString() ?? '',
        );
      }).where((key) => !key.endsWith('::')).toSet();
    } catch (e) {
      debugPrint('Failed to load notification read receipts: $e');
      return <String>{};
    }
  }

  Future<bool> _saveNotificationReadReceipt(
    Map<String, dynamic> item,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    final sourceId = item['id']?.toString();
    final sourceTable = item['source_table']?.toString() ?? 'notifications';

    if (userId == null || sourceId == null || sourceId.isEmpty) return false;

    try {
      await SupabaseService.client.from('notification_read_receipts').upsert(
        {
          'user_id': userId,
          'source_table': sourceTable,
          'source_id': sourceId,
          'read_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,source_table,source_id',
      );
      return true;
    } catch (e) {
      debugPrint('Failed to save notification read receipt: $e');
      return false;
    }
  }

  Future<bool> _saveNotificationReadReceipts(
    List<Map<String, dynamic>> items,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null || items.isEmpty) return false;

    final now = DateTime.now().toIso8601String();
    final rows = items
        .map((item) {
          final sourceId = item['id']?.toString();
          final sourceTable = item['source_table']?.toString() ?? 'notifications';

          if (sourceId == null || sourceId.isEmpty) return null;

          return {
            'user_id': userId,
            'source_table': sourceTable,
            'source_id': sourceId,
            'read_at': now,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (rows.isEmpty) return false;

    try {
      await SupabaseService.client.from('notification_read_receipts').upsert(
            rows,
            onConflict: 'user_id,source_table,source_id',
          );
      return true;
    } catch (e) {
      debugPrint('Failed to save notification read receipts: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _safeProfile() async {
    try {
      return await SupabaseService.getProfile();
    } catch (e) {
      debugPrint('Failed to load profile for notifications: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromNotificationsTable(
      String userId) async {
    final data = await SupabaseService.client
        .from('notifications')
        .select('id,user_id,title,message,type,is_read,created_at')
        .or('user_id.eq.$userId,user_id.is.null')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data).map((item) {
      return {
        ...item,
        'source_table': 'notifications',
        'type': _normaliseType(item['type']),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromActiveAlertsTable(
      String userId) async {
    final data = await SupabaseService.client
        .from('active_alerts')
        .select('id,user_id,alert_type,title,message,icon_name,created_at')
        .or('user_id.eq.$userId,user_id.is.null')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data).map((item) {
      return {
        'id': item['id'],
        'user_id': item['user_id'],
        'title': item['title'],
        'message': item['message'],
        'type': _normaliseType(item['alert_type']),
        'is_read': false,
        'created_at': item['created_at'],
        'source_table': 'active_alerts',
        'icon_name': item['icon_name'],
      };
    }).toList();
  }


  String _titleCase(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return clean;
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  String _formatConsultationDate(Map<String, dynamic> item) {
    final scheduledAt = item['scheduled_at']?.toString();
    if (scheduledAt != null && scheduledAt.isNotEmpty) {
      final parsed = DateTime.tryParse(scheduledAt);
      if (parsed != null) {
        return DateFormat('d MMM yyyy, h:mm a').format(parsed.toLocal());
      }
    }

    final date = item['scheduled_date']?.toString().trim() ?? '';
    final time = item['scheduled_time']?.toString().trim() ?? '';

    if (date.isNotEmpty && time.isNotEmpty) return '$date, $time';
    if (date.isNotEmpty) return date;
    if (time.isNotEmpty) return time;
    return 'Time not confirmed yet';
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromConsultationsTable(
      String userId) async {
    final data = await SupabaseService.client
        .from('consultations')
        .select(
            'id,patient_id,specialist_id,status,consultation_type,scheduled_at,scheduled_date,scheduled_time,purpose,platform,meeting_link,notes,created_at')
        .eq('patient_id', userId)
        .order('created_at', ascending: false)
        .limit(12);

    return List<Map<String, dynamic>>.from(data).map((item) {
      final status = (item['status'] ?? 'booked').toString();
      final consultationType =
          (item['consultation_type'] ?? 'consultation').toString();
      final purpose = (item['purpose'] ?? '').toString().trim();
      final scheduled = _formatConsultationDate(item);

      return {
        'id': 'consultation-${item['id']}',
        'consultation_id': item['id'],
        'user_id': item['patient_id'],
        'title': '${_titleCase(status)} ${_titleCase(consultationType)}',
        'message': purpose.isEmpty
            ? 'Your consultation is scheduled for $scheduled.'
            : '$purpose • $scheduled',
        'type': 'consultation',
        'is_read': true,
        'created_at': item['created_at'] ?? item['scheduled_at'],
        'source_table': 'consultations',
        'status': status,
        'consultation_type': consultationType,
        'scheduled_display': scheduled,
        'scheduled_at': item['scheduled_at'],
        'scheduled_date': item['scheduled_date'],
        'scheduled_time': item['scheduled_time'],
        'purpose': item['purpose'],
        'platform': item['platform'],
        'meeting_link': item['meeting_link'],
        'notes': item['notes'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromAiRecommendationsTable(
      Map<String, dynamic>? profile) async {
    final isPremiumUser = _isPremiumProfile(profile);

    final data = await SupabaseService.client
        .from('ai_recommendations')
        .select(
            'id,trigger_type,trigger_value,recommendation,source_name,source_url,priority,premium_only,created_at')
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(data).where((item) {
      final premiumOnly = item['premium_only'] == true;
      return isPremiumUser || !premiumOnly;
    }).map((item) {
      final triggerType = (item['trigger_type'] ?? '').toString();
      final triggerValue = (item['trigger_value'] ?? '').toString();
      final title = triggerType.isEmpty
          ? 'AI Recommendation'
          : 'AI Recommendation • ${triggerType.replaceAll('_', ' ')}';

      return {
        'id': item['id'],
        'user_id': null,
        'title': title,
        'message': item['recommendation'],
        'type': 'ai',
        'is_read': true,
        'created_at': item['created_at'],
        'source_table': 'ai_recommendations',
        'priority': item['priority'],
        'source_url': item['source_url'],
        'trigger_type': triggerType,
        'trigger_value': triggerValue,
      };
    }).toList();
  }



  Future<Map<String, dynamic>?> _safePregnancyProfile() async {
    try {
      return await SupabaseService.getPregnancyProfile();
    } catch (e) {
      debugPrint('Failed to load pregnancy profile for notifications: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromArticlesTable(
      Map<String, dynamic>? profile) async {
    final isPremiumUser = _isPremiumProfile(profile);

    final data = await SupabaseService.client
        .from('articles')
        .select(
            'id,title,excerpt,content,category,url,is_premium_only,status,created_at,published_at')
        .order('created_at', ascending: false)
        .limit(12);

    return List<Map<String, dynamic>>.from(data).where((item) {
      final premiumOnly = item['is_premium_only'] == true;
      return isPremiumUser || !premiumOnly;
    }).map((item) {
      final excerpt = (item['excerpt'] ?? '').toString().trim();
      final content = (item['content'] ?? '').toString().trim();
      final message = excerpt.isNotEmpty
          ? excerpt
          : content.length > 140
              ? '${content.substring(0, 140)}...'
              : content;

      return {
        'id': item['id'],
        'user_id': null,
        'title': item['title'] ?? 'Education Resource',
        'message': message.isEmpty ? 'Tap to view this education resource.' : message,
        'full_content': content,
        'type': 'education',
        'is_read': true,
        'created_at': item['published_at'] ?? item['created_at'],
        'source_table': 'articles',
        'source_url': item['url'],
        'category': item['category'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _fallbackMilestoneRows(
      Map<String, dynamic>? pregnancyProfile) {
    final week = _currentPregnancyWeek(pregnancyProfile);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (week <= 0) {
      return [
        {
          'id': 'milestone-set-due-date-$today',
          'user_id': SupabaseService.currentUser?.id,
          'title': 'Set your due date',
          'message':
              'Add your due date or pregnancy week in your profile to see weekly baby milestones.',
          'type': 'milestone',
          'is_read': true,
          'created_at': DateTime.now().toIso8601String(),
          'source_table': 'generated_milestone',
          'full_content':
              'To show weekly milestones, TinyBloom needs your due date or current pregnancy week. Update your pregnancy profile so the app can calculate the correct week and show the right baby development information.',
        }
      ];
    }

    final local = pregnancyWeekData[week];
    final size = local?['size']?.toString() ?? 'growing beautifully';
    final emoji = local?['emoji']?.toString() ?? '🌸';
    final weight = local?['weight']?.toString();

    return [
      {
        'id': 'milestone-week-$week-$today',
        'user_id': SupabaseService.currentUser?.id,
        'title': 'Week $week Pregnancy Milestone',
        'message': weight == null || weight.isEmpty
            ? 'Your baby is about the size of $size $emoji this week.'
            : 'Your baby is about the size of $size $emoji and weighs around $weight this week.',
        'type': 'milestone',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
        'source_table': 'generated_milestone',
        'week': week,
        'baby_size': size,
        'emoji': emoji,
        'weight': weight,
        'full_content': weight == null || weight.isEmpty
            ? 'Week $week milestone: your baby is about the size of $size $emoji this week. Continue logging symptoms and notes so you can track changes clearly.'
            : 'Week $week milestone: your baby is about the size of $size $emoji and weighs around $weight this week. Continue logging symptoms and notes so you can track changes clearly.',
      }
    ];
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromBabyDevelopmentTable(
      Map<String, dynamic>? pregnancyProfile) async {
    final week = _currentPregnancyWeek(pregnancyProfile);
    if (week <= 0) return _fallbackMilestoneRows(pregnancyProfile);

    final data = await SupabaseService.client
        .from('baby_development')
        .select(
            'week,baby_size,emoji,development_title,development_description,length_cm,weight_g,trimester')
        .eq('week', week)
        .maybeSingle();

    if (data == null) return _fallbackMilestoneRows(pregnancyProfile);

    final item = Map<String, dynamic>.from(data);
    final title = (item['development_title'] ?? '').toString().trim();
    final size = (item['baby_size'] ?? '').toString().trim();
    final emoji = (item['emoji'] ?? '🌸').toString().trim();
    final description = (item['development_description'] ?? '').toString().trim();

    return [
      {
        'id': 'baby-development-week-$week',
        'user_id': SupabaseService.currentUser?.id,
        'title': title.isEmpty ? 'Week $week Pregnancy Milestone' : title,
        'message': description.isEmpty
            ? 'Your baby is growing beautifully this week. ${size.isEmpty ? '' : 'Size: $size $emoji'}'
            : description,
        'type': 'milestone',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
        'source_table': 'baby_development',
        'week': item['week'],
        'baby_size': size,
        'emoji': emoji,
        'length_cm': item['length_cm'],
        'weight_g': item['weight_g'],
        'trimester': item['trimester'],
        'full_content': description.isEmpty
            ? 'Your baby is growing beautifully this week. ${size.isEmpty ? '' : 'Size: $size $emoji'}'
            : description,
      }
    ];
  }

  List<Map<String, dynamic>> _fallbackEmergencyRows() {
    final now = DateTime.now().toIso8601String();
    return [
      {
        'id': 'emergency-support-fallback',
        'user_id': SupabaseService.currentUser?.id,
        'title': 'Emergency Support',
        'message':
            'If you have severe pain, heavy bleeding, breathing difficulty, fainting, or reduced baby movement, seek urgent medical help immediately.',
        'type': 'emergency',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_emergency',
        'full_content':
            'Seek urgent medical help immediately for severe pain, heavy bleeding, breathing difficulty, fainting, severe headache, chest pain, seizures, fever with worsening symptoms, or reduced baby movement. This app is not a replacement for emergency care.',
      },
      {
        'id': 'emergency-call-fallback',
        'user_id': SupabaseService.currentUser?.id,
        'title': 'When to get help',
        'message':
            'For immediate danger, call local emergency services. For pregnancy concerns, contact your doctor, clinic, or hospital maternity unit.',
        'type': 'emergency',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_emergency',
        'full_content':
            'For immediate danger, call your local emergency number. For urgent pregnancy concerns, contact your doctor, clinic, or hospital maternity unit. Bring your ID, appointment details, medication list, and pregnancy records if you need to go in.',
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromEmergencyRulesTable() async {
    final data = await SupabaseService.client
        .from('emergency_rules')
        .select('id,condition,severity,action')
        .limit(10);

    final rows = List<Map<String, dynamic>>.from(data).map((item) {
      final condition = (item['condition'] ?? 'Emergency Guidance').toString();
      final severity = (item['severity'] ?? '').toString();
      final action = (item['action'] ?? '').toString();

      return {
        'id': item['id'],
        'user_id': null,
        'title': severity.isEmpty ? condition : '$severity: $condition',
        'message': action.isEmpty ? 'Tap to view emergency support guidance.' : action,
        'type': 'emergency',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
        'source_table': 'emergency_rules',
        'condition': condition,
        'severity': severity,
        'action': action,
        'full_content': action.isEmpty
            ? 'Review this emergency guidance carefully and contact a healthcare professional if symptoms are serious or worsening.'
            : action,
      };
    }).toList();

    return rows.isEmpty ? _fallbackEmergencyRows() : rows;
  }



  List<String> _stringListFromArray(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return [];

    return text
        .replaceAll('{', '')
        .replaceAll('}', '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int? _intFromValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _healthLogCreatedAt(Map<String, dynamic> item) {
    return (item['logged_at'] ?? item['created_at'] ?? DateTime.now().toIso8601String())
        .toString();
  }

  String _cleanHealthText(List<String> symptoms, String notes) {
    final parts = <String>[];
    if (symptoms.isNotEmpty) parts.add(symptoms.join(', '));
    if (notes.trim().isNotEmpty) parts.add(notes.trim());
    return parts.join(' ').toLowerCase();
  }

  List<String> _dangerSymptomMatches(String combinedText) {
    final checks = <String, String>{
      'heavy bleeding': 'Heavy bleeding reported',
      'bleeding': 'Bleeding reported',
      'severe headache': 'Severe headache reported',
      'blurred vision': 'Blurred vision reported',
      'vision changes': 'Vision changes reported',
      'chest pain': 'Chest pain reported',
      'shortness of breath': 'Shortness of breath reported',
      'breathless': 'Breathlessness reported',
      'severe abdominal pain': 'Severe abdominal pain reported',
      'fainting': 'Fainting reported',
      'seizure': 'Seizure reported',
      'fever': 'Fever reported',
      'reduced movement': 'Reduced baby movement reported',
      'less movement': 'Reduced baby movement reported',
      'no movement': 'No baby movement reported',
      'swelling': 'Sudden swelling reported',
      'contractions': 'Contractions reported',
      'water broke': 'Possible water breaking reported',
      'fluid leakage': 'Fluid leakage reported',
    };

    final matches = <String>[];
    for (final entry in checks.entries) {
      if (combinedText.contains(entry.key) && !matches.contains(entry.value)) {
        matches.add(entry.value);
      }
    }
    return matches;
  }

  List<Map<String, dynamic>> _emergencyRowsFromHealthLog(
      Map<String, dynamic> item) {
    final systolic = _intFromValue(item['blood_pressure_systolic']);
    final diastolic = _intFromValue(item['blood_pressure_diastolic']);
    final kickCount = _intFromValue(item['kick_count']);
    final symptoms = _stringListFromArray(item['symptoms']);
    final notes = (item['notes'] ?? '').toString();
    final createdAt = _healthLogCreatedAt(item);
    final issues = <String>[];
    var severity = 'Monitor';
    var title = 'Health Log Alert';

    if (systolic != null && diastolic != null) {
      if (systolic >= 160 || diastolic >= 110) {
        title = 'Critical Blood Pressure Alert';
        severity = 'Critical';
        issues.add('Blood pressure is very high: $systolic/$diastolic mmHg');
      } else if (systolic >= 140 || diastolic >= 90) {
        title = 'High Blood Pressure Alert';
        severity = 'Urgent';
        issues.add('Blood pressure is high: $systolic/$diastolic mmHg');
      } else if (systolic < 90 || diastolic < 60) {
        title = 'Low Blood Pressure Alert';
        severity = 'Monitor';
        issues.add('Blood pressure is low: $systolic/$diastolic mmHg');
      }
    }

    if (kickCount != null && kickCount <= 0) {
      severity = severity == 'Critical' ? severity : 'Urgent';
      title = 'Baby Movement Alert';
      issues.add('Baby movement count was logged as $kickCount');
    }

    final symptomMatches = _dangerSymptomMatches(
      _cleanHealthText(symptoms, notes),
    );
    if (symptomMatches.isNotEmpty) {
      if (severity != 'Critical') severity = 'Urgent';
      title = title == 'Health Log Alert' ? 'Symptom Alert' : title;
      issues.addAll(symptomMatches);
    }

    if (issues.isEmpty) return [];

    final bpText = systolic != null && diastolic != null
        ? 'Blood pressure: $systolic/$diastolic mmHg\n'
        : '';
    final symptomsText = symptoms.isNotEmpty
        ? 'Symptoms logged: ${symptoms.join(', ')}\n'
        : '';
    final notesText = notes.trim().isNotEmpty ? 'Notes: ${notes.trim()}\n' : '';

    final fullContent = '${issues.map((issue) => '• $issue').join('\n')}\n\n'
        '${bpText}${symptomsText}${notesText}'
        'This alert was generated from your latest health log. If symptoms are severe, worsening, or you feel unsafe, contact your doctor, clinic, maternity unit, or local emergency services immediately.';

    return [
      {
        'id': 'health-log-emergency-${item['id']}',
        'user_id': item['user_id'] ?? SupabaseService.currentUser?.id,
        'title': title,
        'message': issues.first,
        'type': 'emergency',
        'is_read': false,
        'created_at': createdAt,
        'source_table': 'health_logs',
        'severity': severity,
        'condition': 'Abnormal health log detected',
        'full_content': fullContent,
        'blood_pressure_systolic': systolic,
        'blood_pressure_diastolic': diastolic,
        'symptoms': symptoms,
        'notes': notes,
        'kick_count': kickCount,
      }
    ];
  }

  List<Map<String, dynamic>> _emergencyRowsFromPregnancyLog(
      Map<String, dynamic> item) {
    final symptoms = _stringListFromArray(item['symptoms']);
    final notes = (item['notes'] ?? '').toString();
    final matches = _dangerSymptomMatches(_cleanHealthText(symptoms, notes));
    if (matches.isEmpty) return [];

    return [
      {
        'id': 'pregnancy-log-emergency-${item['id']}',
        'user_id': item['user_id'] ?? SupabaseService.currentUser?.id,
        'title': 'Pregnancy Log Alert',
        'message': matches.first,
        'type': 'emergency',
        'is_read': false,
        'created_at': (item['created_at'] ?? item['log_date'] ?? DateTime.now().toIso8601String()).toString(),
        'source_table': 'pregnancy_logs',
        'severity': 'Urgent',
        'condition': 'Abnormal pregnancy log detected',
        'full_content': '${matches.map((issue) => '• $issue').join('\n')}\n\n'
            '${symptoms.isNotEmpty ? 'Symptoms logged: ${symptoms.join(', ')}\n' : ''}'
            '${notes.trim().isNotEmpty ? 'Notes: ${notes.trim()}\n' : ''}'
            'This alert was generated from your pregnancy log. If symptoms are severe, worsening, or you feel unsafe, seek medical advice immediately.',
        'symptoms': symptoms,
        'notes': notes,
      }
    ];
  }

  Future<List<Map<String, dynamic>>> _loadRowsFromHealthLogEmergencyAlerts(
      String userId) async {
    final alerts = <Map<String, dynamic>>[];

    final healthLogs = await SupabaseService.client
        .from('health_logs')
        .select(
            'id,user_id,blood_pressure_systolic,blood_pressure_diastolic,symptoms,notes,kick_count,logged_at,created_at')
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .limit(10);

    for (final item in List<Map<String, dynamic>>.from(healthLogs)) {
      alerts.addAll(_emergencyRowsFromHealthLog(item));
    }

    try {
      final pregnancyLogs = await SupabaseService.client
          .from('pregnancy_logs')
          .select('id,user_id,mood,symptoms,milestones,notes,log_date,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      for (final item in List<Map<String, dynamic>>.from(pregnancyLogs)) {
        alerts.addAll(_emergencyRowsFromPregnancyLog(item));
      }
    } catch (e) {
      debugPrint('Failed to scan pregnancy_logs for emergency alerts: $e');
    }

    return alerts;
  }

  List<Map<String, dynamic>> _generalReminderRows() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now().toIso8601String();
    final userId = SupabaseService.currentUser?.id;

    return [
      {
        'id': 'daily-health-reminder-$today',
        'user_id': userId,
        'title': 'Daily Health Reminder',
        'message': 'Log your mood, symptoms and pregnancy notes today.',
        'type': 'reminder',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_reminder',
        'full_content':
            'Daily check-in: record your mood, symptoms, medication, discomfort, questions for your doctor, and any changes you noticed today. This makes it easier to explain your condition during appointments.',
      },
      {
        'id': 'hydration-reminder-$today',
        'user_id': userId,
        'title': 'Hydration Reminder',
        'message': 'Drink water regularly and watch for signs of dehydration.',
        'type': 'reminder',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_reminder',
        'full_content':
            'General reminder: keep water nearby, drink regularly throughout the day, and take note if you feel dizzy, very thirsty, or unusually tired. Contact a healthcare professional if symptoms are severe or persistent.',
      },
      {
        'id': 'movement-reminder-$today',
        'user_id': userId,
        'title': 'Baby Movement Reminder',
        'message': 'Pay attention to your baby’s usual movement pattern.',
        'type': 'reminder',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_reminder',
        'full_content':
            'General reminder: notice your baby’s normal movement pattern. If movements are reduced, absent, or feel very different from usual, contact your doctor, clinic, or maternity unit for advice.',
      },
      {
        'id': 'appointment-reminder-$today',
        'user_id': userId,
        'title': 'Appointment Preparation',
        'message': 'Prepare questions and notes for your next consultation.',
        'type': 'reminder',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_reminder',
        'full_content':
            'Before your next consultation, prepare your symptoms, questions, medication list, pregnancy records, and any concerns you want to discuss. This helps you make better use of the appointment time.',
      },
    ];
  }

  Future<void> _loadNotifications() async {
    final userId = SupabaseService.currentUser?.id;

    final profile = await _safeProfile();
    final pregnancyProfile = await _safePregnancyProfile();
    final merged = <Map<String, dynamic>>[];

    if (userId != null) {
      try {
        merged.addAll(await _loadRowsFromNotificationsTable(userId));
      } catch (e) {
        debugPrint('Failed to load rows from notifications table: $e');
      }

      try {
        merged.addAll(await _loadRowsFromActiveAlertsTable(userId));
      } catch (e) {
        // This table is optional for the notification centre. If RLS blocks it,
        // normal notifications should still work instead of showing a blank page.
        debugPrint('Failed to load rows from active_alerts table: $e');
      }

      try {
        merged.addAll(await _loadRowsFromHealthLogEmergencyAlerts(userId));
      } catch (e) {
        debugPrint('Failed to scan health logs for emergency alerts: $e');
      }
    }

    if (userId != null) {
      try {
        merged.addAll(await _loadRowsFromConsultationsTable(userId));
      } catch (e) {
        debugPrint('Failed to load rows from consultations table: $e');
      }
    }

    try {
      merged.addAll(await _loadRowsFromAiRecommendationsTable(profile));
    } catch (e) {
      // AI recommendations are optional. If the table has RLS/policy issues,
      // the Notifications Centre should still show normal alerts.
      debugPrint('Failed to load rows from ai_recommendations table: $e');
    }

    try {
      merged.addAll(await _loadRowsFromArticlesTable(profile));
    } catch (e) {
      debugPrint('Failed to load rows from articles table: $e');
    }

    try {
      merged.addAll(await _loadRowsFromBabyDevelopmentTable(pregnancyProfile));
    } catch (e) {
      debugPrint('Failed to load rows from baby_development table: $e');
      merged.addAll(_fallbackMilestoneRows(pregnancyProfile));
    }

    try {
      merged.addAll(await _loadRowsFromEmergencyRulesTable());
    } catch (e) {
      debugPrint('Failed to load rows from emergency_rules table: $e');
      merged.addAll(_fallbackEmergencyRows());
    }

    merged.addAll(_generalReminderRows());

    final readReceiptKeys = userId == null
        ? <String>{}
        : await _loadNotificationReadReceiptKeys(userId);

    final mergedWithReadState = merged.map((item) {
      final sourceTable = item['source_table']?.toString() ?? 'notifications';
      final sourceId = item['id']?.toString();

      // Apply read receipts to EVERY source, including the notifications
      // table. This fixes global notifications where user_id is NULL, because
      // those rows cannot be updated with is_read=true for one user only.
      if (sourceId != null &&
          readReceiptKeys.contains(
            _notificationReadReceiptKey(sourceTable, sourceId),
          )) {
        return {...item, 'is_read': true};
      }

      return item;
    }).toList();

    mergedWithReadState.sort((a, b) {
      final aRead = a['is_read'] == true ? 1 : 0;
      final bRead = b['is_read'] == true ? 1 : 0;
      final unreadCompare = aRead.compareTo(bRead);
      if (unreadCompare != 0) return unreadCompare;
      return _createdAt(b).compareTo(_createdAt(a));
    });

    if (!mounted) return;
    setState(() {
      _notifications = mergedWithReadState;
      _loading = false;
    });
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    final userId = SupabaseService.currentUser?.id;
    final sourceTable = item['source_table']?.toString() ?? 'notifications';

    if (id == null) return;

    setState(() {
      _notifications = _notifications.map((n) {
        if (n['id']?.toString() == id &&
            (n['source_table']?.toString() ?? 'notifications') == sourceTable) {
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();
    });

    // Always save a read receipt, even for rows from the notifications table.
    // This is important for global notifications where user_id is NULL; those
    // rows cannot safely be updated to is_read=true for one user only.
    await _saveNotificationReadReceipt(item);

    if (sourceTable == 'notifications') {
      try {
        final itemUserId = item['user_id']?.toString();

        // Only update the database notification row when it belongs to this
        // exact user. Global notifications are cleared by the read receipt.
        if (userId != null && itemUserId == userId) {
          await SupabaseService.client
              .from('notifications')
              .update({'is_read': true})
              .eq('id', id)
              .eq('user_id', userId);
        }
      } catch (e) {
        debugPrint('Failed to mark notification as read: $e');
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Save receipts for every unread item, including notifications-table rows.
    // This clears active alerts, generated alerts, AI/education cards, and
    // global notifications that have user_id = NULL.
    final itemsToReceipt = _notifications.where((n) {
      return n['id'] != null && n['is_read'] != true;
    }).toList();

    setState(() {
      _notifications = _notifications.map((n) {
        return {...n, 'is_read': true};
      }).toList();
    });

    try {
      // Only user-owned notification rows are updated. Global notification rows
      // are cleared per user through notification_read_receipts above.
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
    }

    final receiptsSaved = await _saveNotificationReadReceipts(itemsToReceipt);

    if (!mounted) return;

    if (itemsToReceipt.isNotEmpty && !receiptsSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marked normal notifications as read, but read receipts did not save. Check the notification_read_receipts table and RLS policies.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read.')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;

    final selectedType = _normaliseType(_selectedFilter);

    return _notifications.where((n) {
      return _normaliseType(n['type']) == selectedType;
    }).toList();
  }

  int get _urgentCount {
    return _notifications.where((n) {
      return _normaliseType(n['type']) == 'emergency' && n['is_read'] != true;
    }).length;
  }

  Future<void> _showRecommendationDetails(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'AI Recommendation').toString();
    final message = (item['message'] ?? '').toString().trim();
    final triggerType = (item['trigger_type'] ?? '').toString().trim();
    final triggerValue = (item['trigger_value'] ?? '').toString().trim();
    final priority = (item['priority'] ?? '').toString().trim();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.smart_toy_outlined,
                          color: Colors.purpleAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Assistant Advice',
                              style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message.isEmpty
                        ? 'No recommendation details available.'
                        : message,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  if (triggerType.isNotEmpty || triggerValue.isNotEmpty || priority.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.blush.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (triggerType.isNotEmpty)
                            Text(
                              'Based on: ${triggerType.replaceAll('_', ' ')}',
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (triggerValue.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Value: $triggerValue',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (priority.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Priority: $priority',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEducationDetails(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'Education Resource').toString();
    final message = (item['message'] ?? '').toString().trim();
    final fullContent = (item['full_content'] ?? '').toString().trim();
    final category = (item['category'] ?? '').toString().trim();
    final sourceUrl = (item['source_url'] ?? '').toString().trim();
    final body = fullContent.isNotEmpty ? fullContent : message;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Education Resource',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.blush.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.textMid,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    body.isEmpty ? 'No education details available.' : body,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (sourceUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          side: const BorderSide(color: AppColors.teal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => _openWebsite(sourceUrl),
                        icon: const Icon(Icons.open_in_new, size: 17),
                        label: const Text('Open source website'),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _showInfoSheet({
    required String label,
    required String title,
    required String body,
    required IconData icon,
    required Color color,
    List<Widget> extraChildren = const [],
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    body.isEmpty ? 'No details available.' : body,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  if (extraChildren.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    ...extraChildren,
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEmergencyDetails(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'Emergency Information').toString();
    final body = ((item['full_content'] ?? item['message']) ?? '').toString();
    final severity = (item['severity'] ?? '').toString().trim();
    final condition = (item['condition'] ?? '').toString().trim();

    await _showInfoSheet(
      label: 'Emergency Information',
      title: title,
      body: body,
      icon: Icons.warning_amber_rounded,
      color: Colors.redAccent,
      extraChildren: [
        if (severity.isNotEmpty || condition.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (severity.isNotEmpty)
                  Text('Severity: $severity',
                      style: const TextStyle(
                          color: AppColors.textMid,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                if (condition.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Condition: $condition',
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showMilestoneDetails(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'Pregnancy Milestone').toString();
    final body = ((item['full_content'] ?? item['message']) ?? '').toString();
    final week = item['week']?.toString();
    final size = item['baby_size']?.toString();
    final weight = item['weight_g']?.toString() ?? item['weight']?.toString();
    final length = item['length_cm']?.toString();
    final trimester = item['trimester']?.toString();

    await _showInfoSheet(
      label: 'Milestone Details',
      title: title,
      body: body,
      icon: Icons.auto_awesome,
      color: AppColors.rose,
      extraChildren: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blush.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (week != null && week.isNotEmpty)
                Text('Week: $week',
                    style: const TextStyle(
                        color: AppColors.textMid,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              if (trimester != null && trimester.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Trimester: $trimester',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
              if (size != null && size.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Baby size: $size',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
              if (length != null && length.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Length: $length cm',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
              if (weight != null && weight.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text("Weight: $weight${item['weight_g'] != null ? ' g' : ''}",
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showReminderDetails(Map<String, dynamic> item) async {
    await _showInfoSheet(
      label: 'Reminder Details',
      title: (item['title'] ?? 'Daily Reminder').toString(),
      body: ((item['full_content'] ?? item['message']) ?? '').toString(),
      icon: Icons.water_drop_outlined,
      color: AppColors.roseDeep,
    );
  }

  Future<void> _showConsultationDetails(Map<String, dynamic> item) async {
    final consultationId = item['consultation_id']?.toString();
    final title = (item['title'] ?? 'Consultation Booking').toString();
    final scheduled = (item['scheduled_display'] ?? '').toString().trim();
    final purpose = (item['purpose'] ?? '').toString().trim();
    final status = (item['status'] ?? '').toString().trim();
    final platform = (item['platform'] ?? '').toString().trim();
    final meetingLink = (item['meeting_link'] ?? '').toString().trim();
    final notes = (item['notes'] ?? '').toString().trim();

    final body = [
      if (scheduled.isNotEmpty) 'Scheduled: $scheduled',
      if (purpose.isNotEmpty) 'Purpose: $purpose',
      if (status.isNotEmpty) 'Status: ${_titleCase(status)}',
      if (platform.isNotEmpty) 'Platform: $platform',
      if (notes.isNotEmpty) 'Notes: $notes',
      if (consultationId == null)
        (item['message'] ?? 'Open your consultation page to view this booking.')
            .toString(),
    ].join('\n\n');

    await _showInfoSheet(
      label: 'Consultation Booking',
      title: title,
      body: body,
      icon: Icons.calendar_month_outlined,
      color: AppColors.sage,
      extraChildren: [
        if (meetingLink.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sage,
                side: const BorderSide(color: AppColors.sage),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () => _openWebsite(meetingLink),
              icon: const Icon(Icons.video_call_outlined, size: 17),
              label: const Text('Open meeting link'),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/consultation');
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 17),
            label: const Text('Open consultations page'),
          ),
        ),
      ],
    );
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    await _markAsRead(item);

    final type = _normaliseType(item['type']);

    if (!mounted) return;

    switch (type) {
      case 'emergency':
        await _showEmergencyDetails(item);
        break;

      case 'milestone':
        await _showMilestoneDetails(item);
        break;

      case 'consultation':
        await _showConsultationDetails(item);
        break;

      case 'education':
        await _showEducationDetails(item);
        break;

      case 'reminder':
        await _showReminderDetails(item);
        break;

      case 'ai':
        await _showRecommendationDetails(item);
        break;

      default:
        context.push('/notifications');
        break;
    }
  }

  IconData _iconForType(String type) {
    switch (_normaliseType(type)) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'milestone':
        return Icons.auto_awesome;
      case 'consultation':
        return Icons.calendar_month_outlined;
      case 'education':
        return Icons.menu_book_outlined;
      case 'reminder':
        return Icons.water_drop_outlined;
      case 'ai':
        return Icons.smart_toy_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (_normaliseType(type)) {
      case 'emergency':
        return Colors.redAccent;
      case 'milestone':
        return AppColors.rose;
      case 'consultation':
        return AppColors.sage;
      case 'education':
        return AppColors.teal;
      case 'reminder':
        return AppColors.roseDeep;
      case 'ai':
        return Colors.purpleAccent;
      default:
        return AppColors.textMid;
    }
  }

  String _sectionTitle(String type) {
    switch (_normaliseType(type)) {
      case 'emergency':
        return 'Emergency Alert';
      case 'milestone':
        return 'Pregnancy Milestone';
      case 'consultation':
        return 'Consultation Update';
      case 'education':
        return 'Education Recommendation';
      case 'reminder':
        return 'Daily Reminder';
      case 'ai':
        return 'AI Assistant Advice';
      default:
        return 'Notification';
    }
  }

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';

    final date = DateTime.tryParse(createdAt.toString());
    if (date == null) return '';

    final diff = DateTime.now().difference(date.toLocal());

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return DateFormat('d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['is_read'] != true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.rose),
              )
            : RefreshIndicator(
                color: AppColors.rose,
                onRefresh: _loadNotifications,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/dashboard');
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Spacer(),
                        if (_urgentCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_urgentCount Urgent',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Notifications Centre',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unreadCount == 0
                          ? 'You are all caught up 🌸'
                          : '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_notifications.any((n) => n['is_read'] != true))
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _markAllAsRead,
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text('Mark all as read'),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _buildFilters(),
                    const SizedBox(height: 20),
                    if (_filteredNotifications.isEmpty)
                      _emptyState()
                    else
                      ..._filteredNotifications.map(_notificationCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == _selectedFilter;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.rose : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.rose
                      : AppColors.textLight.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 42,
            color: AppColors.textLight,
          ),
          SizedBox(height: 10),
          Text(
            'No notifications here',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Alerts, consultations, milestones, reminders and AI recommendations will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final type = _normaliseType(item['type']);
    final color = _colorForType(type);
    final icon = _iconForType(type);
    final isRead = item['is_read'] == true;
    final isEmergency = type == 'emergency';
    final sourceTable = item['source_table']?.toString() ?? 'notifications';
    final isActiveAlert = sourceTable == 'active_alerts';
    final isAiRecommendation = sourceTable == 'ai_recommendations';

    return GestureDetector(
      onTap: () => _openNotification(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRead
                ? AppColors.textLight.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.38),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sectionTitle(type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isEmergency || isActiveAlert || isAiRecommendation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isEmergency
                                ? 'Urgent'
                                : isAiRecommendation
                                    ? 'AI'
                                    : 'Active',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (item['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (item['message'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _timeAgo(item['created_at']),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (!isRead)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(height: 18),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textLight,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
