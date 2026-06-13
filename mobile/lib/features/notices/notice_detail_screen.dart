import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/date_format.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';

class NoticeDetailScreen extends StatefulWidget {
  final String id;
  const NoticeDetailScreen({super.key, required this.id});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  Map<String, dynamic>? _notice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await api.get('/notices/${widget.id}');
      setState(() { _notice = res.data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _hasAttachment =>
      _notice != null &&
      (_notice!['attachmentName'] ?? '').toString().isNotEmpty;

  bool get _isImageAttachment {
    final mime = (_notice?['attachmentMime'] ?? '').toString().toLowerCase();
    return mime.startsWith('image/');
  }

  Future<void> _openAttachment() async {
    final l = AppLocalizations.of(context);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('memberDocs.downloading'))),
      );
      final res = await api.getBytes('/notices/${widget.id}/attachment');
      final dir = await getTemporaryDirectory();
      final fileName = _notice!['attachmentName'] ?? 'attachment';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(res.data!);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.t("common.error")}: $e')),
        );
      }
    }
  }

  Widget _buildImageAttachment() {
    // Load attachment bytes and display as image
    return FutureBuilder(
      future: api.getBytes('/notices/${widget.id}/attachment'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data?.data == null) {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: _openAttachment,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              Uint8List.fromList(snapshot.data!.data!),
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileAttachment() {
    final name = _notice!['attachmentName'] ?? 'attachment';
    final size = _notice!['attachmentSize'];
    final sizeStr = _formatSize(size);
    final mime = (_notice?['attachmentMime'] ?? '').toString().toLowerCase();
    final isPdf = mime.contains('pdf');

    return GestureDetector(
      onTap: _openAttachment,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(sizeStr,
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '';
    final b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const ShimmerLoading()
            : _error != null
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: AppColors.urgent)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: Text(l.t('common.retry'))),
                    ],
                  ))
                : CustomScrollView(
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l.t('notices.detail'),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Notice content
                      if (_notice != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category badge + date
                                Row(
                                  children: [
                                    StatusBadge(
                                      label: _notice!['category'] ?? 'GENERAL',
                                      color: _isImportant ? AppColors.urgent : AppColors.secondary,
                                    ),
                                    if (_notice!['isPinned'] == true) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.push_pin_rounded, size: 14, color: AppColors.primary),
                                    ],
                                    const Spacer(),
                                    Text(
                                      formatTimeAgo(_notice!['createdAt'] ?? ''),
                                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Title
                                Text(
                                  _title(isMr),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
                                ),
                                const SizedBox(height: 6),

                                // Published by
                                if (_notice!['createdBy'] != null)
                                  Text(
                                    '${l.t("notices.publishedBy")}: ${_notice!['createdBy']['name'] ?? ''}',
                                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                  ),

                                const Divider(height: 32),

                                // Attachment (image inline, others as file card)
                                if (_hasAttachment) ...[
                                  if (_isImageAttachment)
                                    _buildImageAttachment()
                                  else
                                    _buildFileAttachment(),
                                  const SizedBox(height: 20),
                                ],

                                // Full body text
                                SelectableText(
                                  _body(isMr),
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.7,
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // Full date
                                _metaRow(Icons.calendar_today_rounded, l.t('grievances.created'),
                                    _fullDate(_notice!['createdAt'] ?? '')),
                                if (_notice!['expiresAt'] != null)
                                  _metaRow(Icons.timer_off_rounded, l.t('notices.expiresOn'),
                                      _fullDate(_notice!['expiresAt'] ?? '')),
                              ],
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 60)),
                    ],
                  ),
      ),
    );
  }

  bool get _isImportant {
    final cat = _notice?['category'] ?? '';
    return cat == 'EMERGENCY' || cat == 'AGM' || _notice?['isPinned'] == true;
  }

  String _title(bool isMr) {
    if (isMr && (_notice?['titleMr'] ?? '').toString().isNotEmpty) {
      return _notice!['titleMr'].toString();
    }
    return (_notice?['title'] ?? '').toString();
  }

  String _body(bool isMr) {
    if (isMr && (_notice?['bodyMr'] ?? '').toString().isNotEmpty) {
      return _notice!['bodyMr'].toString();
    }
    return (_notice?['body'] ?? '').toString();
  }

  String _fullDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _metaRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
