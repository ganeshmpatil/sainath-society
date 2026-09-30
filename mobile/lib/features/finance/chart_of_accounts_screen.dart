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
class _CoaState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> accounts;
  const _CoaState({this.loading = false, this.error, this.accounts = const []});
  @override
  List<Object?> get props => [loading, error, accounts];
}

class _CoaCubit extends Cubit<_CoaState> {
  _CoaCubit() : super(const _CoaState());

  Future<void> load() async {
    emit(const _CoaState(loading: true));
    try {
      final res = await api.get('/finance/accounts/tree');
      final list = (res.data['accounts'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      emit(_CoaState(accounts: list));
    } catch (e) {
      emit(_CoaState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class ChartOfAccountsScreen extends StatelessWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _CoaCubit()..load(),
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
        title: Text(l.t('coa.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_CoaCubit, _CoaState>(
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
                    onPressed: () => context.read<_CoaCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }
          if (state.accounts.isEmpty) {
            return Center(
              child: Text(l.t('common.noRecords'),
                  style: TextStyle(color: AppColors.textTertiary)),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<_CoaCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Summary cards by type
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(l.t('coa.subtitle'),
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ),
                ...state.accounts
                    .map((root) => _AccountGroupTile(
                          account: root,
                          isMr: isMr,
                          level: 0,
                        )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext ctx) {
    final l = AppLocalizations.of(ctx);
    final cubit = ctx.read<_CoaCubit>();
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final nameMrCtl = TextEditingController();
    String selectedType = 'ASSET';
    bool isGroup = false;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.t('coa.addAccount')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtl,
                  decoration: InputDecoration(
                    labelText: l.t('coa.code'),
                    hintText: 'e.g. 1601',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(
                    labelText: l.t('coa.accountName'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameMrCtl,
                  decoration: InputDecoration(
                    labelText: l.t('coa.accountNameMr'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: l.t('coa.accountType'),
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ASSET', child: Text('Asset')),
                    DropdownMenuItem(
                        value: 'LIABILITY', child: Text('Liability')),
                    DropdownMenuItem(value: 'INCOME', child: Text('Income')),
                    DropdownMenuItem(value: 'EXPENSE', child: Text('Expense')),
                    DropdownMenuItem(value: 'FUND', child: Text('Fund')),
                  ],
                  onChanged: (v) => setState(() => selectedType = v!),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isGroup,
                  onChanged: (v) => setState(() => isGroup = v!),
                  title: Text(l.t('coa.isGroup')),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
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
                if (codeCtl.text.isEmpty || nameCtl.text.isEmpty) return;
                try {
                  await api.post('/finance/accounts', data: {
                    'code': codeCtl.text.trim(),
                    'name': nameCtl.text.trim(),
                    'nameMr': nameMrCtl.text.trim(),
                    'type': selectedType,
                    'isGroup': isGroup,
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

// ═══════════════════════════════════════════════════════════════
// Account Group Tile (recursive tree)
// ═══════════════════════════════════════════════════════════════
class _AccountGroupTile extends StatelessWidget {
  final Map<String, dynamic> account;
  final bool isMr;
  final int level;
  const _AccountGroupTile(
      {required this.account, required this.isMr, required this.level});

  @override
  Widget build(BuildContext context) {
    final name = isMr && (account['nameMr'] ?? '').isNotEmpty
        ? account['nameMr']
        : account['name'];
    final code = account['code'] ?? '';
    final type = account['type'] ?? '';
    final isGroup = account['isGroup'] == true;
    final children = (account['children'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final isSystem = account['isSystem'] == true;

    final color = _typeColor(type);

    if (level == 0) {
      // Top-level group — show as a section header
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon(type), color: color, size: 20),
                const SizedBox(width: 8),
                Text(code,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
                _TypeBadge(type: type, color: color),
              ],
            ),
          ),
          if (children.isNotEmpty)
            ...children.map((child) =>
                _AccountGroupTile(account: child, isMr: isMr, level: 1)),
        ],
      );
    }

    // Sub-group or leaf
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.0 + level * 20, 2, 16, 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isGroup ? color.withAlpha(8) : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: isGroup
                  ? Border.all(color: color.withAlpha(30))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  alignment: Alignment.centerLeft,
                  child: Text(code,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                          fontFamily: 'monospace')),
                ),
                if (isGroup)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.folder_outlined,
                        size: 14, color: color.withAlpha(150)),
                  ),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isGroup ? FontWeight.w600 : FontWeight.w400,
                          color: AppColors.textPrimary)),
                ),
                if (isSystem)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.lock_outline,
                        size: 12, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
        ),
        if (children.isNotEmpty)
          ...children.map((child) =>
              _AccountGroupTile(account: child, isMr: isMr, level: level + 1)),
      ],
    );
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'ASSET':
        return Colors.blue;
      case 'LIABILITY':
        return Colors.red;
      case 'INCOME':
        return Colors.green;
      case 'EXPENSE':
        return Colors.orange;
      case 'FUND':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'ASSET':
        return Icons.account_balance_wallet;
      case 'LIABILITY':
        return Icons.credit_card;
      case 'INCOME':
        return Icons.trending_up;
      case 'EXPENSE':
        return Icons.trending_down;
      case 'FUND':
        return Icons.savings;
      default:
        return Icons.folder;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final Color color;
  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(type,
          style:
              TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
