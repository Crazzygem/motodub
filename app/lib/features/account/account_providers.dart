import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

/// Seam over image_picker so widget tests can fake the gallery pick.
typedef AvatarPicker = Future<XFile?> Function();

/// Gallery-only avatar pick (DESIGN §8: users get an avatar; no camera).
final avatarPickerProvider = Provider<AvatarPicker>((ref) {
  return () => ImagePicker().pickImage(source: ImageSource.gallery);
});
