import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Rounded, shadowed card holding a list of [ListTile]s.
///
/// The fill lives on a [Material], not on the shadow-casting container above
/// it: a ListTile paints its background and ink splashes onto the nearest
/// Material ancestor, so a coloured DecoratedBox in between would cover them
/// and the tap ripple would never be seen.
class TileCard extends StatelessWidget {
  final Widget child;

  /// Defaults to the themed card colour.
  final Color? color;

  const TileCard({super.key, required this.child, this.color});

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: AppColors.of(context).cardShadow,
      ),
      child: Material(
        color: color ?? AppColors.of(context).card,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
