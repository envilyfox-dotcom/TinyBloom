import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/availability_format.dart';
import '../../utils/service_id.dart';

class VolunteerServicesScreen extends StatefulWidget {
  const VolunteerServicesScreen({super.key});

  @override
  State<VolunteerServicesScreen> createState() =>
      _VolunteerServicesScreenState();
}

class _VolunteerServicesScreenState extends State<VolunteerServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  String _searchQuery = '';
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    // Picks up services added/edited elsewhere (e.g. from another device)
    // without the volunteer having to manually pull-to-refresh.
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Legacy fixed timing slots, kept only so services published before
  // free-form times were introduced still auto-expire correctly.
  static const _timingEndHour = {
    'Morning (9AM - 12PM)': 12,
    'Afternoon (12PM - 3PM)': 15,
    'Evening (3PM - 6PM)': 18,
    'Night (6PM - 9PM)': 21,
  };

  // Free-form times are stored as "h:mm a - h:mm a" (e.g. "3:30 PM - 5:00 PM").
  // Returns the end-of-range time, or null if the string doesn't match.
  static DateTime? _parseFreeFormEndTime(DateTime date, String timing) {
    final match =
        RegExp(r'-\s*(\d{1,2}:\d{2}\s?[AaPp][Mm])\s*$').firstMatch(timing);
    if (match == null) return null;
    try {
      final parsed = DateFormat('h:mm a').parse(match.group(1)!.toUpperCase());
      return DateTime(date.year, date.month, date.day, parsed.hour, parsed.minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('volunteer_services')
          .select()
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .order('created_at', ascending: false);
      final services = List<Map<String, dynamic>>.from(data);
      await _autoMarkExpired(services);
      if (mounted) {
        setState(() {
          _services = services;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // A service whose availability slot has fully passed (e.g. "12PM - 3PM" on
  // 12 July, once it's past 3PM that day) is automatically marked done —
  // no manual toggle needed.
  Future<void> _autoMarkExpired(List<Map<String, dynamic>> services) async {
    final now = DateTime.now();
    for (final service in services) {
      if ((service['status'] as String? ?? 'available') != 'available') {
        continue;
      }
      final availability = service['availability'] as String?;
      if (availability == null || !availability.contains(' | ')) continue;
      final parts = availability.split(' | ');
      final date = DateTime.tryParse(parts[0]);
      final timing = parts.length > 1 ? parts[1] : '';
      if (date == null) continue;
      final endsAt = _parseFreeFormEndTime(date, timing) ??
          (_timingEndHour.containsKey(timing)
              ? DateTime(date.year, date.month, date.day,
                  _timingEndHour[timing]!)
              : null);
      if (endsAt == null) continue;
      if (now.isAfter(endsAt)) {
        try {
          await SupabaseService.client
              .from('volunteer_services')
              .update({'status': 'done'})
              .eq('id', service['id']);
          service['status'] = 'done';
        } catch (_) {}
      }
    }
  }

  bool _matchesSearch(Map<String, dynamic> service) {
    if (_searchQuery.isEmpty) return true;
    final title = (service['title'] as String? ?? '').toLowerCase();
    final category = (service['category'] as String? ?? '').toLowerCase();
    final serviceId = formatServiceId(service['service_number']).toLowerCase();
    return title.contains(_searchQuery) ||
        category.contains(_searchQuery) ||
        serviceId.contains(_searchQuery);
  }

  List<Map<String, dynamic>> get _searchedServices =>
      _services.where(_matchesSearch).toList();

  List<Map<String, dynamic>> _byStatus(String status) => _services
      .where((s) => (s['status'] ?? 'available') == status)
      .where(_matchesSearch)
      .toList();

  Future<void> _deleteService(Map<String, dynamic> service) async {
    try {
      await SupabaseService.client
          .from('volunteer_services')
          .delete()
          .eq('id', service['id']);
      // Broadcast (user_id: null) so every mum's Notifications Centre picks
      // it up under the Services filter — this listing has no per-mum
      // relationship to notify individually (see volunteer_services schema).
      try {
        final volunteerProfile = await SupabaseService.getProfile();
        final volunteerName =
            (volunteerProfile?['full_name'] as String?)?.trim();
        final volunteerPhotoUrl =
            (volunteerProfile?['profile_picture_url'] as String?)?.trim();
        await SupabaseService.client.from('notifications').insert({
          'user_id': null,
          'title': 'Service cancelled',
          'message':
              '"${service['title']}" is no longer available.',
          'type': 'services',
          'volunteer_name':
              volunteerName?.isNotEmpty == true ? volunteerName : null,
          'volunteer_photo_url': volunteerPhotoUrl?.isNotEmpty == true
              ? volunteerPhotoUrl
              : null,
        });
      } catch (_) {
        // Best-effort — the delete itself already succeeded.
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Service deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('Services',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.rose,
          labelColor: AppColors.rose,
          unselectedLabelColor: AppColors.textLight,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Available'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.rose,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ServiceFormScreen(mode: ServiceMode.create),
            ),
          );
          _load();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.rose))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search your services',
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textLight),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textLight, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.textLight, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color:
                                  AppColors.textLight.withValues(alpha: 0.3))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color:
                                  AppColors.textLight.withValues(alpha: 0.3))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.rose, width: 1.5)),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ServiceList(
                          services: _searchedServices,
                          onEdit: _onEdit,
                          onDelete: _onDeleteConfirm),
                      _ServiceList(
                          services: _byStatus('available'),
                          onEdit: _onEdit,
                          onDelete: _onDeleteConfirm),
                      _ServiceList(
                          services: _byStatus('done'),
                          onEdit: _onEdit,
                          onDelete: _onDeleteConfirm),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _onEdit(Map<String, dynamic> service) async {
    // A completed service is locked — no editing, no meeting join — but its
    // details stay fully viewable, same as a closed chat on the Requests page.
    final isDone = (service['status'] as String? ?? 'available') == 'done';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceFormScreen(
            mode: isDone ? ServiceMode.view : ServiceMode.edit,
            service: service),
      ),
    );
    _load();
  }

  void _onDeleteConfirm(Map<String, dynamic> service) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ServiceFormScreen(mode: ServiceMode.delete, service: service),
      ),
    );
    if (confirmed == true) await _deleteService(service);
  }
}

