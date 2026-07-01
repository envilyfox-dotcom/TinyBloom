import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

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

  Future<void> _loadNotifications() async {
    final userId = SupabaseService.currentUser?.id;

    if (userId == null) {
      setState(() {
        _notifications = [];
        _loading = false;
      });
      return;
    }

    final data = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    setState(() {
      _notifications = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _markAsRead(String id) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true}).eq('id', id);

    await _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true}).eq('user_id', userId);

    await _loadNotifications();
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'All') return _notifications;

    final type = _selectedFilter.toLowerCase();

    return _notifications.where((n) {
      final itemType = (n['type'] ?? '').toString().toLowerCase();

      if (type == 'consultation') return itemType == 'appointment';
      return itemType == type;
    }).toList();
  }

  int get _urgentCount {
    return _notifications.where((n) {
      return (n['type'] ?? '').toString().toLowerCase() == 'emergency' &&
          n['is_read'] != true;
    }).length;
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    await _markAsRead(item['id'].toString());

    final type = (item['type'] ?? '').toString().toLowerCase();

    if (!mounted) return;

    switch (type) {
      case 'emergency':
        context.push('/logs/create');
        break;

      case 'milestone':
        context.push('/milestone-journey');
        break;

      case 'appointment':
        context.push('/consultation');
        break;

      case 'education':
        context.push('/education');
        break;

      case 'reminder':
        context.push('/logs/create');
        break;

      case 'ai':
        context.push('/chatbot');
        break;

      default:
        context.push('/notifications');
        break;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'milestone':
        return Icons.auto_awesome;
      case 'appointment':
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
    switch (type.toLowerCase()) {
      case 'emergency':
        return Colors.redAccent;
      case 'milestone':
        return AppColors.rose;
      case 'appointment':
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
    switch (type.toLowerCase()) {
      case 'emergency':
        return 'Emergency Alert';
      case 'milestone':
        return 'Pregnancy Milestone';
      case 'appointment':
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
    final unreadCount =
        _notifications.where((n) => n['is_read'] != true).length;

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
                          onPressed: () => context.pop(),
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
                    if (_notifications.isNotEmpty)
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
            'Alerts, consultations, milestones and reminders will appear here.',
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
    final type = (item['type'] ?? 'general').toString().toLowerCase();
    final color = _colorForType(type);
    final icon = _iconForType(type);
    final isRead = item['is_read'] == true;
    final isEmergency = type == 'emergency';

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
                      if (isEmergency)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Urgent',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['title'] ?? '',
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
                    item['message'] ?? '',
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
