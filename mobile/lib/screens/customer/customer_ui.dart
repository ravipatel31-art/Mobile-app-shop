import 'package:flutter/material.dart';

import '../../models/menu_item.dart';
import '../../util/money.dart';
import '../../widgets/haptics.dart';
import '../../widgets/menu_image.dart';
import '../../widgets/motion.dart';
import '../../widgets/ui_kit.dart';

/// Photo-or-emoji art for a menu item: real photo when the item has one,
/// otherwise the gradient [EmojiArtTile] with a dish emoji.
class ItemArt extends StatelessWidget {
  final MenuItem item;
  final double size;
  final double fontSize;

  const ItemArt({
    super.key,
    required this.item,
    this.size = 84,
    this.fontSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    if (url == null || url.isEmpty) {
      return EmojiArtTile(
        emoji: dishEmoji(item.name, category: item.category),
        gradient: CafeGradients.forSeed('${item.category}-${item.name}'),
        size: size,
        fontSize: fontSize,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: MenuImage(url: url, width: size, height: size),
    );
  }
}

/// "GST 5%" pill shown next to prices on the menu.
class GstChip extends StatelessWidget {
  final int rate;

  const GstChip({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CafePalette.latte,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'GST $rate%',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: CafePalette.coffee,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Table pill for the hero banners — shows the picked table, or doubles as the
/// "Pick your table" call to action when the QR didn't carry one.
class TablePill extends StatelessWidget {
  final String? tableNumber;
  final VoidCallback onTap;

  const TablePill({super.key, required this.tableNumber, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final picked = tableNumber != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: picked ? Colors.white.withValues(alpha: 0.18) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: picked
                ? Border.all(color: Colors.white.withValues(alpha: 0.45))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_restaurant_rounded,
                size: 18,
                color: picked ? Colors.white : CafePalette.espresso,
              ),
              const SizedBox(width: 7),
              Text(
                picked ? 'Table $tableNumber' : 'Pick your table',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: picked ? Colors.white : CafePalette.espresso,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: picked
                    ? Colors.white.withValues(alpha: 0.8)
                    : CafePalette.caramel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Emoji + label pill used for the category filter strip.
class CategoryPill extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryPill({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, 180),
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? CafeGradients.coffee : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.07)),
            // Chips lift on the low rung of the shadow scale — no coloured
            // glow; the gradient alone carries the selection colour.
            boxShadow: selected ? AppShadow.low : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : CafePalette.espresso,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped gradient button used for the primary actions in the QR flow.
class GradientPillButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;

  /// Height at 100% text scale — used as a *minimum* so the pill grows
  /// (instead of clipping its label) at large OS text sizes.
  final double height;
  final double horizontalPadding;

  const GradientPillButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = CafeGradients.coffee,
    this.height = 52,
    this.horizontalPadding = 22,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? gradient : null,
        color: enabled ? null : const Color(0xFFE8E2DB),
        borderRadius: radius,
        boxShadow: enabled ? AppShadow.low : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 6),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : Colors.black38,
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "Add"/"Choose" button that sits on a menu card.
class ItemAddButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const ItemAddButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      // Tell screen readers *why* the control is inert, and keep the
      // "Sold out" label dark enough to read on the latte chip (the old
      // 0xFF9C8A78 was ~2.4:1 on white — far below the 4.5:1 floor).
      return Semantics(
        button: true,
        enabled: false,
        label: 'Sold out — currently unavailable',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: CafePalette.latte,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Sold out',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: CafePalette.coffee,
            ),
          ),
        ),
      );
    }
    return GradientPillButton(
      onPressed: onTap,
      height: 36,
      horizontalPadding: 16,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Friendly −/+ quantity control used in the item sheet and the cart.
class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const QtyStepper({
    super.key,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundStepButton(
            icon: Icons.remove_rounded,
            enabled: onDecrement != null,
            // Value included so a screen reader reports the new quantity
            // context, not just "decrease".
            semanticLabel: 'Decrement quantity, currently $qty',
            onTap: onDecrement,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 30),
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          _RoundStepButton(
            icon: Icons.add_rounded,
            enabled: onIncrement != null,
            semanticLabel: 'Increment quantity, currently $qty',
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _RoundStepButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkResponse(
        radius: 22,
        // 44×44: Apple's minimum comfortable touch target (was 36×36).
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.tap(context);
                onTap!();
              },
        child: SizedBox(
          width: 44,
          height: 44,
          child: _StepIcon(icon: icon, enabled: enabled),
        ),
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  const _StepIcon({required this.icon, required this.enabled});

  @override
  Widget build(BuildContext context) {
    // Disabled colour follows the theme instead of a hard-coded black26.
    final disabledColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);
    return Icon(
      icon,
      size: 20,
      color: enabled ? CafePalette.espresso : disabledColor,
    );
  }
}

/// Floating pill bar that appears once the customer has something in the cart.
class FloatingCartBar extends StatelessWidget {
  final int count;
  final int total;
  final VoidCallback onTap;

  const FloatingCartBar({
    super.key,
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(999));
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: CafeGradients.espresso,
        borderRadius: radius,
        // Floating pill over the menu → top rung of the shadow scale.
        boxShadow: AppShadow.high,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: [
                Semantics(
                  // The count digit alone means nothing read aloud — give
                  // the badge a full phrase.
                  label: '$count ${count == 1 ? 'item' : 'items'} in cart',
                  excludeSemantics: true,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'View your order',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Text(
                  formatMoney(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft white dock used at the bottom of the cart / checkout screens.
/// Delegates to the one [BottomSurface] material (single surface colour,
/// single hairline edge) — the floating elements on top own their shadows.
class BottomDock extends StatelessWidget {
  final Widget child;

  const BottomDock({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BottomSurface(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: child,
    );
  }
}
