import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/api_client.dart" show apiBaseUrl;
import "../../core/auth/auth_state.dart";
import "../../core/models/driver.dart";
import "../../core/theme/app_theme.dart";
import "../deck/deck_provider.dart" show driverRepoProvider;
import "../auth/providers.dart" show userRepoProvider;
import "account_providers.dart";

/// Shared logout pill — the admin header still carries one; every other
/// shell reaches logout through its Account tab.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.tonal(
      onPressed: () => ref.read(authProvider.notifier).logout(),
      child: const Text("Log out"),
    );
  }
}

/// Session identity + Task B profile customization: tappable avatar
/// (gallery pick → multipart upload), name/email/role card with an edit
/// sheet, a change-password item (success ⇒ re-login flow) and a
/// driver-only vehicle block backed by PATCH /api/drivers.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _uploadingAvatar = false;

  /// Server photos arrive as relative `/uploads/…` URLs — resolve them
  /// against the API base; absolute URLs pass through untouched.
  String? get _photoUrl {
    final photo =
        ref.watch(authProvider).valueOrNull?.photo?.trim() ?? "";
    if (photo.isEmpty) return null;
    if (photo.startsWith("http://") || photo.startsWith("https://")) {
      return photo;
    }
    return "$apiBaseUrl$photo";
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);

    final picked = await ref.read(avatarPickerProvider)();
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? _mimeFromName(picked.name);
      final result = await ref.read(userRepoProvider).uploadAvatar(
            bytes: bytes,
            filename: picked.name.isNotEmpty ? picked.name : "avatar.jpg",
            mimeType: mimeType,
          );
      if (!mounted) return;
      if (result.isOk) {
        await ref.read(authProvider.notifier).adoptUser(result.data!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
    }

    if (mounted) setState(() => _uploadingAvatar = false);
  }

  Future<void> _openEditProfileSheet() async {
    final session = ref.read(authProvider).valueOrNull ?? const AuthState();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: _EditProfileSheet(
          name: session.name ?? "",
          phone: session.phone ?? "",
        ),
      ),
    );
  }

  Future<void> _openPasswordSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: const _ChangePasswordSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(authProvider).valueOrNull ?? const AuthState();
    final name = session.name;
    final email = session.email;
    final role = (session.role ?? "").toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text("Account", style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        key: const Key("account-avatar"),
                        onTap: _pickAndUploadAvatar,
                        child: _avatar(theme, name),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name ?? "Signed in",
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              email ?? "—",
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "Edit profile",
                        onPressed: _openEditProfileSheet,
                        icon: const Icon(Icons.edit_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.amberDeep,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              onTap: _openPasswordSheet,
              icon: Icons.lock_outline_rounded,
              title: "Change password",
              subtitle: "You'll log in again with the new one",
            ),
            if (session.role == "driver") ...[
              const SizedBox(height: 12),
              _VehicleSection(),
            ],
            const SizedBox(height: 16),
            const SizedBox(width: double.infinity, child: LogoutButton()),
          ],
        ),
      ),
    );
  }

  Widget _avatar(ThemeData theme, String? name) {
    final url = _photoUrl;
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.amber.withValues(alpha: .14),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: url == null ? 0 : .9),
          width: 2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _initialsTile(theme, name),
            )
          else
            _initialsTile(theme, name),
          if (_uploadingAvatar)
            const ColoredBox(
              color: Colors.black38,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialsTile(ThemeData theme, String? name) => Center(
        child: Text(
          _initialsFor(name),
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.amberDeep,
          ),
        ),
      );
}

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}

/// First letters of the first two name words ("Dara Sok" → "DS").
String _initialsFor(String? name) {
  final words =
      name?.trim().split(RegExp(r"\s+")).where((w) => w.isNotEmpty).toList() ??
          const [];
  if (words.isEmpty) return "?";
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

// --- shared bits -----------------------------------------------------------

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.amberDeep, size: 22),
        title: Text(title, style: theme.textTheme.labelLarge),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.faint),
      ),
    );
  }
}

/// Bottom-sheet chrome shared by all three forms (booking-sheet style).
Future<T?> _showFormSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: child,
    ),
  );
}

Widget _dragHandle() => Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

InputDecoration _field(String label, IconData icon) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon, size: 18),
    );

TextFormField _sheetField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  bool obscured = false,
  String? Function(String?)? validator,
  TextInputAction action = TextInputAction.next,
}) =>
    TextFormField(
      controller: controller,
      decoration: _field(label, icon),
      keyboardType: keyboardType,
      obscureText: obscured,
      autocorrect: false,
      textInputAction: action,
      validator: validator,
    );

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.passRed.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.passRed.withValues(alpha: .35)),
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.passRed),
      ),
    );
  }
}

FilledButton _submitButton(BuildContext context,
        {required String label,
        required bool busy,
        required VoidCallback onPressed}) =>
    FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: AppColors.amber.withValues(alpha: .4),
        disabledForegroundColor: AppColors.ink.withValues(alpha: .5),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );

bool _validPhone(String v) => RegExp(r"^[0-9+][0-9\s\-]{4,19}$").hasMatch(v);

