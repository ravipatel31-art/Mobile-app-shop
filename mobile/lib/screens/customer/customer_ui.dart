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

/// Shared-element (Hero) tags for one dish across the customer journey:
/// menu card -> item sheet -> cart line -> checkout summary. Every screen
/// wraps the same dish in the same tag, so it keeps its identity while the
/// flow moves on instead of blinking out and reappearing.
///
/// Flutter only flies heroes between `PageRoute`s (a modal bottom sheet is a
/// `PopupRoute`), so the item sheet carries the same tags for continuity but
/// the flight itself only happens on the pushed screens.
class DishHeroTags {
  const DishHeroTags({required this.art, required this.title});

  /// The dish's picture (emoji tile or photo).
  final String art;

  /// The dish's name.
  final String title;
}

/// Hero tags for a single dish: the item id is the identity, with the name
/// as a last-resort fallback when the id comes back blank.
DishHeroTags dishHeroTagsForItem(MenuItem item) {
  final id = item.id.trim();
  final key = id.isEmpty ? item.name.trim() : id;
  return DishHeroTags(art: 'dish-$key', title: 'dish-$key-title');
}

/// Hero tags for a listed run of dishes, made unique for one route.
///
/// A dish listed once keeps its plain tag — that is what pairs it with the
/// dish's card. Anything that would repeat a tag already used in this run —
/// the same dish listed twice (different options are separate cart lines),
/// or an id crafted to collide with another dish's `-title` slot — gets the
/// list position appended: Hero throws when two widgets in one route share a
/// tag.
List<DishHeroTags> dishHeroTagsFor(Iterable<MenuItem> items) {
  final used = <String>{};
  final tags = <DishHeroTags>[];
  var position = 0;
  for (final item in items) {
    final base = dishHeroTagsForItem(item);
    var dish = base;
    while (used.contains(dish.art) || used.contains(dish.title)) {
      dish = _withSuffix(dish, '@$position');
    }
    used.add(dish.art);
    used.add(dish.title);
    tags.add(dish);
    position++;
  }
  return tags;
}

DishHeroTags _withSuffix(DishHeroTags tags, String suffix) => DishHeroTags(
      art: '${tags.art}$suffix',
      title: '${tags.title}$suffix',
    );

/// "GST 5%" pill shown next to prices on the menu.
class GstChip extends StatelessWidget {
  final int rate;

  const GstChip({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // Pale latte chip on cream; the raised surface tone in dark, so it
        // reads as a chip instead of a bright sticker.
        color: scheme.latte,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'GST $rate%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.coffee,
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
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
            // Unselected rests on the page: white on cream, card surface
            // on espresso (a white pill would glare there).
            color: selected ? null : scheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.07)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: CafePalette.coffee.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
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
                  color: selected ? Colors.white : scheme.espressoInk,
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(999);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? gradient : null,
        // Disabled drops the gradient for a flat, inert tone: greyed cream
        // on light, the top of the espresso ladder in dark.
        color: enabled ? null : scheme.surfaceContainerHighest,
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
                  // White over the gradient; a muted on-surface wash over
                  // the inert fill (black at 26–38% on light, warm white
                  // at the same strength in dark).
                  color: enabled
                      ? Colors.white
                      : scheme.onSurface.withValues(alpha: dark ? 0.45 : 0.38),
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
      final scheme = Theme.of(context).colorScheme;
      final dark = scheme.brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.latte,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Sold out',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            // Muted coffee-grey on latte; the muted secondary text role
            // carries the same "inert" reading on the dark surface.
            color: dark ? scheme.onSurfaceVariant : const Color(0xFF9C8A78),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.07)),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return InkResponse(
      radius: 18,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          icon,
          size: 20,
          // Espresso ink when live; black@26% (light) / warm white@38%
          // (dark) when the step is out of range.
          color: enabled
              ? scheme.espressoInk
              : scheme.onSurface.withValues(alpha: dark ? 0.38 : 0.26),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          // A white dock reads as "laid over" the cream page; in dark the
          // same move is a *lighter* surface, one step up the ladder.
          color: dark ? scheme.surfaceContainerHigh : Colors.white,
          border: Border(
              top: BorderSide(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
