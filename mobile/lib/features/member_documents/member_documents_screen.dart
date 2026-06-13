import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ── Document type metadata ──────────────────────────────────────────────────

class _DocTypeInfo {
  final String value;
  final String labelEn;
  final String labelMr;
  final IconData icon;
  final Color color;
  const _DocTypeInfo(this.value, this.labelEn, this.labelMr, this.icon, this.color);
}

const _docTypes = [
  _DocTypeInfo('AADHAAR', 'Aadhaar Card', 'आधार कार्ड', Icons.fingerprint_rounded, Color(0xFF3B82F6)),
  _DocTypeInfo('PAN_CARD', 'PAN Card', 'पॅन कार्ड', Icons.credit_card_rounded, Color(0xFFF59E0B)),
  _DocTypeInfo('SHARE_CERTIFICATE', 'Share Certificate', 'शेअर प्रमाणपत्र', Icons.verified_rounded, Color(0xFF10B981)),
  _DocTypeInfo('HOUSE_REGISTRATION', 'House Registration', 'घर नोंदणी', Icons.home_rounded, Color(0xFFA855F7)),
  _DocTypeInfo('PASSPORT', 'Passport', 'पासपोर्ट', Icons.flight_rounded, Color(0xFF06B6D4)),
  _DocTypeInfo('VOTER_ID', 'Voter ID', 'मतदार ओळखपत्र', Icons.how_to_vote_rounded, Color(0xFFEF4444)),
  _DocTypeInfo('DRIVING_LICENSE', 'Driving License', 'वाहन परवाना', Icons.directions_car_rounded, Color(0xFFF97316)),
  _DocTypeInfo('OTHER', 'Other', 'इतर', Icons.description_rounded, Color(0xFF64748B)),
];

_DocTypeInfo _infoFor(String type) {
  return _docTypes.firstWhere((d) => d.value == type, orElse: () => _docTypes.last);
}

// ── Screen ──────────────────────────────────────────────────────────────────

class MemberDocumentsScreen extends StatefulWidget {
  const MemberDocumentsScreen({super.key});
  @override
  State<MemberDocumentsScreen> createState() => _MemberDocumentsScreenState();
}

class _MemberDocumentsScreenState extends State<MemberDocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  String? _error;
  int _filterIndex = 0;

  static const _filterValues = ['', 'AADHAAR', 'PAN_CARD', 'SHARE_CERTIFICATE', 'HOUSE_REGISTRATION', 'OTHER'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? docType]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = docType != null && docType.isNotEmpty ? {'docType': docType} : null;
      final res = await api.get('/member-documents', queryParams: params);
      final list = (res.data['memberDocuments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() { _docs = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _uploadDocument() async {
    final isMr = context.read<LocaleCubit>().isMarathi;
    final l = AppLocalizations.of(context);

    // Pick document type first
    final selectedType = await showModalBottomSheet<_DocTypeInfo>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('memberDocs.selectType'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _docTypes.map((dt) => GestureDetector(
                onTap: () => Navigator.pop(ctx, dt),
                child: Container(
                  width: (MediaQuery.of(ctx).size.width - 70) / 2,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: dt.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dt.color.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Icon(dt.icon, size: 20, color: dt.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(isMr ? dt.labelMr : dt.labelEn,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (selectedType == null || !mounted) return;

    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    // 10 MB limit check
    if ((pickedFile.size) > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('memberDocs.fileTooLarge'))),
        );
      }
      return;
    }

    // Upload
    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(pickedFile.path!, filename: pickedFile.name),
        'docType': selectedType.value,
        'title': isMr ? selectedType.labelMr : selectedType.labelEn,
        'titleMr': selectedType.labelMr,
      });
      await api.postMultipart('/member-documents/upload', data: formData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('memberDocs.uploadSuccess'))),
        );
      }
      _load(_filterValues[_filterIndex]);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.t("common.error")}: $e')),
        );
      }
    }
  }

  Future<void> _downloadAndOpen(Map<String, dynamic> doc) async {
    final l = AppLocalizations.of(context);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('memberDocs.downloading'))),
      );
      final res = await api.getBytes('/member-documents/${doc["id"]}/download');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${doc["fileName"]}');
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

  Future<void> _deleteDocument(String id) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.t('memberDocs.deleteConfirm'),
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.t('common.delete'),
                  style: const TextStyle(color: AppColors.urgent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await api.delete('/member-documents/$id');
      _load(_filterValues[_filterIndex]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.t("common.error")}: $e')),
        );
      }
    }
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

    final filterLabelsEn = ['All', 'Aadhaar', 'PAN', 'Share Cert', 'House Reg', 'Other'];
    final filterLabelsMr = ['सर्व', 'आधार', 'पॅन', 'शेअर प्रमाणपत्र', 'घर नोंदणी', 'इतर'];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(_filterValues[_filterIndex]),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('memberDocs.title'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(l.t('memberDocs.subtitle'),
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: FilterChipsRow(
                    labels: isMr ? filterLabelsMr : filterLabelsEn,
                    selectedIndex: _filterIndex,
                    onSelected: (i) {
                      setState(() => _filterIndex = i);
                      _load(_filterValues[i]);
                    },
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(child: ShimmerLoading()),
              if (!_loading && _error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text(_error!,
                        style: TextStyle(color: AppColors.urgent))),
                  ),
                ),
              if (!_loading && _error == null && _docs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open_rounded, size: 56, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(l.t('memberDocs.noDocuments'),
                            style: TextStyle(color: AppColors.textTertiary)),
                        const SizedBox(height: 8),
                        Text(l.t('memberDocs.tapToUpload'),
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                ),
              if (!_loading && _error == null && _docs.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildDocCard(_docs[i], isMr, l),
                    childCount: _docs.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadDocument,
        child: const Icon(Icons.upload_file_rounded, size: 28),
      ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc, bool isMr, AppLocalizations l) {
    final info = _infoFor(doc['docType'] ?? 'OTHER');
    final title = isMr && (doc['titleMr'] ?? '').isNotEmpty
        ? doc['titleMr'] : doc['title'] ?? '';
    final fileName = doc['fileName'] ?? '';
    final originalSize = _formatSize(doc['originalSize']);
    final compressedSize = _formatSize(doc['compressedSize']);

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: info.color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, size: 24, color: info.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(fileName,
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$originalSize → $compressedSize',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
            onPressed: () => _downloadAndOpen(doc),
            tooltip: l.t('memberDocs.download'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.urgent),
            onPressed: () => _deleteDocument(doc['id']),
            tooltip: l.t('common.delete'),
          ),
        ],
      ),
    );
  }
}
