import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

class GrievanceDetailScreen extends StatefulWidget {
  final String id;
  const GrievanceDetailScreen({super.key, required this.id});

  @override
  State<GrievanceDetailScreen> createState() => _GrievanceDetailScreenState();
}

class _GrievanceDetailScreenState extends State<GrievanceDetailScreen> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  final _msgCtrl = TextEditingController();
  bool _isInternal = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await api.get('/grievances/${widget.id}');
      if (!mounted) return;
      final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
      final msgs = (data?['messages'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          (data?['comments'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
          [];
      setState(() {
        _data = data;
        _messages = msgs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await api.patch('/grievances/${widget.id}/status', data: {'status': status});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).t('common.error')}: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await api.post('/grievances/${widget.id}/comments',
          data: {'comment': text, 'isInternal': _isInternal});
      _msgCtrl.clear();
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).t('common.error')}: $e')),
        );
      }
    }
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
      case 'OPEN': return l.t('grievances.open');
      case 'IN_PROGRESS': return l.t('grievances.inProgress');
      case 'RESOLVED': return l.t('grievances.resolved');
      case 'CLOSED': return l.t('grievances.closed');
      default: return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;
    final currentUserId = authState is Authenticated ? authState.user.id : '';

    if (_loading) {
      return Scaffold(
        body: SafeArea(child: const ShimmerLoading()),
      );
    }

    if (_error != null || _data == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
                const SizedBox(height: 8),
                Text(_error ?? l.t('common.error'),
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _load,
                  child: Text(l.t('common.retry'),
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final g = _data!;
    final title = (isMr ? g['titleMr'] : null) ?? g['title'] ?? '';
    final desc = (isMr ? g['descriptionMr'] : null) ?? g['description'] ?? '';
    final priority = g['priority'] ?? 'MEDIUM';
    final status = g['status'] ?? 'OPEN';
    final ticket = g['ticketNo'] ?? '';
    final category = g['category'] ?? '';
    final type = g['type'] as String?;
    final sColor = _statusColor(status);
    final isClosed = status == 'CLOSED';

    String typeLabel(String? t) {
      if (t == 'MAINTENANCE_REQUEST') return l.t('grievances.typeMaintenanceRequest');
      return l.t('grievances.typeComplaint');
    }

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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ticket,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary, fontFamily: 'monospace',
                      )),
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusLabel(l, status),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
              ),
            ]),
          ),

          // Ticket info card
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
                if (desc.isNotEmpty)
                  Text(desc, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  _InfoChip(category, Icons.category_rounded),
                  _InfoChip(priority, Icons.flag_rounded),
                  if (type != null)
                    _InfoChip(typeLabel(type), Icons.label_rounded),
                  if (g['flatNo'] != null)
                    _InfoChip('${g['flatNo']}', Icons.home_rounded),
                ]),
                // Admin status actions
                if (isAdmin && !isClosed) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    if (status == 'OPEN')
                      _SmallAction(l.t('grievances.markInProgress'),
                          const Color(0xFF3B82F6), () => _updateStatus('IN_PROGRESS')),
                    if (status == 'IN_PROGRESS')
                      _SmallAction(l.t('grievances.markResolved'),
                          const Color(0xFF10B981), () => _updateStatus('RESOLVED')),
                    if (status != 'CLOSED')
                      _SmallAction(l.t('grievances.closeTicket'),
                          const Color(0xFF64748B), () => _updateStatus('CLOSED')),
                  ]),
                ],
              ]),
            ),
          ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(l.t('common.noRecords'),
                        style: TextStyle(color: AppColors.textTertiary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final senderId = msg['authorId'] ?? msg['senderId'] ?? '';
                      final isMe = senderId == currentUserId;
                      final isInternalNote = msg['isInternal'] == true;
                      final body = msg['comment'] ?? msg['body'] ?? '';
                      final senderName = msg['authorName'] ?? msg['senderName'] ?? '';
                      final senderRole = msg['authorRole'] ?? msg['senderRole'] ?? '';
                      final createdAt = DateTime.tryParse(msg['createdAt'] ?? '');

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(ctx).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isInternalNote
                                ? const Color(0xFFFEF3C7)
                                : isMe
                                    ? AppColors.primary.withAlpha(20)
                                    : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isInternalNote
                                  ? const Color(0xFFF59E0B).withAlpha(60)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(
                                    senderName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isMe ? AppColors.primary : AppColors.textTertiary,
                                    ),
                                  ),
                                  if (senderRole == 'ADMIN') ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Admin',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                  ],
                                  if (isInternalNote) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.lock_rounded,
                                        size: 10, color: const Color(0xFFF59E0B)),
                                    Text(' Internal',
                                        style: TextStyle(
                                            fontSize: 8,
                                            color: const Color(0xFFF59E0B))),
                                  ],
                                ]),
                                const SizedBox(height: 4),
                                Text(body,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isInternalNote
                                          ? const Color(0xFF92400E)
                                          : AppColors.textPrimary,
                                    )),
                                if (createdAt != null)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          fontSize: 9, color: AppColors.textTertiary),
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
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 24),
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
                            color: _isInternal
                                ? const Color(0xFFF59E0B)
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isInternal
                                ? l.t('grievances.internalNote')
                                : l.t('grievances.publicReply'),
                            style: TextStyle(
                              fontSize: 10,
                              color: _isInternal
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.textTertiary,
                            ),
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
                        hintText: l.t('grievances.typeMessage'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.send_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ),
                ]),
              ]),
            ),
        ]),
      ),
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
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(6),
      ),
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
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
