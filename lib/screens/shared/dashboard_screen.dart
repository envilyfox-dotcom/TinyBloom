import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _pregnancyProfile;
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _myQuestions = [];
  Map<String, String> _providerNames = {};
  bool _loading = true;
  DateTime? _lastNavTime;

  bool _canNav() {
    final now = DateTime.now();
    if (_lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) {
      return false;
    }
    _lastNavTime = now;
    return true;
  }


  String _normaliseNotificationType(dynamic rawType) {
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

  DateTime _notificationCreatedAt(Map<String, dynamic> item) {
    return DateTime.tryParse(item['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
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
      debugPrint('Failed to load dashboard read receipts: $e');
      return <String>{};
    }
  }

  Future<void> _saveNotificationReadReceipt(
    Map<String, dynamic> item,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    final sourceId = item['id']?.toString();
    final sourceTable = item['source_table']?.toString() ?? 'notifications';

    if (userId == null || sourceId == null || sourceId.isEmpty) return;

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
    } catch (e) {
      debugPrint('Failed to save dashboard read receipt: $e');
    }
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

  int _pregnancyWeekFromProfile(Map<String, dynamic>? pregnancyProfile) {
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

  Map<String, dynamic> _dashboardMilestoneNotification(
      Map<String, dynamic>? pregnancyProfile) {
    final week = _pregnancyWeekFromProfile(pregnancyProfile);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (week <= 0) {
      return {
        'id': 'dashboard-milestone-set-due-date-$today',
        'user_id': SupabaseService.currentUser?.id,
        'title': 'Set your due date',
        'message':
            'Add your due date or pregnancy week to see weekly baby milestones.',
        'type': 'milestone',
        'is_read': true,
        'created_at': DateTime.now().toIso8601String(),
        'source_table': 'generated_milestone',
      };
    }

    final data = pregnancyWeekData[week];
    final size = data?['size']?.toString() ?? 'growing beautifully';
    final emoji = data?['emoji']?.toString() ?? '🌸';
    final weight = data?['weight']?.toString();

    return {
      'id': 'dashboard-milestone-week-$week-$today',
      'user_id': SupabaseService.currentUser?.id,
      'title': 'Week $week Pregnancy Milestone',
      'message': weight == null || weight.isEmpty
          ? 'Your baby is about the size of $size $emoji this week.'
          : 'Your baby is about the size of $size $emoji and weighs around $weight this week.',
      'type': 'milestone',
      'is_read': true,
      'created_at': DateTime.now().toIso8601String(),
      'source_table': 'generated_milestone',
    };
  }

  List<Map<String, dynamic>> _dashboardEmergencyNotifications() {
    final now = DateTime.now().toIso8601String();
    return [
      {
        'id': 'dashboard-emergency-support-fallback',
        'user_id': SupabaseService.currentUser?.id,
        'title': 'Emergency Support',
        'message':
            'If you have severe pain, heavy bleeding, breathing difficulty, fainting, or reduced baby movement, seek urgent medical help immediately.',
        'type': 'emergency',
        'is_read': true,
        'created_at': now,
        'source_table': 'generated_emergency',
      },
    ];
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

  List<Map<String, dynamic>> _dashboardEmergencyRowsFromHealthLog(
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
        'full_content': '${issues.map((issue) => '• $issue').join('\n')}\n\nThis alert was generated from the user health log. If symptoms are severe, worsening, or the user feels unsafe, they should contact a doctor, clinic, maternity unit, or local emergency services immediately.',
      }
    ];
  }

  List<Map<String, dynamic>> _dashboardEmergencyRowsFromPregnancyLog(
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
        'full_content': '${matches.map((issue) => '• $issue').join('\n')}\n\nThis alert was generated from the pregnancy log. If symptoms are severe, worsening, or the user feels unsafe, they should seek medical advice immediately.',
      }
    ];
  }

  Future<List<Map<String, dynamic>>> _loadDashboardHealthLogEmergencyAlerts(
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
      alerts.addAll(_dashboardEmergencyRowsFromHealthLog(item));
    }

    try {
      final pregnancyLogs = await SupabaseService.client
          .from('pregnancy_logs')
          .select('id,user_id,mood,symptoms,milestones,notes,log_date,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      for (final item in List<Map<String, dynamic>>.from(pregnancyLogs)) {
        alerts.addAll(_dashboardEmergencyRowsFromPregnancyLog(item));
      }
    } catch (e) {
      debugPrint('Failed to scan pregnancy_logs for dashboard emergency alerts: $e');
    }

    return alerts;
  }

  String _titleCase(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return clean;
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  String _formatDashboardConsultationDate(Map<String, dynamic> item) {
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

  Future<List<Map<String, dynamic>>> _loadDashboardConsultationNotifications(
      String userId) async {
    final data = await SupabaseService.client
        .from('consultations')
        .select(
            'id,patient_id,specialist_id,status,consultation_type,scheduled_at,scheduled_date,scheduled_time,purpose,platform,meeting_link,notes,created_at')
        .eq('patient_id', userId)
        .order('created_at', ascending: false)
        .limit(8);

    return List<Map<String, dynamic>>.from(data).map((item) {
      final status = (item['status'] ?? 'booked').toString();
      final consultationType =
          (item['consultation_type'] ?? 'consultation').toString();
      final purpose = (item['purpose'] ?? '').toString().trim();
      final scheduled = _formatDashboardConsultationDate(item);

      return {
        'id': 'consultation-${item['id']}',
        'consultation_id': item['id'],
        'user_id': item['patient_id'],
        'title': '${_titleCase(status)} ${_titleCase(consultationType)}',
        'message': purpose.isEmpty
            ? 'Your consultation is scheduled for $scheduled.'
            : '$purpose • $scheduled',
        'type': 'consultation',
        'is_read': false,
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

  Future<List<Map<String, dynamic>>> _loadDashboardNotifications(
      Map<String, dynamic>? profile,
      Map<String, dynamic>? pregnancyProfile) async {
    final userId = SupabaseService.currentUser?.id;

    final isPremiumUser = _isPremiumProfile(profile);

    final merged = <Map<String, dynamic>>[];

    if (userId != null) {
      try {
        final data = await SupabaseService.client
            .from('notifications')
            .select('id,user_id,title,message,type,is_read,created_at')
            .or('user_id.eq.$userId,user_id.is.null')
            .order('created_at', ascending: false)
            .limit(12);

        merged.addAll(List<Map<String, dynamic>>.from(data).map((item) {
          return {
            ...item,
            'source_table': 'notifications',
            'type': _normaliseNotificationType(item['type']),
          };
        }));
      } catch (e) {
        debugPrint('Failed to load dashboard notifications: $e');
      }

      try {
        final data = await SupabaseService.client
            .from('active_alerts')
            .select('id,user_id,alert_type,title,message,icon_name,created_at')
            .or('user_id.eq.$userId,user_id.is.null')
            .order('created_at', ascending: false)
            .limit(12);

        merged.addAll(List<Map<String, dynamic>>.from(data).map((item) {
          return {
            'id': item['id'],
            'user_id': item['user_id'],
            'title': item['title'],
            'message': item['message'],
            'type': _normaliseNotificationType(item['alert_type']),
            'is_read': false,
            'created_at': item['created_at'],
            'source_table': 'active_alerts',
            'icon_name': item['icon_name'],
          };
        }));
      } catch (e) {
        // Active alerts are optional. If this table is blocked by RLS, keep the
        // dashboard usable with normal notifications and generated cards.
        debugPrint('Failed to load dashboard active alerts: $e');
      }

      try {
        merged.addAll(await _loadDashboardHealthLogEmergencyAlerts(userId));
      } catch (e) {
        debugPrint('Failed to scan health logs for dashboard emergency alerts: $e');
      }

      try {
        merged.addAll(await _loadDashboardConsultationNotifications(userId));
      } catch (e) {
        debugPrint('Failed to load dashboard consultation notifications: $e');
      }
    }

    try {
      final data = await SupabaseService.client
          .from('ai_recommendations')
          .select(
              'id,trigger_type,trigger_value,recommendation,source_name,source_url,priority,premium_only,created_at')
          .order('created_at', ascending: false)
          .limit(8);

      merged.addAll(List<Map<String, dynamic>>.from(data).where((item) {
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
      }));
    } catch (e) {
      debugPrint('Failed to load dashboard AI recommendations: $e');
    }



    try {
      final articleData = await SupabaseService.client
          .from('articles')
          .select('id,title,excerpt,content,url,is_premium_only,created_at,published_at')
          .order('created_at', ascending: false)
          .limit(4);

      merged.addAll(List<Map<String, dynamic>>.from(articleData).where((item) {
        final premiumOnly = item['is_premium_only'] == true;
        return isPremiumUser || !premiumOnly;
      }).map((item) {
        final excerpt = (item['excerpt'] ?? '').toString().trim();
        final content = (item['content'] ?? '').toString().trim();
        final message = excerpt.isNotEmpty
            ? excerpt
            : content.length > 110
                ? '${content.substring(0, 110)}...'
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
        };
      }));
    } catch (e) {
      debugPrint('Failed to load dashboard education articles: $e');
    }

    try {
      final emergencyData = await SupabaseService.client
          .from('emergency_rules')
          .select('id,condition,severity,action')
          .limit(3);

      merged.addAll(List<Map<String, dynamic>>.from(emergencyData).map((item) {
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
        };
      }));
    } catch (e) {
      debugPrint('Failed to load dashboard emergency rules: $e');
    }

    if (!merged.any((item) => _normaliseNotificationType(item['type']) == 'milestone')) {
      merged.add(_dashboardMilestoneNotification(pregnancyProfile));
    }

    if (!merged.any((item) => _normaliseNotificationType(item['type']) == 'emergency')) {
      merged.addAll(_dashboardEmergencyNotifications());
    }

    merged.add({
      'id': 'daily-health-reminder-${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      'user_id': userId,
      'title': 'Daily Health Reminder',
      'message': 'Remember to log your mood, symptoms and pregnancy notes today.',
      'type': 'reminder',
      'is_read': true,
      'created_at': DateTime.now().toIso8601String(),
      'source_table': 'generated_reminder',
    });

    final readReceiptKeys = userId == null
        ? <String>{}
        : await _loadNotificationReadReceiptKeys(userId);

    final visible = merged.where((item) {
      final sourceTable = item['source_table']?.toString() ?? 'notifications';
      final sourceId = item['id']?.toString();

      if (sourceTable == 'notifications' && item['is_read'] == true) {
        return false;
      }

      if (sourceId != null &&
          readReceiptKeys.contains(
            _notificationReadReceiptKey(sourceTable, sourceId),
          )) {
        return false;
      }

      return item['is_read'] != true;
    }).toList();

    visible.sort((a, b) {
      final aRead = a['is_read'] == true ? 1 : 0;
      final bRead = b['is_read'] == true ? 1 : 0;
      final unreadCompare = aRead.compareTo(bRead);
      if (unreadCompare != 0) return unreadCompare;
      return _notificationCreatedAt(b).compareTo(_notificationCreatedAt(a));
    });

    return visible.take(6).toList();
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

  Future<void> _openNotificationsCentre() async {
    if (!_canNav()) return;

    await context.push('/notifications');

    // Refresh dashboard after returning from Notifications Centre.
    // This is important because Mark All As Read is done on the
    // Notifications Centre page, while the dashboard keeps its own list
    // in memory until we reload it.
    if (mounted) {
      await _load();
    }
  }

  Future<void> _openDashboardNotification(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    final sourceTable = notification['source_table']?.toString() ?? 'notifications';
    final type = _normaliseNotificationType(notification['type']);

    // Remove the card from the dashboard immediately after the user opens it.
    // This keeps Active Alerts & Notifications clear once the item is read.
    if (id != null) {
      setState(() {
        _notifications = _notifications.where((n) {
          return !(n['id']?.toString() == id &&
              (n['source_table']?.toString() ?? 'notifications') == sourceTable);
        }).toList();
      });

      // Always save a read receipt so the dashboard stays cleared after
      // app restart. This also handles global notifications where user_id is NULL.
      await _saveNotificationReadReceipt(notification);

      if (sourceTable == 'notifications') {
        try {
          final userId = SupabaseService.currentUser?.id;
          final itemUserId = notification['user_id']?.toString();

          // Only update user-owned notification rows. Global notification rows
          // are cleared per user through notification_read_receipts.
          if (userId != null && itemUserId == userId) {
            await SupabaseService.client
                .from('notifications')
                .update({'is_read': true})
                .eq('id', id)
                .eq('user_id', userId);
          }
        } catch (e) {
          debugPrint('Failed to mark dashboard notification as read: $e');
        }
      }
    }

    if (!mounted) return;

    if (type == 'ai') {
      await _showRecommendationDetails(notification);
      return;
    }

    // For dashboard preview cards, open the full Notifications Centre.
    // The Notifications Centre now shows the correct detail sheet for
    // emergency, consultation, milestone, education, reminder and AI items.
    await _openNotificationsCentre();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? profile;
    Map<String, dynamic>? pp;
    List<Map<String, dynamic>> consultations = [];
    List<Map<String, dynamic>> notifications = [];
    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}
    // Fall back to JWT metadata for name display.
    if (profile == null) {
      final meta = SupabaseService.currentUser?.userMetadata;
      if (meta != null) {
        profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }
    try {
      pp = await SupabaseService.getPregnancyProfile();
    } catch (_) {}
    try {
      consultations = await SupabaseService.getConsultations();
    } catch (_) {}

    List<Map<String, dynamic>> myQuestions = [];
    try {
      myQuestions = await SupabaseService.getMyVolunteerQuestions();
    } catch (_) {}

    // Load latest notifications and active alerts for the dashboard preview.
    notifications = await _loadDashboardNotifications(profile, pp);

    // Look up provider names for whichever consultations the Active Alerts
    // card will actually show, so it can read "2:00 PM - Nur Aisyah".
    final activeSpecialistIds = consultations
        .where((c) {
          final status = (c['status'] as String? ?? '').toLowerCase();
          return status == 'pending' || status == 'confirmed';
        })
        .take(2)
        .map((c) => c['specialist_id'] as String?)
        .whereType<String>()
        .toSet();
    final providerNames = <String, String>{};
    for (final id in activeSpecialistIds) {
      try {
        final p = await SupabaseService.getProviderProfile(id);
        final name =
            (p?['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
        if (name != null) providerNames[id] = name;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _profile = profile;
        _pregnancyProfile = pp;
        _consultations = consultations;
        _notifications = notifications;
        _myQuestions = myQuestions;
        _providerNames = providerNames;
        _loading = false;
      });
    }
  }

  int get _currentWeek {
    if (_pregnancyProfile == null) return 0;
    // Prefer due_date — recalculates week automatically over time.
    final dueDateStr = _pregnancyProfile!['due_date'] as String?;
    if (dueDateStr != null) {
      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate != null) {
        final conception = dueDate.subtract(const Duration(days: 280));
        final week = DateTime.now().difference(conception).inDays ~/ 7;
        return week.clamp(1, 42);
      }
    }
    // Fallback: use the stored week snapshot.
    final stored = _pregnancyProfile!['current_week'] ??
        _pregnancyProfile!['pregnancy_week'];
    if (stored != null) return (stored as num).toInt().clamp(1, 42);
    return 0;
  }

  Future<void> _pickAndSaveDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 140)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 300)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.rose)),
        child: child!,
      ),
    );
    if (picked != null) {
      try {
        await SupabaseService.updateDueDate(picked);
      } catch (_) {}
      _load();
    }
  }

  // Single source of truth lives in pregnancyWeekData (shared with the Baby
  // Development screen) so the two screens never disagree on a given week.
  String _babySize(int week) {
    final data = pregnancyWeekData[week];
    if (data == null) return 'growing strong 🌸';
    return '${data['size']} ${data['emoji']}';
  }

  String? _babyWeight(int week) => pregnancyWeekData[week]?['weight'];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName =>
      (_profile?['full_name'] as String? ?? 'there').split(' ').first;

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPremium = auth.isPremium;
    final isMum = auth.isMum;

    if (_loading) return const Scaffold(body: TBLoading());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.rose,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              expandedHeight: isPremium ? 172 : 160,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.blush,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$_greeting, $_firstName! 🌸',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontSize: 20)),
                                const SizedBox(height: 2),
                                Text(
                                    DateFormat('EEEE, d MMMM')
                                        .format(DateTime.now()),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textMid, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                              child: _photoUrl != null
                                  ? null
                                  : Text(
                                      _firstName.isNotEmpty
                                          ? _firstName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: AppColors.roseDeep,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                      if (isPremium) ...[
                        const SizedBox(height: 6),
                        const PremiumBadge(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mum-specific: pregnancy week card
                    if (isMum) ...[
                      _buildPregnancyCard(context),
                      const SizedBox(height: 20),
                    ],

                    // Active alerts: milestones + upcoming consultations
                    _buildActiveAlerts(),

                    // Mum-specific: her posted volunteer questions
                    if (isMum && _myQuestions.isNotEmpty) ...[
                      _buildMyQuestions(),
                    ],

                    // Upcoming features
                    const TBSectionTitle(
                      title: 'Explore',
                      action: '',
                    ),
                    const SizedBox(height: 12),
                    _buildExploreGrid(context, isPremium),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Named milestones for a handful of well-known weeks, falling back to the
  // existing per-week development highlight for everything else.
  String _milestoneLabel(int week) {
    const named = {
      4: 'Pregnancy confirmed',
      8: 'Heartbeat detectable',
      12: 'End of first trimester',
      13: 'Second trimester begins',
      20: 'Halfway there!',
      23: 'Viability milestone reached',
      24: 'Viability milestone reached',
      28: 'Third trimester begins',
      37: 'Full term soon',
      40: 'Full term!',
    };
    return named[week] ??
        (pregnancyWeekData[week]?['highlight'] ?? 'Growing strong');
  }

  String get _trimesterLabel {
    if (_currentWeek <= 12) return '1st Trimester';
    if (_currentWeek <= 27) return '2nd Trimester';
    return '3rd Trimester';
  }

  // Progress through the *current* trimester, not the whole pregnancy.
  double get _trimesterProgress {
    final week = _currentWeek;
    if (week <= 12) return week / 12;
    if (week <= 27) return (week - 12) / 15;
    return (week - 27) / 13;
  }

  // "Week X of Y" within the current trimester, for the caption under the bar.
  (int, int) get _trimesterWeekOverview {
    final week = _currentWeek;
    if (week <= 12) return (week, 12);
    if (week <= 27) return (week - 12, 15);
    return (week - 27, 13);
  }

  // Tappable — leads to Baby Development. (The "New Milestone" alert leads
  // to the Milestone Journey screen instead.)
  Widget _buildPregnancyCard(BuildContext context) {
    final week = _currentWeek;
    final hasDate = week > 0;
    return GestureDetector(
      onTap: () {
        if (_canNav()) context.push('/baby-development');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🌸  Your Pregnancy',
                    style: TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Icon(Icons.chevron_right, color: AppColors.roseDeep, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            if (hasDate) ...[
              const Text('Current week',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              Text('Week $week',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 28, color: AppColors.rose)),
              const SizedBox(height: 2),
              Text('${_milestoneLabel(week)} ✦',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Trimester progress',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_trimesterLabel,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('${(_trimesterProgress.clamp(0.0, 1.0) * 100).round()}%',
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _trimesterProgress.clamp(0.0, 1.0),
                backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                  'Week ${_trimesterWeekOverview.$1} of ${_trimesterWeekOverview.$2} this trimester',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
            ] else ...[
              const SizedBox(height: 4),
              const Text('When is your baby due?',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickAndSaveDueDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text('Set Due Date',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlerts() {
    final cards = <Widget>[];

    // Only show unread dashboard notifications loaded from the database or
    // generated alert sources. Do not recreate fallback milestone/consultation
    // cards here, because that makes the dashboard look unread again after
    // the user taps Mark all as read.
    for (final n in _notifications.take(3)) {
      final type = _normaliseNotificationType(n['type']);

      cards.add(
        _notificationPreviewCard(
          title: (n['title'] ?? 'Notification').toString(),
          message: (n['message'] ?? '').toString(),
          type: type,
          isRead: n['is_read'] == true,
          onTap: () => _openDashboardNotification(n),
        ),
      );
    }

    if (cards.isEmpty) {
      cards.add(_emptyAlertCard());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Active Alerts & Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _openNotificationsCentre,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cards,
        const SizedBox(height: 20),
      ],
    );
  }


  Widget _buildMyQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Questions to Volunteers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/consultation'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._myQuestions.take(3).map((q) {
          // Whether *any* reply has happened, not whether the chat is
          // still active — a closed chat already had a reply, so it
          // shouldn't regress back to "waiting" once it's completed.
          final hasReply = q['status'] != 'pending';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TBCard(
              onTap: () async {
                await context.push('/ask-volunteer/detail', extra: q);
                _load();
              },
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        (hasReply ? AppColors.sage : AppColors.gold)
                            .withValues(alpha: 0.15),
                    child: Text(hasReply ? '✅' : '⏳'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q['question'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          hasReply
                              ? 'A volunteer has replied'
                              : 'Waiting for a volunteer to reply',
                          style: TextStyle(
                              color: hasReply
                                  ? AppColors.sage
                                  : AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textLight, size: 18),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _emptyAlertCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: _openNotificationsCentre,
        padding: const EdgeInsets.all(14),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.blush,
              child: Icon(
                Icons.notifications_none_outlined,
                color: AppColors.roseDeep,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No new alerts today. Tap View All to open the Notifications Centre.',
                style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    switch (_normaliseNotificationType(type)) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'milestone':
        return Icons.auto_awesome;
      case 'consultation':
        return Icons.calendar_today_outlined;
      case 'education':
        return Icons.menu_book_outlined;
      case 'ai':
        return Icons.smart_toy_outlined;
      case 'reminder':
        return Icons.water_drop_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _notificationColor(String type) {
    switch (_normaliseNotificationType(type)) {
      case 'emergency':
        return Colors.redAccent;
      case 'milestone':
        return AppColors.rose;
      case 'consultation':
        return AppColors.sage;
      case 'education':
        return AppColors.teal;
      case 'ai':
        return Colors.purpleAccent;
      case 'reminder':
        return AppColors.roseDeep;
      default:
        return AppColors.textMid;
    }
  }

  Widget _notificationPreviewCard({
    required String title,
    required String message,
    required String type,
    required bool isRead,
    required VoidCallback onTap,
  }) {
    final color = _notificationColor(type);
    final isEmergency = type == 'emergency';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: onTap,
        // Smaller padding prevents the alert row from being a few pixels too wide
        // on smaller Android screens.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_notificationIcon(type), color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (isEmergency) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Urgent',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    message.isEmpty ? 'Tap to view more details.' : message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            const SizedBox(
              width: 14,
              child: Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _appointmentDateLabel(String? scheduledDate, String? status) {
    final normalisedStatus = (status ?? '').toLowerCase();
    if (normalisedStatus == 'pending') return 'Appointment Pending Approval';

    final date =
        scheduledDate != null ? DateTime.tryParse(scheduledDate) : null;
    if (date == null) return 'Upcoming Appointment';
    final today = DateTime.now();
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'Appointment Today';
    if (diff == 1) return 'Appointment Tomorrow';
    if (diff < 0) return 'Past Appointment';
    return 'Appointment on ${DateFormat('d MMM').format(date)}';
  }

  String _dashboardTimeOnly(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    var time = value.trim();

    if (time.toLowerCase().startsWith('today')) {
      time = time.substring(5).trim();
    }

    if (time.contains('-')) {
      time = time.split('-').first.trim();
    }

    return time;
  }

  String _appointmentSubtitle(Map<String, dynamic> c) {
    final type = (c['consultation_type'] as String? ?? 'specialist');
    final typeLabel =
        '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
    final time = _dashboardTimeOnly(c['scheduled_time'] as String?);
    final providerName = _providerNames[c['specialist_id']];
    if (time.isEmpty && providerName == null) return typeLabel;
    final timeProvider = [if (time.isNotEmpty) time, providerName]
        .whereType<String>()
        .join(' - ');
    return '$typeLabel\n$timeProvider';
  }

  Widget _alertCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreGrid(BuildContext context, bool isPremium) {
    final items = [
      {
        'emoji': '🤖',
        'title': 'AI Assistant',
        'desc': 'Get pregnancy guidance',
        'route': '/chatbot',
        'premium': false,
      },
      {
        'emoji': '👩‍⚕️',
        'title': 'Consultations',
        'desc': 'Book volunteer or specialist support',
        'route': '/consultation',
        'premium': false,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) =>
          _exploreCard(context, items[index], isPremium),
    );
  }

  Widget _exploreCard(
      BuildContext context, Map<String, Object> item, bool isPremium) {
    return GestureDetector(
      onTap: () {
        if (_canNav()) context.push(item['route'] as String);
      },
      child: TBCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['emoji'] as String, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              item['title'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                item['desc'] as String,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 11,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
