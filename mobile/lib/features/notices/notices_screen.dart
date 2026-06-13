import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/date_format.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ListCubit(endpoint: '/notices', listKey: 'notices')..load(),
      child: const _NoticesView(),
    );
  }
}

class _NoticesView extends StatefulWidget {
  const _NoticesView();
  @override
  State<_NoticesView> createState() => _NoticesViewState();
}

class _NoticesViewState extends State<_NoticesView> {
  int _filterIndex = 0;
  static const _filterLabels = ['common.all', 'notices.important', 'notices.general', 'notices.maintenance'];
  static const _categories = ['', 'EMERGENCY', 'GENERAL', 'MAINTENANCE'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ListCubit>().load(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('notices.title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(l.t('notices.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: FilterChipsRow(
                    labels: _filterLabels.map((k) => l.t(k)).toList(),
                    selectedIndex: _filterIndex,
                    onSelected: (i) {
                      setState(() => _filterIndex = i);
                      final cat = _categories[i];
                      context.read<ListCubit>().load(cat.isEmpty ? null : {'category': cat});
                    },
                  ),
                ),
              ),
              BlocBuilder<ListCubit, ListData>(
                builder: (context, state) {
                  if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
                  if (state.items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(padding: const EdgeInsets.all(40),
                          child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final notice = state.items[i];
                        return GestureDetector(
                          onTap: () => context.push('/notices/${notice["id"]}'),
                          child: _NoticeCard(notice: notice, isMr: isMr),
                        );
                      },
                      childCount: state.items.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context),
              child: const Icon(Icons.add_rounded, size: 28))
          : null,
    );
  }

  void _showCreateSheet(BuildContext parentContext) {
    final cubit = parentContext.read<ListCubit>();
    final l = AppLocalizations.of(parentContext);
    String title = '', body = '', category = 'GENERAL';
    PlatformFile? pickedFile;

    showModalBottomSheet(
      context: parentContext, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Text(l.t('notices.newNotice'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('grievances.subject'))),
            const SizedBox(height: 14),
            TextField(onChanged: (v) => body = v, maxLines: 4, decoration: InputDecoration(labelText: l.t('notices.noticeBody'))),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(value: category, dropdownColor: AppColors.surface,
              items: ['GENERAL', 'MAINTENANCE', 'AGM', 'EMERGENCY', 'FESTIVAL'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => category = v!),
            const SizedBox(height: 14),
            // Attachment picker
            GestureDetector(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'],
                );
                if (result != null && result.files.isNotEmpty) {
                  setSheetState(() => pickedFile = result.files.first);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    pickedFile != null ? pickedFile!.name : l.t('notices.attachFile'),
                    style: TextStyle(fontSize: 13, color: pickedFile != null ? AppColors.textPrimary : AppColors.textTertiary),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                  if (pickedFile != null)
                    GestureDetector(
                      onTap: () => setSheetState(() => pickedFile = null),
                      child: Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(label: l.t('common.submit'), onPressed: () async {
              if (title.isEmpty || body.isEmpty) return;
              try {
                if (pickedFile != null && pickedFile!.path != null) {
                  final formData = FormData.fromMap({
                    'title': title, 'body': body, 'category': category,
                    'file': await MultipartFile.fromFile(pickedFile!.path!, filename: pickedFile!.name),
                  });
                  await api.postMultipart('/notices/with-attachment', data: formData);
                } else {
                  await api.post('/notices', data: {'title': title, 'body': body, 'category': category});
                }
                if (context.mounted) Navigator.pop(context); cubit.load();
              } catch (_) {}
            }),
          ])),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Map<String, dynamic> notice;
  final bool isMr;
  const _NoticeCard({required this.notice, required this.isMr});

  @override
  Widget build(BuildContext context) {
    final title = (isMr ? notice['titleMr'] : null) ?? notice['title'] ?? '';
    final body = (isMr ? notice['bodyMr'] : null) ?? notice['body'] ?? '';
    final cat = notice['category'] ?? 'GENERAL';
    final isPinned = notice['isPinned'] == true;
    final date = notice['createdAt'] ?? '';
    final isImportant = cat == 'EMERGENCY' || cat == 'AGM' || isPinned;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImportant ? null : AppColors.surface,
        gradient: isImportant ? LinearGradient(colors: [AppColors.primary.withAlpha(15), AppColors.secondary.withAlpha(15)]) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isImportant ? AppColors.primary.withAlpha(50) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: cat, color: isImportant ? AppColors.urgent : AppColors.secondary),
          const Spacer(),
          Text(_fmtDate(date), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ]),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (body.isNotEmpty) ...[const SizedBox(height: 4),
          Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))],
        const SizedBox(height: 8),
        Row(children: [
          if ((notice['attachmentName'] ?? '').toString().isNotEmpty) ...[
            Icon(Icons.attach_file_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(notice['attachmentName'], style: TextStyle(fontSize: 11, color: AppColors.primary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const Spacer(),
          Text(AppLocalizations.of(context).t('notices.tapToRead'), style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
        ]),
      ]),
    );
  }

  String _fmtDate(String iso) => formatTimeAgo(iso);
}
