import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';

/// 简化版 4 位码输入弹窗。
///
/// 用于“重新连接”场景：只输入配对码，不包含额外设置选项。
class SimpleFourDigitCodeDialog extends StatefulWidget {
  const SimpleFourDigitCodeDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.invalidCodeText,
    required this.cancelText,
  });

  final String title;
  final String hint;
  final String invalidCodeText;
  final String cancelText;

  @override
  State<SimpleFourDigitCodeDialog> createState() =>
      _SimpleFourDigitCodeDialogState();
}

class _SimpleFourDigitCodeDialogState extends State<SimpleFourDigitCodeDialog> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
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

  String get _code => _controllers.map((e) => e.text).join();

  void _submitIfComplete() {
    if (RegExp(r'^\d{4}$').hasMatch(_code)) {
      Navigator.of(context).pop(_code);
      return;
    }
    setState(() {
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
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
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
          if (_hasError) {
            setState(() {
              _hasError = false;
            });
          }
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          }
          if (index == 3 && value.isNotEmpty) {
            _submitIfComplete();
          }
        },
        onSubmitted: (_) => _submitIfComplete(),
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
            Text(
              _hasError ? widget.invalidCodeText : widget.hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _hasError ? Theme.of(context).colorScheme.error : null,
                fontWeight: _hasError ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
      ],
    );
  }
}
