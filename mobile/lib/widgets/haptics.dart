import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptic feedback for the app's commit moments (item added, payment
/// collected, order fired) — wrapped so it always respects the user's
/// accessibility settings.
///
/// Every call is a no-op when [MediaQuery.disableAnimationsOf] is true: that
/// flag is the cross-platform proxy for the OS "reduce motion / remove
/// animations" setting, and users who asked their device for fewer sensations
/// must not get buzzes they never opted into.
class AppHaptics {
  AppHaptics._();

  /// Light tick for small in-app confirmations (steppers, toggles).
  static Future<void> tap(BuildContext context) =>
      _fire(context, HapticFeedback.selectionClick);

  /// Soft bump — "something was added".
  static Future<void> light(BuildContext context) =>
      _fire(context, HapticFeedback.lightImpact);

  /// Firm thud — a decision that costs something (validation failure).
  static Future<void> impact(BuildContext context) =>
      _fire(context, HapticFeedback.mediumImpact);

  /// Strong confirmation — money changed hands, order fired to the kitchen.
  static Future<void> success(BuildContext context) =>
      _fire(context, HapticFeedback.heavyImpact);

  /// Deliberately different pattern from [success] so a failure never feels
  /// like a win.
  static Future<void> error(BuildContext context) =>
      _fire(context, HapticFeedback.vibrate);

  static Future<void> _fire(
    BuildContext context,
    Future<void> Function() feedback,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return Future<void>.value();
    return feedback();
  }
}
