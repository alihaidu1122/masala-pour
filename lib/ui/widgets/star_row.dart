import 'package:flutter/material.dart';

import '../../config/asset_paths.dart';

/// Displays 0–3 earned stars for a level.
class StarRow extends StatelessWidget {
  /// Creates a star row for [stars] out of 3.
  const StarRow({super.key, this.stars = 0, this.size = 32});

  final int stars;

  /// Size of each star icon.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.05),
          child: Image.asset(
            i < stars ? AssetPaths.starOn : AssetPaths.starOff,
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(
              i < stars ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}
