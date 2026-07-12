import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class VolunteerServicesScreen extends StatefulWidget {
  const VolunteerServicesScreen({super.key});

  @override
  State<VolunteerServicesScreen> createState() =>
      _VolunteerServicesScreenState();
}

class _VolunteerServicesScreenState extends State<VolunteerServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // A service's availability slot end time (matches the timing options
  // offered on the publish/edit form).
  static const _timingEndHour = {
    'Morning (9AM - 12PM)': 12,
    'Afternoon (12PM - 3PM)': 15,
    'Evening (3PM - 6PM)': 18,
    'Night (6PM - 9PM)': 21,
  };

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
      final endHour = _timingEndHour[parts.length > 1 ? parts[1] : ''];
      if (date == null || endHour == null) continue;
      final endsAt = DateTime(date.year, date.month, date.day, endHour);
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

  List<Map<String, dynamic>> _byStatus(String status) =>
      _services.where((s) => (s['status'] ?? 'available') == status).toList();

  Future<void> _deleteService(Map<String, dynamic> service) async {
    try {
      await SupabaseService.client
          .from('volunteer_services')
          .delete()
          .eq('id', service['id']);
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
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
          ),
          child: Text('Services',
              style: GoogleFonts.poppins(
                  fontSize: 15, color: AppColors.textDark)),
        ),
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
            Tab(text: 'Expired'),
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
          : TabBarView(
              controller: _tabs,
              children: [
                _ServiceList(
                    services: _services,
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
    );
  }

  void _onEdit(Map<String, dynamic> service) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ServiceFormScreen(mode: ServiceMode.edit, service: service),
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
                child: Text(isDone ? 'Expired' : 'Available',
                    style: GoogleFonts.poppins(
                        color: isDone ? Colors.red.shade400 : AppColors.sage,
                        fontWeight: FontWeight.w600,
                        fontSize: 10)),
              ),
            ],
          ),
          if (category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.label_outline, size: 13, color: AppColors.textLight),
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
                Icon(Icons.schedule_outlined,
                    size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(availability,
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
                    side: BorderSide(color: AppColors.rose),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Edit', style: GoogleFonts.poppins()),
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

enum ServiceMode { create, edit, delete }

class ServiceFormScreen extends StatefulWidget {
  final ServiceMode mode;
  final Map<String, dynamic>? service;

  const ServiceFormScreen({super.key, required this.mode, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  static const _timingOptions = [
    'Morning (9AM - 12PM)',
    'Afternoon (12PM - 3PM)',
    'Evening (3PM - 6PM)',
    'Night (6PM - 9PM)',
  ];

  static const _consultationMethods = ['Chat', 'Video'];

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _catCtrl;
  DateTime? _availDate;
  String? _availTiming;
  String? _consultationMethod;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.service?['title'] ?? '');
    _descCtrl =
        TextEditingController(text: widget.service?['description'] ?? '');
    _catCtrl = TextEditingController(text: widget.service?['category'] ?? '');
    final method = widget.service?['consultation_method'] as String?;
    if (_consultationMethods.contains(method)) _consultationMethod = method;

    final avail = widget.service?['availability'] as String?;
    if (avail != null && avail.contains(' | ')) {
      final parts = avail.split(' | ');
      _availDate = DateTime.tryParse(parts[0]);
      if (parts.length > 1 && _timingOptions.contains(parts[1])) {
        _availTiming = parts[1];
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _catCtrl.dispose();
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

  String get _formTitle {
    switch (widget.mode) {
      case ServiceMode.create:
        return 'New Services';
      case ServiceMode.edit:
        return 'Edit Services';
      case ServiceMode.delete:
        return 'Delete Services';
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
    }
  }

  Future<void> _handlePrimary() async {
    if (widget.mode != ServiceMode.delete) {
      if (_titleCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a service title.')));
        return;
      }
      if (_availDate == null || _availTiming == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please select an availability date and time.')));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final availability =
          '${DateFormat('yyyy-MM-dd').format(_availDate ?? DateTime.now())} | $_availTiming';
      if (widget.mode == ServiceMode.create) {
        await SupabaseService.client.from('volunteer_services').insert({
          'volunteer_id': SupabaseService.currentUser!.id,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'availability': availability,
          'category': _catCtrl.text.trim(),
          'consultation_method': _consultationMethod,
          'status': 'available',
        });
      } else if (widget.mode == ServiceMode.edit) {
        await SupabaseService.client.from('volunteer_services').update({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'availability': availability,
          'category': _catCtrl.text.trim(),
          'consultation_method': _consultationMethod,
        }).eq('id', widget.service!['id']);
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
    final isReadOnly = widget.mode == ServiceMode.delete;
    final isDelete = widget.mode == ServiceMode.delete;

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
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
          ),
          child: Text('Services',
              style: GoogleFonts.poppins(
                  fontSize: 15, color: AppColors.textDark)),
        ),
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
              _field('Description', _descCtrl, readOnly: isReadOnly),
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
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.rose),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _availDate != null
                              ? DateFormat('d MMM yyyy').format(_availDate!)
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
              Text('Availability Time',
                  style:
                      GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    initialValue: _availTiming,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.rose),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.access_time,
                            size: 16, color: AppColors.rose),
                      ),
                      prefixIconConstraints:
                          BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    hint: Text('Select Time',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textLight)),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textDark),
                    items: _timingOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (v) => setState(() => _availTiming = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _field('Category', _catCtrl, readOnly: isReadOnly),
              const SizedBox(height: 12),
              Text('Preferred Consultation Method',
                  style:
                      GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _consultationMethods.map((method) {
                  final selected = _consultationMethod == method;
                  return ChoiceChip(
                    label: Text(method),
                    selected: selected,
                    onSelected: isReadOnly
                        ? null
                        : (value) => setState(
                            () => _consultationMethod = value ? method : null),
                    showCheckmark: false,
                    selectedColor: AppColors.rose,
                    backgroundColor: AppColors.white,
                    side: BorderSide(
                        color: selected
                            ? Colors.transparent
                            : AppColors.textLight.withValues(alpha: 0.3)),
                    labelStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.textDark),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
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
                            color: AppColors.textLight.withValues(alpha: 0.4)),
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
                                  fontWeight: FontWeight.w600, fontSize: 13)),
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

  Widget _field(String label, TextEditingController ctrl,
      {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
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
}
