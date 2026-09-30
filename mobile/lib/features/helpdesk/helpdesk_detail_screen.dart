import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';

// ── State & Cubit ─────────────────────────────────────────────

class _St {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? ticket;
  final List<Map<String, dynamic>> messages;
  const _St({this.loading = false, this.error, this.ticket, this.messages = const []});
}

class _Cu extends Cubit<_St> {
  final String id;
  _Cu(this.id) : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/helpdesk/$id');
      final data = res.data as Map<String, dynamic>;
      final msgs = (data['messages'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(ticket: data, messages: msgs));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }

  Future<void> sendMessage(String body, {bool isInternal = false}) async {
    try {
      await api.post('/helpdesk/$id/messages', data: {'body': body, 'isInternal': isInternal});
      load();
    } catch (e) {
      emit(_St(ticket: state.ticket, messages: state.messages, error: e.toString()));
    }
  }

  Future<void> updateStatus(String status) async {
    try {
      await api.patch('/helpdesk/$id/status', data: {'status': status});
      load();
    } catch (e) {
      emit(_St(ticket: state.ticket, messages: state.messages, error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class HelpdeskDetailScreen extends StatelessWidget {
  final String id;
  const HelpdeskDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _Cu(id)..load(),
    child: const _View(),
  );
}

class _View extends StatefulWidget {
  const _View();
  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _msgCtrl = TextEditingController();
  bool _isInternal = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'OPEN': return const Color(0xFFF97316);
      case 'IN_PROGRESS': return const Color(0xFF3B82F6);
      case 'RESOLVED': return const Color(0xFF10B981);
      case 'CLOSED': return const Color(0xFF64748B);
      default: return const Color(0xFF64748B);
    }
  }

  String _statusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'OPEN': return l.t('helpdesk.open');
      case 'IN_PROGRESS': return l.t('helpdesk.inProgress');
      case 'RESOLVED': return l.t('helpdesk.resolved');
      case 'CLOSED': return l.t('helpdesk.closed');
      default: return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return BlocBuilder<_Cu, _St>(
      builder: (context, state) {
        final t = state.ticket;
        final status = t?['status'] as String?;
        final sColor = _statusColor(status);
        final isClosed = status == 'CLOSED';

        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t?['ticketNo'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontFamily: 'monospace')),
                    Text(t?['subject'] ?? l.t('helpdesk.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                    child: Text(_statusLabel(l, status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
                  ),
                ]),
              ),

              // Ticket info
              if (t != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (t['description'] != null && t['description'].toString().isNotEmpty)
                        Text(t['description'], style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, children: [
                        _InfoChip('${t['flatNo']}', Icons.home_rounded),
                        _InfoChip('${t['category']}', Icons.category_rounded),
                        _InfoChip('${t['priority']}', Icons.flag_rounded),
                      ]),
                      // Admin status actions
                      if (isAdmin && !isClosed) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          if (status == 'OPEN')
                            _SmallAction(l.t('helpdesk.markInProgress'), const Color(0xFF3B82F6), () => context.read<_Cu>().updateStatus('IN_PROGRESS')),
                          if (status == 'IN_PROGRESS')
                            _SmallAction(l.t('helpdesk.markResolved'), const Color(0xFF10B981), () => context.read<_Cu>().updateStatus('RESOLVED')),
                          if (status != 'CLOSED')
                            _SmallAction(l.t('helpdesk.close'), const Color(0xFF64748B), () => context.read<_Cu>().updateStatus('CLOSED')),
                        ]),
                      ],
                    ]),
                  ),
                ),

              // Messages
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null
                        ? Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
                              const SizedBox(height: 8),
                              Text(state.error!, style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => context.read<_Cu>().load(),
                                child: Text(l.t('common.retry'), style: TextStyle(color: AppColors.primary)),
                              ),
                            ],
                          ))
                        : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: state.messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = state.messages[i];
                          final isMe = msg['senderId'] == (authState is Authenticated ? authState.user.id : '');
                          final isInternalNote = msg['isInternal'] == true;
                          final createdAt = DateTime.tryParse(msg['createdAt'] ?? '');

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isInternalNote
                                    ? const Color(0xFFFEF3C7)
                                    : isMe
                                        ? AppColors.primary.withAlpha(20)
                                        : AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isInternalNote ? const Color(0xFFF59E0B).withAlpha(60) : AppColors.border),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(
                                    msg['senderName'] ?? '',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isMe ? AppColors.primary : AppColors.textTertiary),
                                  ),
                                  if (msg['senderRole'] == 'ADMIN') ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Admin', style: TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                  if (isInternalNote) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.lock_rounded, size: 10, color: const Color(0xFFF59E0B)),
                                    Text(' Internal', style: TextStyle(fontSize: 8, color: const Color(0xFFF59E0B))),
                                  ],
                                ]),
                                const SizedBox(height: 4),
                                Text(msg['body'] ?? '', style: TextStyle(fontSize: 13, color: isInternalNote ? const Color(0xFF92400E) : AppColors.textPrimary)),
                                if (createdAt != null)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
                                    ),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),

              // Message input
              if (!isClosed)
                Container(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          GestureDetector(
                            onTap: () => setState(() => _isInternal = !_isInternal),
                            child: Row(children: [
                              Icon(
                                _isInternal ? Icons.lock_rounded : Icons.lock_open_rounded,
                                size: 14,
                                color: _isInternal ? const Color(0xFFF59E0B) : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isInternal ? l.t('helpdesk.internalNote') : l.t('helpdesk.publicReply'),
                                style: TextStyle(fontSize: 10, color: _isInternal ? const Color(0xFFF59E0B) : AppColors.textTertiary),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          decoration: InputDecoration(
                            hintText: l.t('helpdesk.typeMessage'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final text = _msgCtrl.text.trim();
                          if (text.isEmpty) return;
                          context.read<_Cu>().sendMessage(text, isInternal: _isInternal);
                          _msgCtrl.clear();
                        },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                    ]),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primary.withAlpha(10), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallAction(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(60))),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
