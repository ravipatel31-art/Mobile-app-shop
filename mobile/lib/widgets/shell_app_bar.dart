import 'package:flutter/material.dart';

/// Branded header for the owner and staff shells: a café badge, the current
/// view title (large, animated, and pinned to its real size so it never
/// collapses into "0"-looking glyphs on web), the signed-in user's identity
/// chip, and a logout action.
class ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShellAppBar({
    super.key,
    required this.title,
    required this.userName,
    required this.onLogout,
  });

  /// Total height (toolbar + 1px hairline below it).
  static const double kHeight = 66;

  final String title;
  final String userName;
  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kHeight);

  String get _initial =>
      userName.isEmpty ? '?' : userName.substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseTitle = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    // Big and unmistakably readable — and we pin the scale so aggressive
    // browser text scaling can't shrink it into a blur of "0"s on web.
    final titleStyle =
        baseTitle?.copyWith(fontSize: 26, fontWeight: FontWeight.w800);

    return AppBar(
      toolbarHeight: kHeight - 1,
      // Soft brand wash that fades down into the surface colour.
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
      // Hairline that gives the header a little definition over content.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.black.withValues(alpha: 0.06),
        ),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          // Café brand badge.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.local_cafe_rounded,
                size: 19, color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                title,
                key: ValueKey(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Signed-in identity: gradient initial + full name, so the avatar's
        // single letter is always in context (no lone "O" read as "0").
        Container(
          height: 36,
          padding: const EdgeInsets.only(left: 6, right: 10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Text(
                  _initial,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: scheme.onPrimaryContainer,
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  userName,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Log out ($userName)',
          icon: const Icon(Icons.logout_rounded),
          onPressed: onLogout,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}