// --- profile edit sheet ------------------------------------------------------

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).updateProfile(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(); // optimistic write already on the card
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(),
                const SizedBox(height: 8),
                Text("Edit profile",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                _sheetField(
                  controller: _name,
                  label: "Name",
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    final v = value?.trim() ?? "";
                    if (v.isEmpty) return "Enter your name";
                    if (v.length < 2) return "At least 2 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _sheetField(
                  controller: _phone,
                  label: "Phone",
                  icon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final v = value?.trim() ?? "";
                    if (v.isEmpty) return "Enter your phone number";
                    if (!_validPhone(v)) return "Enter a valid phone number";
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_error!),
                ],
                const SizedBox(height: 16),
                _submitButton(context,
                    label: "Save changes", busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- password sheet ----------------------------------------------------------

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(userRepoProvider).changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );

    if (!mounted) return;
    if (!result.isOk) {
      setState(() {
        _busy = false;
        // The mapped UNAUTHORIZED copy ("Please log in again.") reads wrong
        // here — this endpoint's 401 specifically means a bad current secret.
        _error = result.code == "UNAUTHORIZED"
            ? "Your current password is incorrect."
            : result.message!;
      });
      return;
    }

    Navigator.of(context).pop();
    // Re-login flow (Task A design): token stays valid server-side, but the
    // app clears the session so the next login exercises the new secret.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Password changed. Please log in again."),
      ),
    );
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(),
                const SizedBox(height: 8),
                Text("Change password",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                _sheetField(
                  controller: _current,
                  label: "Current password",
                  icon: Icons.lock_outline_rounded,
                  obscured: true,
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Enter your current password"
                      : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  controller: _next,
                  label: "New password",
                  icon: Icons.key_outlined,
                  obscured: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter a new password";
                    }
                    if (value.length < 8) return "At least 8 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _sheetField(
                  controller: _confirm,
                  label: "Confirm new password",
                  icon: Icons.check_circle_outline_rounded,
                  obscured: true,
                  action: TextInputAction.done,
                  validator: (value) =>
                      value != _next.text ? "Passwords don't match" : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_error!),
                ],
                const SizedBox(height: 16),
                _submitButton(context,
                    label: "Update password", busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- driver vehicle block ------------------------------------------------------

class _VehicleSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VehicleSection> createState() => _VehicleSectionState();
}

class _VehicleSectionState extends ConsumerState<_VehicleSection> {
  Driver? _vehicle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref.read(driverRepoProvider).me();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _vehicle = result.data;
    });
  }

  Future<void> _edit() async {
    final vehicle = _vehicle;
    if (vehicle == null) return;
    final updated = await _showFormSheet<Driver>(
      context,
      child: _EditVehicleSheet(vehicle: vehicle),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _vehicle = updated); // server truth
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Vehicle", style: theme.textTheme.titleMedium),
              ),
              if (_vehicle != null)
                IconButton(
                  tooltip: "Edit vehicle",
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_rounded, size: 20),
                ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_vehicle != null) ...[
            _row(theme, "Car model", _vehicle!.carModel),
            _row(theme, "Plate", _vehicle!.plate),
            _row(theme, "License", _vehicle!.licenseNo),
            _row(theme, "Price per km",
                "\$${_vehicle!.pricePerKm.toStringAsFixed(2)} / km"),
          ] else
            Text("No vehicle yet", style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      );
}

class _EditVehicleSheet extends ConsumerStatefulWidget {
  const _EditVehicleSheet({required this.vehicle});

  final Driver vehicle;

  @override
  ConsumerState<_EditVehicleSheet> createState() => _EditVehicleSheetState();
}

class _EditVehicleSheetState extends ConsumerState<_EditVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _carModel = TextEditingController(text: widget.vehicle.carModel);
  late final _plate = TextEditingController(text: widget.vehicle.plate);
  late final _license = TextEditingController(text: widget.vehicle.licenseNo);
  late final _price = TextEditingController(
    text: widget.vehicle.pricePerKm.toStringAsFixed(2),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _carModel.dispose();
    _plate.dispose();
    _license.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      setState(() => _error = "Enter a valid price per km");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(driverRepoProvider).updateVehicle(
          carModel: _carModel.text.trim(),
          plate: _plate.text.trim(),
          licenseNo: _license.text.trim(),
          pricePerKm: price,
        );

    if (!mounted) return;
    if (!result.isOk) {
      setState(() {
        _busy = false;
        _error = result.message!;
      });
      return;
    }
    Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(),
                const SizedBox(height: 8),
                Text("Edit vehicle",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                _sheetField(
                  controller: _carModel,
                  label: "Car model",
                  icon: Icons.directions_car_rounded,
                  validator: (value) => (value == null ||
                          value.trim().isEmpty)
                      ? "Enter your car model"
                      : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  controller: _plate,
                  label: "Plate",
                  icon: Icons.pin_rounded,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? "Enter your plate"
                          : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  controller: _license,
                  label: "License",
                  icon: Icons.badge_outlined,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? "Enter your license"
                          : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  controller: _price,
                  label: "Price per km (\$)",
                  icon: Icons.payments_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) =>
                      double.tryParse(value?.trim() ?? "") == null
                          ? "Enter a valid price per km"
                          : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_error!),
                ],
                const SizedBox(height: 16),
                _submitButton(context,
                    label: "Update vehicle", busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
