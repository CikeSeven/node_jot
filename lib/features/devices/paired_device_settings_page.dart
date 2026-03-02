import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/models/app_services.dart';
import '../../data/isar/collections/device_entity.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ios_group_section.dart';

/// 已配对设备配置页。
///
/// 支持修改设备备注与删除该设备。
class PairedDeviceSettingsPage extends ConsumerStatefulWidget {
  const PairedDeviceSettingsPage({super.key, required this.device});

  final DeviceEntity device;

  @override
  ConsumerState<PairedDeviceSettingsPage> createState() =>
      _PairedDeviceSettingsPageState();
}

class _PairedDeviceSettingsPageState
    extends ConsumerState<PairedDeviceSettingsPage> {
  late final TextEditingController _remarkController;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.device.displayName);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = ref.watch(appServicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairedDeviceSettings)),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.pageBackground(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              IosGroupSection(
                title: l10n.deviceRemark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _remarkController,
                      decoration: InputDecoration(hintText: l10n.deviceRemarkHint),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveRemark,
                        child: Text(_saving ? l10n.saving : l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
              IosGroupSection(
                title: l10n.deviceInfo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.deviceIdLabel(widget.device.deviceId)}\n${widget.device.host}:${widget.device.port}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IosGroupSection(
                title: l10n.connectionAndSync,
                child: Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          services.appSettingsService.oneTimeConnectionNotifier,
                      builder: (context, enabled, _) {
                        return SwitchListTile.adaptive(
                          value: enabled,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.oneTimeConnection),
                          subtitle: Text(l10n.oneTimeConnectionHint),
                          onChanged:
                              (value) => services.appSettingsService
                                  .setOneTimeConnection(value),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          services.appSettingsService.autoSyncNotifier,
                      builder: (context, enabled, _) {
                        return SwitchListTile.adaptive(
                          value: enabled,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.autoSync),
                          subtitle: Text(l10n.autoSyncHint),
                          onChanged:
                              (value) =>
                                  services.appSettingsService.setAutoSync(value),
                        );
                      },
                    ),
                  ],
                ),
              ),
              IosGroupSection(
                title: l10n.deleteDevice,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _confirmDelete,
                    icon: Icon(
                      CupertinoIcons.trash,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      _deleting ? l10n.deleting : l10n.deleteDevice,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRemark() async {
    final l10n = context.l10n;
    final remark = _remarkController.text.trim();
    if (remark.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final services = ref.read(appServicesProvider);
    try {
      await services.deviceRepository.updateTrustedDeviceRemark(
        deviceId: widget.device.deviceId,
        remark: remark,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.saved)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteDevice),
          content: Text(l10n.deleteDeviceConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _deleting = true);
    final services = ref.read(appServicesProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await services.deviceRepository.deleteDevice(widget.device.deviceId);
      if (!mounted) {
        return;
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.deviceDeleted)));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}
