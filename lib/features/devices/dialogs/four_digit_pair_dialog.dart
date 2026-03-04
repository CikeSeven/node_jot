import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';

/// 通用 4 位配对码弹窗。
///
/// 支持：
/// - 四格输入；
/// - 自动提交；
/// - 错误态提示；
/// - 一次性连接与自动同步开关。
class FourDigitPairDialog extends StatefulWidget {
  const FourDigitPairDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.cancelText,
    required this.invalidCodeText,
    required this.oneTimeConnectionLabel,
    required this.autoSyncLabel,
    required this.initialOneTimeConnection,
    required this.initialAutoSync,
    required this.onOneTimeConnectionChanged,
    required this.onAutoSyncChanged,
    required this.onSubmit,
  });

  final String title;
  final String hint;
  final String cancelText;
  final String invalidCodeText;
  final String oneTimeConnectionLabel;
  final String autoSyncLabel;
  final bool initialOneTimeConnection;
  final bool initialAutoSync;
  final Future<void> Function(bool value) onOneTimeConnectionChanged;
  final Future<void> Function(bool value) onAutoSyncChanged;
  final Future<bool> Function(String code) onSubmit;

  @override
  State<FourDigitPairDialog> createState() => _FourDigitPairDialogState();
}

class _FourDigitPairDialogState extends State<FourDigitPairDialog> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late bool _oneTimeConnection;
  late bool _autoSync;
  bool _submitting = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    _oneTimeConnection = widget.initialOneTimeConnection;
    _autoSync = widget.initialAutoSync;
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _joinedCode => _controllers.map((c) => c.text).join();

  Future<void> _tryAutoSubmit() async {
    if (_submitting || !RegExp(r'^\d{4}$').hasMatch(_joinedCode)) {
      return;
    }

    setState(() {
      _submitting = true;
      _hasError = false;
    });

    final success = await widget.onSubmit(_joinedCode);
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() {
      _submitting = false;
      _hasError = true;
    });
  }

  Widget _buildCell(int index) {
    return SizedBox(
      width: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: index == 3 ? TextInputAction.done : TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor:
              _hasError
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
                  : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  _hasError
                      ? Theme.of(context).colorScheme.error
                      : AppColors.borderSoft,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              width: 1.4,
              color:
                  _hasError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        onChanged: (value) {
          if (_submitting) {
            return;
          }
          if (_hasError) {
            setState(() {
              _hasError = false;
            });
          }
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          }
          unawaited(_tryAutoSubmit());
        },
        onSubmitted: (_) {
          if (_submitting) {
            return;
          }
          unawaited(_tryAutoSubmit());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCell(0),
                const SizedBox(width: 8),
                _buildCell(1),
                const SizedBox(width: 8),
                _buildCell(2),
                const SizedBox(width: 8),
                _buildCell(3),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    _hasError ? widget.invalidCodeText : widget.hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          _hasError
                              ? Theme.of(context).colorScheme.error
                              : null,
                      fontWeight: _hasError ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _oneTimeConnection,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(widget.oneTimeConnectionLabel),
              onChanged:
                  _submitting
                      ? null
                      : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _oneTimeConnection = value;
                        });
                        unawaited(widget.onOneTimeConnectionChanged(value));
                      },
            ),
            CheckboxListTile(
              value: _autoSync,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(widget.autoSyncLabel),
              onChanged:
                  _submitting
                      ? null
                      : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _autoSync = value;
                        });
                        unawaited(widget.onAutoSyncChanged(value));
                      },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.cancelText),
        ),
      ],
    );
  }
}
