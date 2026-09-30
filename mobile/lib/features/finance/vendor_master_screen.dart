import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ═══════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════
class _VmState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> vendors;
  const _VmState({this.loading = false, this.error, this.vendors = const []});
  @override
  List<Object?> get props => [loading, error, vendors];
}

class _VmCubit extends Cubit<_VmState> {
  _VmCubit() : super(const _VmState());

  Future<void> load() async {
    emit(const _VmState(loading: true));
    try {
      final res = await api.get('/finance/vendors');
      final list = (res.data['vendors'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      emit(_VmState(vendors: list));
    } catch (e) {
      emit(_VmState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class VendorMasterScreen extends StatelessWidget {
  const VendorMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _VmCubit()..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('vendor.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_VmCubit, _VmState>(
        builder: (context, state) {
          if (state.loading) return const ShimmerLoading();
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.t('common.error'),
                      style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<_VmCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          if (state.vendors.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_outlined, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(l.t('vendor.noVendors'),
                      style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<_VmCubit>().load(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: state.vendors.length,
              itemBuilder: (_, i) =>
                  _VendorCard(vendor: state.vendors[i], isMr: isMr),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVendorDialog(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showAddVendorDialog(BuildContext ctx) {
    final l = AppLocalizations.of(ctx);
    final cubit = ctx.read<_VmCubit>();
    final nameCtl = TextEditingController();
    final nameMrCtl = TextEditingController();
    final panCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final addressCtl = TextEditingController();
    String vendorType = 'CONTRACTOR';

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.t('vendor.addVendor')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameMrCtl,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.nameMr'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: vendorType,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.type'),
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CONTRACTOR', child: Text('Contractor')),
                    DropdownMenuItem(value: 'PROFESSIONAL', child: Text('Professional (CA/Lawyer)')),
                    DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee')),
                    DropdownMenuItem(value: 'LANDLORD', child: Text('Landlord')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => vendorType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: panCtl,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.pan'),
                    hintText: 'ABCDE1234F',
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtl,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.phone'),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtl,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.email'),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtl,
                  decoration: InputDecoration(
                    labelText: l.t('vendor.address'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtl.text.isEmpty) return;
                try {
                  await api.post('/finance/vendors', data: {
                    'name': nameCtl.text.trim(),
                    'nameMr': nameMrCtl.text.trim(),
                    'vendorType': vendorType,
                    'pan': panCtl.text.trim().toUpperCase(),
                    'phone': phoneCtl.text.trim(),
                    'email': emailCtl.text.trim(),
                    'address': addressCtl.text.trim(),
                  });
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  cubit.load();
                } catch (e) {
                  if (dialogCtx.mounted) {
                    ScaffoldMessenger.of(dialogCtx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: Text(l.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Map<String, dynamic> vendor;
  final bool isMr;
  const _VendorCard({required this.vendor, required this.isMr});

  @override
  Widget build(BuildContext context) {
    final name = isMr && (vendor['nameMr'] ?? '').toString().isNotEmpty
        ? vendor['nameMr']
        : vendor['name'];
    final vType = vendor['vendorType'] ?? '';
    final pan = vendor['pan'] ?? '';
    final phone = vendor['phone'] ?? '';
    final tdsSection = vendor['tdsSection'] ?? '';
    final tdsRate = (vendor['tdsRate'] ?? 0).toDouble();
    final color = _typeColor(vType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha(30),
                child: Icon(_typeIcon(vType), size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(_typeLabel(vType),
                        style: TextStyle(fontSize: 11, color: color)),
                  ],
                ),
              ),
              if (tdsSection.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'TDS $tdsSection @ ${tdsRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800]),
                  ),
                ),
            ],
          ),
          if (pan.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (pan.isNotEmpty) ...[
                  Icon(Icons.badge_outlined,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('PAN: $pan',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                  const SizedBox(width: 16),
                ],
                if (phone.isNotEmpty) ...[
                  Icon(Icons.phone_outlined,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(phone,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'CONTRACTOR': return Colors.blue;
      case 'PROFESSIONAL': return Colors.purple;
      case 'EMPLOYEE': return Colors.green;
      case 'LANDLORD': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'CONTRACTOR': return Icons.engineering;
      case 'PROFESSIONAL': return Icons.gavel;
      case 'EMPLOYEE': return Icons.person;
      case 'LANDLORD': return Icons.home;
      default: return Icons.store;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'CONTRACTOR': return 'Contractor';
      case 'PROFESSIONAL': return 'Professional';
      case 'EMPLOYEE': return 'Employee';
      case 'LANDLORD': return 'Landlord';
      default: return 'Other';
    }
  }
}
