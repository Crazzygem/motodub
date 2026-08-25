import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

/// Seam over image_picker so widget tests can fake the gallery pick.
typedef AvatarPicker = Future<XFile?> Function();

/// Gallery-only avatar pick (DESIGN §8: users get an avatar; no camera).
final avatarPickerProvider = Provider<AvatarPicker>((ref) {
  return () => ImagePicker().pickImage(source: ImageSource.gallery);
});

/// Multi-pick seam for the vehicle photo gallery (widget tests fake it too).
typedef VehiclePhotosPicker = Future<List<XFile>> Function();

/// Gallery-only multi pick feeding POST /api/drivers/photos (cap 6 enforced
/// server-side). pickMultiImage is gallery-only on mobile — no source param.
final vehiclePhotosPickerProvider = Provider<VehiclePhotosPicker>((ref) {
  return () => ImagePicker().pickMultiImage();
});