class _ServiceList extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _ServiceList({
    required this.services,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volunteer_activism_outlined,
                size: 48, color: AppColors.textLight.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No services here yet.',
                style: GoogleFonts.poppins(
                    color: AppColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Tap + to publish a service mums can book.',
                style: GoogleFonts.poppins(
                    color: AppColors.textLight.withValues(alpha: 0.8),
                    fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _ServiceCard(
        service: services[i],
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = service['status'] as String? ?? 'available';
    final isDone = status == 'done';
    final category = service['category'] as String? ?? '';
    final description = service['description'] as String? ?? '';
    final availability = service['availability'] as String? ?? '';
    final consultationMethod = service['consultation_method'] as String? ?? '';
    final serviceId = formatServiceId(service['service_number']);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(service['title'] ?? '',
                    style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDone ? Colors.red.shade400 : AppColors.sage)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(isDone ? 'Completed' : 'Available',
                    style: GoogleFonts.poppins(
                        color: isDone ? Colors.red.shade400 : AppColors.sage,
                        fontWeight: FontWeight.w600,
                        fontSize: 10)),
              ),
            ],
          ),
          if (serviceId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Service ID: $serviceId',
                style: GoogleFonts.poppins(
                    color: AppColors.textLight, fontSize: 11)),
          ],
          if (category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.label_outline, size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(category,
                    style: GoogleFonts.poppins(
                        color: AppColors.textMid, fontSize: 12)),
              ],
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: AppColors.textMid, fontSize: 12)),
          ],
          if (availability.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_outlined,
                    size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(formatAvailabilityDisplay(availability),
                      style: GoogleFonts.poppins(
                          color: AppColors.textMid, fontSize: 12)),
                ),
              ],
            ),
          ],
          if (consultationMethod.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                    consultationMethod == 'Video'
                        ? Icons.videocam_outlined
                        : Icons.chat_bubble_outline,
                    size: 13,
                    color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(consultationMethod,
                    style: GoogleFonts.poppins(
                        color: AppColors.textMid, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onEdit(service),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                    side: const BorderSide(color: AppColors.rose),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isDone ? 'View' : 'Edit',
                      style: GoogleFonts.poppins()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onDelete(service),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Delete', style: GoogleFonts.poppins()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Service Form (New / Edit / Delete) ───────────────────────────────────────

enum ServiceMode { create, edit, delete, view }

class ServiceFormScreen extends StatefulWidget {
  final ServiceMode mode;
  final Map<String, dynamic>? service;

  const ServiceFormScreen({super.key, required this.mode, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
<<<<<<< Updated upstream
  late TextEditingController _catCtrl;
=======
  late TextEditingController _zoomCtrl;
>>>>>>> Stashed changes
  DateTime? _availDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.service?['title'] ?? '');
    _descCtrl =
        TextEditingController(text: widget.service?['description'] ?? '');
<<<<<<< Updated upstream
    _catCtrl = TextEditingController(text: widget.service?['category'] ?? '');
=======
    _zoomCtrl = TextEditingController(text: widget.service?['zoom_link'] ?? '');
>>>>>>> Stashed changes

    final avail = widget.service?['availability'] as String?;
    if (avail != null && avail.contains(' | ')) {
      final parts = avail.split(' | ');
      _availDate = DateTime.tryParse(parts[0]);
      if (parts.length > 1) {
        final match = RegExp(
                r'^(\d{1,2}:\d{2}\s?[AaPp][Mm])\s*-\s*(\d{1,2}:\d{2}\s?[AaPp][Mm])$')
            .firstMatch(parts[1].trim());
        if (match != null) {
          _startTime = _tryParseTime(match.group(1)!);
          _endTime = _tryParseTime(match.group(2)!);
        }
      }
    }
  }

  TimeOfDay? _tryParseTime(String text) {
    try {
      final parsed = DateFormat('h:mm a').parse(text.toUpperCase());
      return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay t) {
    final dt = DateTime(2020, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
<<<<<<< Updated upstream
    _catCtrl.dispose();
=======
    _zoomCtrl.dispose();
>>>>>>> Stashed changes
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _availDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.rose),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _availDate = picked);
  }

  // Scroll-wheel time picker (replaces the old keyboard-entry showTimePicker)
  // shared by both Start Time and End Time.
  Future<TimeOfDay?> _showScrollTimePicker(TimeOfDay initial) {
    TimeOfDay selected = initial;
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: AppColors.textLight)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: Text('Done',
                      style: GoogleFonts.poppins(
                          color: AppColors.rose, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime:
                    DateTime(2020, 1, 1, initial.hour, initial.minute),
                onDateTimeChanged: (dt) =>
                    selected = TimeOfDay(hour: dt.hour, minute: dt.minute),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await _showScrollTimePicker(_startTime ?? TimeOfDay.now());
    if (picked == null || !mounted) return;
    setState(() {
      _startTime = picked;
      // A previously-picked end time that's no longer after the new start
      // time is no longer valid — clear it so an invalid combination can't
      // silently persist.
      if (_endTime != null &&
          (_endTime!.hour * 60 + _endTime!.minute) <=
              (picked.hour * 60 + picked.minute)) {
        _endTime = null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'End time cleared — it was no longer after the new start time.')));
      }
    });
  }

  Future<void> _pickEndTime() async {
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a start time first.')));
      return;
    }
    final picked =
        await _showScrollTimePicker(_endTime ?? _startTime ?? TimeOfDay.now());
    if (picked == null || !mounted) return;
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final pickedMinutes = picked.hour * 60 + picked.minute;
    if (pickedMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End time must be after the start time.')));
      return;
    }
    setState(() => _endTime = picked);
  }

  String get _formTitle {
    switch (widget.mode) {
      case ServiceMode.create:
        return 'New Services';
      case ServiceMode.edit:
        return 'Edit Services';
      case ServiceMode.delete:
        return 'Delete Services';
      case ServiceMode.view:
        return 'Service Details';
    }
  }

  String get _primaryLabel {
    switch (widget.mode) {
      case ServiceMode.create:
        return 'Publish Service';
      case ServiceMode.edit:
        return 'Save';
      case ServiceMode.delete:
        return 'Confirm Delete';
      case ServiceMode.view:
        return 'Close';
    }
  }

  Future<void> _handlePrimary() async {
    if (widget.mode == ServiceMode.view) {
      Navigator.pop(context);
      return;
    }
    if (widget.mode != ServiceMode.delete) {
      if (_titleCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a service title.')));
        return;
      }
      if (_availDate == null || _startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select an availability date and time.')));
        return;
      }
      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('End time must be after start time.')));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final availability = _startTime == null || _endTime == null
          ? ''
          : '${DateFormat('yyyy-MM-dd').format(_availDate ?? DateTime.now())} | '
              '${_formatTime(_startTime!)} - ${_formatTime(_endTime!)}';
      if (widget.mode == ServiceMode.create) {
        // A real, joinable Zoom meeting is minted for this slot instead of
        // asking the volunteer to paste one in — see
        // SupabaseService.createServiceZoomMeeting.
        final zoomLink = await SupabaseService.createServiceZoomMeeting(
          title: _titleCtrl.text.trim(),
          date: _availDate!,
          startTime: _formatTime(_startTime!),
          endTime: _formatTime(_endTime!),
        );
        await SupabaseService.client.from('volunteer_services').insert({
          'volunteer_id': SupabaseService.currentUser!.id,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'availability': availability,
<<<<<<< Updated upstream
          'category': _catCtrl.text.trim(),
          'zoom_link': zoomLink,
          'status': 'available',
        });
      } else if (widget.mode == ServiceMode.edit) {
        // zoom_link is left untouched — the meeting created at publish
        // time is still the same real, joinable link.
=======
          'zoom_link': _zoomCtrl.text.trim(),
          'status': 'available',
        });
      } else if (widget.mode == ServiceMode.edit) {
        final oldAvailability =
            (widget.service!['availability'] ?? '').toString();
        final timingChanged = availability != oldAvailability;
>>>>>>> Stashed changes
        await SupabaseService.client.from('volunteer_services').update({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'availability': availability,
<<<<<<< Updated upstream
          'category': _catCtrl.text.trim(),
=======
          'zoom_link': _zoomCtrl.text.trim(),
>>>>>>> Stashed changes
        }).eq('id', widget.service!['id']);

        // Broadcast (user_id: null) so every mum's Notifications Centre
        // picks it up under the Services filter on any saved edit — this
        // listing has no per-mum relationship to notify individually (see
        // volunteer_services schema).
        try {
          final volunteerProfile = await SupabaseService.getProfile();
          final volunteerName =
              (volunteerProfile?['full_name'] as String?)?.trim();
          final volunteerPhotoUrl =
              (volunteerProfile?['profile_picture_url'] as String?)?.trim();
          await SupabaseService.client.from('notifications').insert({
            'user_id': null,
            'title':
                timingChanged ? 'Service timing updated' : 'Service updated',
            'message': timingChanged
                ? '"${_titleCtrl.text.trim()}" now scheduled for ${formatAvailabilityDisplay(availability)}.'
                : '"${_titleCtrl.text.trim()}" has been updated.',
            'type': 'services',
            'volunteer_name':
                volunteerName?.isNotEmpty == true ? volunteerName : null,
            'volunteer_photo_url': volunteerPhotoUrl?.isNotEmpty == true
                ? volunteerPhotoUrl
                : null,
          });
        } catch (_) {
          // Best-effort — the update itself already succeeded.
        }
      }
      // delete is handled by the parent via pop(true)
      if (mounted) {
        Navigator.pop(
            context, widget.mode == ServiceMode.delete ? true : false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly =
        widget.mode == ServiceMode.delete || widget.mode == ServiceMode.view;
    final isDelete = widget.mode == ServiceMode.delete;
    final isView = widget.mode == ServiceMode.view;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textDark),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text('Services',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_formTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _field('Service Title', _titleCtrl, readOnly: isReadOnly),
              const SizedBox(height: 12),
              _field('Description', _descCtrl,
                  readOnly: isReadOnly, minLines: 4, maxLines: 8),
              const SizedBox(height: 12),
              Text('Availability Date',
                  style:
                      GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isReadOnly ? null : _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.textLight.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.rose.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.rose),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _availDate != null
                              ? DateFormat('dd/MM/yyyy').format(_availDate!)
                              : 'Select Date',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _availDate != null
                                  ? AppColors.textDark
                                  : AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _timeField(
                      label: 'Start Time',
                      time: _startTime,
                      onTap: isReadOnly ? null : _pickStartTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeField(
                      label: 'End Time',
                      time: _endTime,
                      onTap: isReadOnly ? null : _pickEndTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
<<<<<<< Updated upstream
              _field('Category', _catCtrl, readOnly: isReadOnly),
              const SizedBox(height: 12),
              _zoomLinkSection(),
=======
              _field('Zoom Link (for mums to join)', _zoomCtrl,
                  readOnly: isReadOnly),
>>>>>>> Stashed changes
              const SizedBox(height: 20),
              if (isView)
                // Completed services are read-only — a single Close button,
                // no Cancel/Save pair, same pattern as a closed chat on the
                // Requests page (info stays fully visible, nothing editable).
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Close',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/home');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMid,
                          side: BorderSide(
                              color:
                                  AppColors.textLight.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel', style: GoogleFonts.poppins()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _handlePrimary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDelete ? Colors.red.shade400 : AppColors.rose,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_primaryLabel,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Create mode: no link exists yet — it's minted from the chosen slot the
  // moment the volunteer hits Publish (see SupabaseService.createServiceZoomMeeting).
  // Edit/delete mode: show the real link that was generated at publish
  // time, read-only — there's nothing to type in any more.
  Widget _zoomLinkSection() {
    if (widget.mode == ServiceMode.create) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_outlined, size: 16, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A Zoom link will be created automatically for this slot when you publish.',
                style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final zoomLink = (widget.service?['zoom_link'] as String? ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zoom Link (for mums to join)',
            style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.textLight.withValues(alpha: 0.3)),
          ),
          child: Text(
            zoomLink.isEmpty ? 'No Zoom link on this listing yet.' : zoomLink,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: zoomLink.isEmpty ? AppColors.textLight : AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool readOnly = false, int minLines = 1, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          minLines: minLines,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.textLight.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: AppColors.textLight.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.rose, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _timeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.textLight.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.rose.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.rose),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    time != null ? _formatTime(time) : 'Select',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: time != null
                            ? AppColors.textDark
                            : AppColors.textLight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
