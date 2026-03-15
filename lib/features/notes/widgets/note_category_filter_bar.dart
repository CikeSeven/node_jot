import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/note_category_codec.dart';

/// 笔记列表顶部分类筛选栏。
class NoteCategoryFilterBar extends StatefulWidget {
  const NoteCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryKeys,
    required this.onToggleCategory,
    required this.onClearCategories,
  });

  final List<String> categories;
  final Set<String> selectedCategoryKeys;
  final void Function(String category, bool selected) onToggleCategory;
  final VoidCallback onClearCategories;

  @override
  State<NoteCategoryFilterBar> createState() => _NoteCategoryFilterBarState();
}

class _NoteCategoryFilterBarState extends State<NoteCategoryFilterBar>
    with SingleTickerProviderStateMixin {
  static const double _halfTurn = 3.1415926535897932;

  late final AnimationController _clearController;
  late final Animation<double> _clearScale;
  late final Animation<double> _clearRotation;
  double _clearBaseAngle = 0;

  @override
  void initState() {
    super.initState();
    _clearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _clearScale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.84,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.84,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_clearController);
    _clearRotation = Tween<double>(
      begin: 0,
      end: _halfTurn,
    ).animate(CurvedAnimation(parent: _clearController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _clearController.dispose();
    super.dispose();
  }

  Future<void> _handleClearTap() async {
    widget.onClearCategories();
    if (_clearController.isAnimating) {
      return;
    }
    unawaited(_playClearAnimation());
  }

  Future<void> _playClearAnimation() async {
    await _clearController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _clearBaseAngle += _halfTurn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = widget.selectedCategoryKeys.isNotEmpty;
    final selectedChipColor =
        isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.96)
            : Colors.white;
    final unselectedChipColor =
        isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.86)
            : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s),
          itemBuilder: (context, index) {
            if (index == 0) {
              return AnimatedBuilder(
                animation: _clearController,
                builder: (_, child) {
                  return Transform.rotate(
                    angle: _clearBaseAngle + _clearRotation.value,
                    child: Transform.scale(
                      scale: _clearScale.value,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleClearTap,
                  child: SizedBox(
                    width: 26,
                    height: 32,
                    child: Center(
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color:
                            hasSelection
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }

            final category = widget.categories[index - 1];
            final selected = widget.selectedCategoryKeys.contains(
              NoteCategoryCodec.toKey(category),
            );
            return _CategoryChip(
              label: category,
              selected: selected,
              selectedColor: selectedChipColor,
              unselectedColor: unselectedChipColor,
              selectedForegroundColor: colorScheme.primary,
              unselectedForegroundColor: colorScheme.onSurface,
              onTap: () => widget.onToggleCategory(category, !selected),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectedForegroundColor,
    required this.unselectedForegroundColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedForegroundColor;
  final Color unselectedForegroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor =
        selected ? selectedForegroundColor : unselectedForegroundColor;
    final borderColor =
        selected
            ? selectedForegroundColor.withValues(alpha: 0.45)
            : colorScheme.outlineVariant.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? selectedColor : unselectedColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor, width: selected ? 2 : 1.2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
