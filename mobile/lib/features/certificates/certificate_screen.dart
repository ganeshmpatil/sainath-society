import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ─── State ────────────────────────────────────────────────────────

class _St extends Equatable {
  final bool loading;
  final List<Map<String, dynamic>> certificates;
  const _St({this.loading = false, this.certificates = const []});
  @override List<Object?> get props => [loading, certificates];
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());
  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/certificates');
      final list = (res.data['certificates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      emit(_St(certificates: list));
    } catch (_) {
      emit(const _St());
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => _Cu()..load(), child: const _Body());
  }
}

class _Body extends StatefulWidget {
  const _Body();
  @override State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is Authenticated && s.user.role == 'ADMIN';
  }

  String? get _flatId {
    final s = context.read<AuthBloc>().state;
    if (s is Authenticated) return s.user.flatId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l.t('cert.title'))),
      body: RefreshIndicator(
        onRefresh: () => context.read<_Cu>().load(),
        child: BlocBuilder<_Cu, _St>(builder: (context, state) {
          if (state.loading) return const ShimmerLoading(itemCount: 4);
          if (state.certificates.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(l.t('cert.noCerts'), style: TextStyle(color: AppColors.textTertiary)),
              const SizedBox(height: 8),
              Text(l.t('cert.noCertsHint'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary), textAlign: TextAlign.center),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.certificates.length,
            itemBuilder: (_, i) => _CertCard(cert: state.certificates[i], l: l, isAdmin: _isAdmin),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestDialog(context, l),
        icon: const Icon(Icons.add),
        label: Text(l.t('cert.request')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showRequestDialog(BuildContext context, AppLocalizations l) {
    String certType = 'NO_DUES';
    final purposeCtl = TextEditingController();
    final buyerCtl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
          builder: (ctx2, setSheetState) => Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(l.t('cert.requestTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: certType,
                decoration: InputDecoration(labelText: l.t('cert.type'), border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'NO_DUES', child: Text(l.t('cert.noDues'))),
                  DropdownMenuItem(value: 'NOC', child: Text(l.t('cert.noc'))),
                ],
                onChanged: (v) => setSheetState(() => certType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtl,
                decoration: InputDecoration(
                  labelText: l.t('cert.purpose'),
                  hintText: certType == 'NO_DUES' ? 'Bank loan / Passport' : 'Flat sale / Transfer',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (certType == 'NOC') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: buyerCtl,
                  decoration: InputDecoration(labelText: l.t('cert.buyerName'), border: const OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  if (_flatId == null) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      const SnackBar(content: Text('No flat assigned'), backgroundColor: Colors.red));
                    return;
                  }
                  try {
                    await api.post('/certificates', data: {
                      'type': certType,
                      'flatId': _flatId,
                      'purpose': purposeCtl.text.trim(),
                      if (certType == 'NOC') 'buyerName': buyerCtl.text.trim(),
                    });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    if (mounted) {
                      context.read<_Cu>().load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.t('cert.requested')), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  }
                },
                child: Text(l.t('cert.submitRequest')),
              )),
            ],
          )),
        ),
      ),
    ),
    );
  }
}

class _CertCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  final AppLocalizations l;
  final bool isAdmin;
  const _CertCard({required this.cert, required this.l, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final type = cert['type'] ?? '';
    final status = cert['status'] ?? '';
    final certNo = cert['certNo'] ?? '';
    final purpose = cert['purpose'] ?? '';
    final pending = ((cert['pendingAmount'] ?? 0) as num).toDouble();
    final flat = cert['flat'] as Map<String, dynamic>?;
    final member = cert['member'] as Map<String, dynamic>?;
    final flatNo = flat?['flatNumber'] ?? '';
    final memberName = member?['name'] ?? '';
    final issueDate = cert['issueDate']?.toString().substring(0, 10) ?? '';
    final validUntil = cert['validUntil']?.toString().substring(0, 10) ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'APPROVED':
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_bottom;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(type == 'NOC' ? Icons.description : Icons.verified_user,
                  color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type == 'NOC' ? l.t('cert.noc') : l.t('cert.noDues'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(certNo, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          if (isAdmin) _infoRow(Icons.person, '$memberName — $flatNo'),
          if (purpose.isNotEmpty) _infoRow(Icons.note, purpose),
          if (pending > 0) _infoRow(Icons.warning_amber, '${l.t('cert.pendingDues')}: \u20B9${pending.toStringAsFixed(0)}',
              color: Colors.red),
          if (status == 'APPROVED') ...[
            _infoRow(Icons.event, '${l.t('cert.issued')}: $issueDate'),
            _infoRow(Icons.schedule, '${l.t('cert.validUntil')}: $validUntil'),
          ],
          if (cert['rejectionNote'] != null && (cert['rejectionNote'] as String).isNotEmpty)
            _infoRow(Icons.info, cert['rejectionNote'], color: Colors.red),

          // Admin actions
          if (isAdmin && status == 'REQUESTED') ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => _reject(context, cert['id']),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l.t('cert.reject')),
              )),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(
                onPressed: () => _approve(context, cert['id']),
                child: Text(l.t('cert.approve')),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(icon, size: 13, color: color ?? AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color ?? AppColors.textSecondary))),
      ]),
    );
  }

  Future<void> _approve(BuildContext context, String id) async {
    try {
      await api.post('/certificates/$id/approve');
      if (context.mounted) context.read<_Cu>().load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject(BuildContext context, String id) async {
    final reasonCtl = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(l.t('cert.rejectReason')),
      content: TextField(controller: reasonCtl, decoration: const InputDecoration(border: OutlineInputBorder()), maxLines: 2),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('common.cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.t('cert.reject'))),
      ],
    ));
    if (confirmed != true || reasonCtl.text.isEmpty) return;
    try {
      await api.post('/certificates/$id/reject', data: {'reason': reasonCtl.text.trim()});
      if (context.mounted) context.read<_Cu>().load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }
}
