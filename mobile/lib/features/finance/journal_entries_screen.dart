import 'package:dio/dio.dart';
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
class _JeState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> entries;
  const _JeState({this.loading = false, this.error, this.entries = const []});
  @override
  List<Object?> get props => [loading, error, entries];
}

class _JeCubit extends Cubit<_JeState> {
  _JeCubit() : super(const _JeState());

  Future<void> load({String? from, String? to}) async {
    emit(const _JeState(loading: true));
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await api.get('/finance/journal', queryParams: params.isEmpty ? null : params);
      final list = (res.data['entries'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      emit(_JeState(entries: list));
    } catch (e) {
      emit(_JeState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class JournalEntriesScreen extends StatelessWidget {
  const JournalEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _JeCubit()..load(),
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
        title: Text(l.t('journal.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_JeCubit, _JeState>(
        builder: (context, state) {
          if (state.loading) return const ShimmerLoading();
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.t('common.error'), style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<_JeCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }
          if (state.entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(l.t('journal.noEntries'),
                      style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<_JeCubit>().load(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              itemCount: state.entries.length,
              itemBuilder: (ctx, i) => _JournalCard(entry: state.entries[i], isMr: isMr),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showCreateDialog(BuildContext ctx) {
    final cubit = ctx.read<_JeCubit>();
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => _CreateJournalScreen(onCreated: () => cubit.load()),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════
// Journal Card
// ═══════════════════════════════════════════════════════════════
class _JournalCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isMr;
  const _JournalCard({required this.entry, required this.isMr});

  @override
  Widget build(BuildContext context) {
    final narration = isMr && (entry['narrationMr'] ?? '').isNotEmpty
        ? entry['narrationMr']
        : entry['narration'] ?? '';
    final entryNo = entry['entryNo'] ?? '';
    final date = entry['entryDate'] ?? '';
    final amount = (entry['totalAmount'] ?? 0).toDouble();
    final isAuto = entry['isAutomatic'] == true;
    final refType = entry['refType'] ?? '';
    final lines = (entry['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isAuto ? Colors.blue.withAlpha(20) : Colors.green.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isAuto ? Icons.auto_mode : Icons.edit_note,
            size: 18,
            color: isAuto ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(narration,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Text(_formatDate(date),
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(width: 8),
            Text(entryNo,
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontFamily: 'monospace')),
            const Spacer(),
            Text('₹${amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
        children: [
          if (refType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(refType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          // Lines table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('Account', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary))),
                      Expanded(child: Text('Dr', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[700]), textAlign: TextAlign.right)),
                      Expanded(child: Text('Cr', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red[700]), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                ...lines.map((line) {
                  final account = line['accountHead'] as Map<String, dynamic>?;
                  final accountName = account != null
                      ? (isMr && (account['nameMr'] ?? '').isNotEmpty ? account['nameMr'] : account['name'])
                      : 'Unknown';
                  final dr = (line['debitAmount'] ?? 0).toDouble();
                  final cr = (line['creditAmount'] ?? 0).toDouble();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(accountName, style: TextStyle(fontSize: 11, color: AppColors.textPrimary))),
                        Expanded(child: Text(dr > 0 ? '₹${dr.toStringAsFixed(0)}' : '', style: TextStyle(fontSize: 11, color: Colors.green[700]), textAlign: TextAlign.right)),
                        Expanded(child: Text(cr > 0 ? '₹${cr.toStringAsFixed(0)}' : '', style: TextStyle(fontSize: 11, color: Colors.red[700]), textAlign: TextAlign.right)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Create Journal Entry Screen
// ═══════════════════════════════════════════════════════════════
class _CreateJournalScreen extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateJournalScreen({required this.onCreated});

  @override
  State<_CreateJournalScreen> createState() => _CreateJournalScreenState();
}

class _CreateJournalScreenState extends State<_CreateJournalScreen> {
  final _narrationCtl = TextEditingController();
  final _narrationMrCtl = TextEditingController();
  DateTime _entryDate = DateTime.now();
  List<Map<String, dynamic>> _accounts = [];
  bool _loadingAccounts = true;
  bool _saving = false;

  // Lines: each has accountHeadId, debitAmount, creditAmount
  final List<_LineData> _lines = [_LineData(), _LineData()];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final res = await api.get('/finance/accounts/leaf');
      _accounts = (res.data['accounts'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
    } catch (_) {}
    if (mounted) setState(() => _loadingAccounts = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('journal.create')),
        centerTitle: true,
      ),
      body: _loadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.t('journal.entryDate')),
                    subtitle: Text('${_entryDate.day}/${_entryDate.month}/${_entryDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _entryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _entryDate = date);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Narration
                  TextField(
                    controller: _narrationCtl,
                    decoration: InputDecoration(
                      labelText: l.t('journal.narration'),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _narrationMrCtl,
                    decoration: InputDecoration(
                      labelText: l.t('journal.narrationMr'),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  // Lines
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.t('journal.lines'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_LineData())),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l.t('journal.addLine')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_lines.length, (i) => _buildLineRow(i, isMr)),
                  const SizedBox(height: 16),
                  // Balance check
                  _buildBalanceRow(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.t('journal.save')),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLineRow(int index, bool isMr) {
    final line = _lines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.accountId,
                    decoration: InputDecoration(
                      labelText: 'Account',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    isExpanded: true,
                    items: _accounts.map((a) {
                      final name = isMr && (a['nameMr'] ?? '').isNotEmpty ? a['nameMr'] : a['name'];
                      return DropdownMenuItem(value: a['id'] as String, child: Text('${a['code']} - $name', style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (v) => setState(() => line.accountId = v),
                  ),
                ),
                if (_lines.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red[400]),
                    onPressed: () => setState(() => _lines.removeAt(index)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Debit (₹)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => line.debit = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Credit (₹)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => line.credit = double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow() {
    double totalDr = 0, totalCr = 0;
    for (final l in _lines) {
      totalDr += l.debit;
      totalCr += l.credit;
    }
    final balanced = (totalDr - totalCr).abs() < 0.01 && totalDr > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: balanced ? Colors.green.withAlpha(15) : Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: balanced ? Colors.green.withAlpha(50) : Colors.red.withAlpha(50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Debit: ₹${totalDr.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w600)),
              Text('Total Credit: ₹${totalCr.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w600)),
            ],
          ),
          Icon(
            balanced ? Icons.check_circle : Icons.warning,
            color: balanced ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_narrationCtl.text.isEmpty) return;
    double totalDr = 0, totalCr = 0;
    for (final l in _lines) {
      totalDr += l.debit;
      totalCr += l.credit;
    }
    if ((totalDr - totalCr).abs() > 0.01 || totalDr == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debits must equal credits')),
      );
      return;
    }
    for (final l in _lines) {
      if (l.accountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an account for each line')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await api.post('/finance/journal', data: {
        'entryDate': '${_entryDate.year}-${_entryDate.month.toString().padLeft(2, '0')}-${_entryDate.day.toString().padLeft(2, '0')}',
        'narration': _narrationCtl.text.trim(),
        'narrationMr': _narrationMrCtl.text.trim(),
        'lines': _lines.map((l) => {
          'accountHeadId': l.accountId,
          'debitAmount': l.debit,
          'creditAmount': l.credit,
        }).toList(),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['error'] ?? e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _narrationCtl.dispose();
    _narrationMrCtl.dispose();
    super.dispose();
  }
}

class _LineData {
  String? accountId;
  double debit = 0;
  double credit = 0;
}
