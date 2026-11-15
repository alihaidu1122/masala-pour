import 'package:flutter/material.dart';

/// Renders a PNG from [AssetPaths] at a fixed [size], with optional fade when
/// [enabled] is false.
class AssetIcon extends StatelessWidget {
  /// Creates an asset icon.
  const AssetIcon(
    this.assetPath, {
    super.key,
    this.size = 28,
    this.enabled = true,
  });

  final String assetPath;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Source PNGs are 1024px; decode at display size to save memory.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3;
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      cacheWidth: (size * dpr).ceil(),
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          Icon(Icons.broken_image_outlined, size: size, color: Colors.white54),
    );
    if (enabled) return image;
    return Opacity(opacity: 0.35, child: image);
  }
}
