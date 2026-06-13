import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';

class GrievanceDetailScreen extends StatefulWidget {
  final String id;
  const GrievanceDetailScreen({super.key, required this.id});

  @override
  State<GrievanceDetailScreen> createState() => _GrievanceDetailScreenState();
}

class _GrievanceDetailScreenState extends State<GrievanceDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await api.get('/grievances/${widget.id}');
      setState(() {
        _data = res.data is Map<String, dynamic> ? res.data : null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await api.patch('/grievances/${widget.id}/status', data: {'status': status});
      _load();
    } catch (_) {}
  }

  Future<void> _addComment() async {
    if (_commentCtrl.text.isEmpty) return;
    try {
      await api.post('/grievances/${widget.id}/comments',
          data: {'comment': _commentCtrl.text});
      _commentCtrl.clear();
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const ShimmerLoading()
            : _data == null
                ? Center(child: Text(l.t('common.error')))
                : _buildContent(l, isMr, isAdmin),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l, bool isMr, bool isAdmin) {
    final g = _data!;
    final title = (isMr ? g['titleMr'] : null) ?? g['title'] ?? '';
    final desc = (isMr ? g['descriptionMr'] : null) ?? g['description'] ?? '';
    final priority = g['priority'] ?? 'MEDIUM';
    final status = g['status'] ?? 'OPEN';
    final ticket = g['ticketNo'] ?? '';
    final category = g['category'] ?? '';
    final date = g['createdAt'] ?? '';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ticket, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(l.t('grievances.detail'),
                            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Badges
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusBadge.priority(priority),
                    StatusBadge.status(status),
                    StatusBadge(label: category, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Title + Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Raised by info
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _initials(g['raisedBy']?['name'] ?? ''),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g['raisedBy']?['name'] ?? '',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            '${l.t('grievances.raisedBy')} • ${_formatDate(date)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(indent: 16, endIndent: 16),

              // Status timeline
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('grievances.statusTimeline'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    _timelineStep(l.t('grievances.created'), _formatDate(date), true),
                    if (status == 'IN_PROGRESS' || status == 'RESOLVED' || status == 'CLOSED')
                      _timelineStep(l.t('grievances.inProgress'), '', true),
                    if (status == 'RESOLVED' || status == 'CLOSED')
                      _timelineStep(l.t('grievances.resolved'), '', true),
                    if (status != 'RESOLVED' && status != 'CLOSED')
                      _timelineStep(l.t('grievances.awaitingAction'), '', false, isLast: true),
                  ],
                ),
              ),

              // Admin actions
              if (isAdmin && status != 'RESOLVED' && status != 'CLOSED') ...[
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('grievances.adminActions'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionBtn(
                              l.t('grievances.markInProgress'),
                              AppColors.secondary,
                              () => _updateStatus('IN_PROGRESS'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionBtn(
                              l.t('grievances.markResolved'),
                              AppColors.resolved,
                              () => _updateStatus('RESOLVED'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Comment input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: l.t('grievances.addComment'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _addComment,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineStep(String title, String sub, bool completed, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? AppColors.open : AppColors.borderLight,
                border: completed ? null : Border.all(color: AppColors.borderLight, width: 2),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 30, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: completed ? FontWeight.w600 : FontWeight.w500,
                  color: completed ? AppColors.textPrimary : AppColors.textTertiary,
                )),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
