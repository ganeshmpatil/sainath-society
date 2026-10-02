import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_config.dart';
import '../i18n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../i18n/locale_cubit.dart';
import '../theme/app_colors.dart';

class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

  static const _currentVersion = '1.0.1';

  bool _checking = false;

  /// Call once after login / dashboard mount.
  Future<void> checkForUpdate(BuildContext context) async {
    if (_checking) return;
    _checking = true;

    try {
      final resp = await Dio().get('${ApiConfig.baseUrl}/version');
      final data = resp.data as Map<String, dynamic>;
      final latest = data['latestVersion'] as String? ?? _currentVersion;
      final downloadUrl = data['downloadUrl'] as String? ?? '';

      if (_isNewer(latest, _currentVersion) && context.mounted) {
        final isMr = context.read<LocaleCubit>().isMarathi;
        final notes = (isMr ? data['releaseNotesMr'] : null) ?? data['releaseNotes'] ?? '';
        _showUpdateDialog(context, latest, downloadUrl, notes);
      }
    } catch (_) {
      // Silently ignore — don't block the user
    } finally {
      _checking = false;
    }
  }

  bool _isNewer(String remote, String local) {
    final r = remote.split('.').map(int.tryParse).toList();
    final l = local.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final rv = (i < r.length ? r[i] : 0) ?? 0;
      final lv = (i < l.length ? l[i] : 0) ?? 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url, String notes) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(
        version: version,
        url: url,
        notes: notes,
        updateLabel: l.t('update.updateAvailable'),
        newVersionLabel: l.t('update.newVersion'),
        downloadLabel: l.t('update.download'),
        laterLabel: l.t('update.later'),
        downloadingLabel: l.t('update.downloading'),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version, url, notes;
  final String updateLabel, newVersionLabel, downloadLabel, laterLabel, downloadingLabel;

  const _UpdateDialog({
    required this.version,
    required this.url,
    required this.notes,
    required this.updateLabel,
    required this.newVersionLabel,
    required this.downloadLabel,
    required this.laterLabel,
    required this.downloadingLabel,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    _cancelToken = CancelToken();

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/aangan-update.apk';

      await Dio().download(
        widget.url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
      }
    } catch (e) {
      if (mounted && !_cancelToken!.isCancelled) {
        setState(() { _downloading = false; _progress = 0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.updateLabel, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.newVersionLabel}: ${widget.version}',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          if (widget.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.notes, style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ],
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress, color: AppColors.primary),
            const SizedBox(height: 6),
            Text('${widget.downloadingLabel} ${(_progress * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ],
        ],
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(widget.laterLabel, style: TextStyle(color: AppColors.textTertiary)),
              ),
              FilledButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(widget.downloadLabel),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
    );
  }
}
