import 'package:flutter/widgets.dart';

/// 轻量本地化实现（中英文）。
///
/// 当前项目未使用 ARB 代码生成，改为手写映射以减少首版复杂度。
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations!;
  }

  /// 当前是否为中文环境。
  bool get _isZh => locale.languageCode == 'zh';

  String get appTitle => 'NodeJot';
  String get tabNotes => _isZh ? '笔记' : 'Notes';
  String get tabDevices => _isZh ? '设备' : 'Devices';
  String get tabSettings => _isZh ? '设置' : 'Settings';
  String get conflicts => _isZh ? '冲突' : 'Conflicts';
  String get noConflictNotes => _isZh ? '暂无冲突笔记。' : 'No conflict notes.';
  String updatedAtLabel(String value) =>
      _isZh ? '更新于 $value' : 'Updated $value';
  String get noNotesYet => _isZh ? '还没有笔记' : 'No notes yet';
  String get createNote => _isZh ? '新建笔记' : 'Create Note';
  String get noteConflictTag => _isZh ? '冲突' : 'Conflict';
  String get newNote => _isZh ? '新建笔记' : 'New Note';
  String get editNote => _isZh ? '编辑笔记' : 'Edit Note';
  String get titleHint => _isZh ? '标题' : 'Title';
  String get markdownHint =>
      _isZh ? '输入笔记...' : 'Type your note...';
  String get saving => _isZh ? '保存中...' : 'Saving...';
  String get save => _isZh ? '保存' : 'Save';
  String get saved => _isZh ? '已保存' : 'Saved';
  String charCountLabel(int count) => _isZh ? '字数 $count' : 'Chars $count';
  String get delete => _isZh ? '删除' : 'Delete';
  String get deleteNoteTitle => _isZh ? '删除笔记' : 'Delete Note';
  String get deleteNoteConfirmMessage =>
      _isZh ? '确定删除这条笔记吗？此操作无法撤销。' : 'Delete this note? This action cannot be undone.';
  String get conflictCopyCreated =>
      _isZh
          ? '检测到冲突，已创建冲突副本。'
          : 'Detected conflict. A conflict copy was created.';
  String saveFailedWithReason(String reason) =>
      _isZh ? '保存失败: $reason' : 'Save failed: $reason';
  String deleteFailedWithReason(String reason) =>
      _isZh ? '删除失败: $reason' : 'Delete failed: $reason';
  String get devices => _isZh ? '设备' : 'Devices';
  String pairingCodeDisplay(String code) =>
      _isZh ? '配对码: $code' : 'Pairing Code: $code';
  String get pairingCodeHint =>
      _isZh ? '在另一台设备输入该配对码完成配对' : 'Use this code on another device to pair';
  String get refresh => _isZh ? '刷新' : 'Refresh';
  String get pairedDevices => _isZh ? '已配对设备' : 'Paired Devices';
  String get noPairedDevicesYet =>
      _isZh ? '还没有已配对设备。' : 'No paired devices yet.';
  String get discovered => _isZh ? '已发现' : 'Discovered';
  String get noDevicesFound =>
      _isZh ? '局域网内未发现设备。' : 'No devices found on LAN.';
  String get directPair => _isZh ? '直连配对' : 'Direct Pair';
  String get directPairTitle => _isZh ? '直连配对（IP）' : 'Direct Pair (IP)';
  String get hostIpLabel => _isZh ? '主机 IP' : 'Host IP';
  String get hostIpHint => _isZh ? '例如 192.168.1.23' : 'e.g. 192.168.1.23';
  String get portLabel => _isZh ? '端口' : 'Port';
  String get pairingCodeInputLabel => _isZh ? '配对码' : 'Pairing Code';
  String get cancel => _isZh ? '取消' : 'Cancel';
  String get pair => _isZh ? '配对' : 'Pair';
  String get hostAndCodeRequired =>
      _isZh ? '主机地址和配对码不能为空' : 'Host and pairing code are required';
  String get directPairSuccess => _isZh ? '直连配对成功' : 'Direct pairing success';
  String directPairFailedWithReason(String reason) =>
      _isZh ? '直连配对失败: $reason' : 'Direct pairing failed: $reason';
  String get discoveryRefreshed => _isZh ? '已刷新发现列表' : 'Discovery refreshed';
  String get pairWithDevice => _isZh ? '与设备配对' : 'Pair with device';
  String pairWithNamedDevice(String name) =>
      _isZh ? '与$name配对' : 'Pair with $name';
  String get fourDigitCodeHint => _isZh ? '4 位配对码' : '4-digit code';
  String get pairCodeInvalid => _isZh ? '配对码错误' : 'Invalid pairing code';
  String get pairingSuccess => _isZh ? '配对成功' : 'Pairing success';
  String pairingFailedWithReason(String reason) =>
      _isZh ? '配对失败: $reason' : 'Pairing failed: $reason';
  String get sync => _isZh ? '同步' : 'Sync';
  String get syncDone => _isZh ? '同步完成' : 'Sync done';
  String syncFailedWithReason(String reason) =>
      _isZh ? '同步失败: $reason' : 'Sync failed: $reason';
  String get settings => _isZh ? '设置' : 'Settings';
  String get themeMode => _isZh ? '主题模式' : 'Theme Mode';
  String get themeSystem => _isZh ? '跟随系统' : 'System';
  String get themeLight => _isZh ? '亮色' : 'Light';
  String get themeDark => _isZh ? '暗色' : 'Dark';
  String get pairedDeviceSettings => _isZh ? '设备配置' : 'Device Settings';
  String get deviceRemark => _isZh ? '备注' : 'Remark';
  String get deviceRemarkHint => _isZh ? '输入设备备注' : 'Enter device remark';
  String get deviceInfo => _isZh ? '设备信息' : 'Device Info';
  String get deleteDevice => _isZh ? '删除此设备' : 'Delete Device';
  String get deleting => _isZh ? '删除中...' : 'Deleting...';
  String get deleteDeviceConfirm =>
      _isZh ? '确定删除该设备吗？删除后需要重新配对。' : 'Delete this device? Pairing will be required again.';
  String get deviceDeleted => _isZh ? '设备已删除' : 'Device deleted';
  String get connectionAndSync => _isZh ? '连接与同步' : 'Connection & Sync';
  String get oneTimeConnection => _isZh ? '一次性连接' : 'One-time Connection';
  String get oneTimeConnectionHint =>
      _isZh ? '关闭应用后自动删除已配对设备' : 'Delete paired devices when app closes';
  String get autoSync => _isZh ? '自动同步' : 'Auto Sync';
  String get autoSyncHint =>
      _isZh ? '发现已配对设备后自动尝试同步' : 'Auto-sync when paired devices are discovered';
  String get deviceName => _isZh ? '设备名称' : 'Device Name';
  String get saveDeviceName => _isZh ? '保存设备名称' : 'Save Device Name';
  String get localProfile => _isZh ? '本机信息' : 'Local Profile';
  String deviceIdLabel(String id) => _isZh ? '设备 ID: $id' : 'Device ID: $id';
  String publicKeyLabel(String value) =>
      _isZh ? '公钥: $value' : 'Public Key: $value';
  String get localFirstDescription =>
      _isZh
          ? 'NodeJot 采用本地优先：无云上传、无账号、无服务端依赖。'
          : 'NodeJot is local-first: no cloud upload, no account, no server dependency.';
  String get saveDeviceNameDone => _isZh ? '保存成功' : 'Saved';
}

/// 本地化委托。
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'zh';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// BuildContext 快捷扩展。
extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
