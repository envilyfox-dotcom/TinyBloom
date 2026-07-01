import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';

class VolunteerServicesScreen extends StatefulWidget {
  const VolunteerServicesScreen({super.key});

  @override
  State<VolunteerServicesScreen> createState() =>
      _VolunteerServicesScreenState();
}

class _VolunteerServicesScreenState extends State<VolunteerServicesScreen>
    with SingleTickerProviderStateMixin {
  static const _pink = Color(0xFFE8A0B4);
  static const _roseDark = Color(0xFF9B8B86);
  static const _cardBg = Color(0xFFCB9189);

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

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('volunteer_services')
          .select()
          .eq('volunteer_id', SupabaseService.currentUser!.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF6B4A46)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF5DDD9)),
          ),
          child: Text('Services',
              style: GoogleFonts.poppins(
                  fontSize: 15, color: const Color(0xFF6B4A46))),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _pink,
          labelColor: _pink,
          unselectedLabelColor: _roseDark,
          labelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Available'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _pink,
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
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : TabBarView(
              controller: _tabs,
              children: [
                _ServiceList(
                    services: _services,
                    cardBg: _cardBg,
                    onEdit: _onEdit,
                    onDelete: _onDeleteConfirm),
                _ServiceList(
                    services: _byStatus('available'),
                    cardBg: _cardBg,
                    onEdit: _onEdit,
                    onDelete: _onDeleteConfirm),
                _ServiceList(
                    services: _byStatus('done'),
                    cardBg: _cardBg,
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
  final Color cardBg;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _ServiceList({
    required this.services,
    required this.cardBg,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Text('No services here yet.',
            style: GoogleFonts.poppins(
                color: const Color(0xFF9B8B86), fontSize: 14)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _ServiceCard(
        service: services[i],
        cardBg: cardBg,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final Color cardBg;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _ServiceCard({
    required this.service,
    required this.cardBg,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(service['title'] ?? '',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onEdit(service),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
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
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
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
  static const _pink = Color(0xFFE8A0B4);
  static const _cardBg = Color(0xFFCB9189);

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _availCtrl;
  late TextEditingController _catCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.service?['title'] ?? '');
    _descCtrl =
        TextEditingController(text: widget.service?['description'] ?? '');
    _availCtrl =
        TextEditingController(text: widget.service?['availability'] ?? '');
    _catCtrl = TextEditingController(text: widget.service?['category'] ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _availCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
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
    if (widget.mode != ServiceMode.delete && _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a service title.')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.mode == ServiceMode.create) {
        await SupabaseService.client.from('volunteer_services').insert({
          'volunteer_id': SupabaseService.currentUser!.id,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'availability': _availCtrl.text.trim(),
          'category': _catCtrl.text.trim(),
          'status': 'available',
        });
      } else if (widget.mode == ServiceMode.edit) {
        await SupabaseService.client.from('volunteer_services').update({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'availability': _availCtrl.text.trim(),
          'category': _catCtrl.text.trim(),
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
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF6B4A46)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF5DDD9)),
          ),
          child: Text('Services',
              style: GoogleFonts.poppins(
                  fontSize: 15, color: const Color(0xFF6B4A46))),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_formTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _field('Service Title', _titleCtrl, readOnly: isReadOnly),
              const SizedBox(height: 12),
              _field('Description', _descCtrl, readOnly: isReadOnly),
              const SizedBox(height: 12),
              _field('Availability', _availCtrl, readOnly: isReadOnly),
              const SizedBox(height: 12),
              _field('Category', _catCtrl, readOnly: isReadOnly),
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
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
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
                            isDelete ? Colors.red.shade300 : Colors.white,
                        foregroundColor:
                            isDelete ? Colors.white : const Color(0xFF6B4A46),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
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
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
