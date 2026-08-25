import "package:flutter/material.dart";

import "../../core/api/api_client.dart" show resolveUploadUrl;
import "../../core/theme/app_theme.dart" show tokensOf;

/// Identity circle shared by the booking-sheet mini-header and the tracking
/// driver card: vehicle photo first, user avatar as fallback, taxi icon when
/// neither exists (DESIGN §8 — no broken-image icons, ever). Relative
/// `/uploads/…` URLs resolve against the API base; broken URLs degrade
/// silently to the icon.
class DriverPhotoAvatar extends StatelessWidget {
  const DriverPhotoAvatar({
    super.key,
    required this.vehiclePhoto,
    required this.photo,
    this.size = 44,
    this.iconSize = 22,
    this.backgroundColor,
  });

  final String? vehiclePhoto;
  final String? photo;
  final double size;
  final double iconSize;

  /// Defaults to the theme card color; callers may match their surface
  /// (e.g. the sheet's inset tone).
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final first = vehiclePhoto?.trim() ?? "";
    final raw = first.isNotEmpty ? first : (photo?.trim() ?? "");
    final url = raw.isEmpty ? null : resolveUploadUrl(raw);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? tokens.card,
      ),
      child: url == null
          ? Icon(Icons.local_taxi_rounded,
              color: tokens.textSecondary, size: iconSize)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(Icons.local_taxi_rounded,
                  color: tokens.textSecondary, size: iconSize),
            ),
    );
  }
}
