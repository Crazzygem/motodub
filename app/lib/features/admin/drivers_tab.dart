import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/api/admin_repo.dart";
import "../../core/api/error_messages.dart" show localizedErrorFor;
import "../../core/l10n/l10n.dart";
import "../../core/preferences/preferences_provider.dart" show appLocaleProvider;
import "../../core/theme/app_theme.dart";
import "admin_screen.dart" show adminRepoProvider;

// DESIGN.md §2 admin chip tokens (not core AppColors — admin-only shades):
// verified ok-bg/#047857 · pending warn-bg/#B45309 · suspended bad-bg/#B91C1C.
const _okBg = Color(0xFFD1FAE5);
const _okFg = Color(0xFF047857);
const _warnBg = Color(0xFFFEF3C7);
const _warnFg = Color(0xFFB45309);
const _badBg = Color(0xFFFEE2E2);
const _badFg = Color(0xFFB91C1C);

/// One fetch of GET /api/admin/drivers plus its render state. Loading is
/// implicit: `drivers == null && error == null` (history_screen convention).
class DriversState {
  const DriversState({this.drivers, this.error});

  final List<AdminDriver>? drivers;

  /// Mapped, user-facing failure copy — null when idle.
  final String? error;
}

class DriversNotifier extends AutoDisposeNotifier<DriversState> {
  /// Set when the container disposes this notifier — awaited repo calls
  /// check it before touching state (this riverpod has no Ref.mounted).
  bool _disposed = false;

  @override
  DriversState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return const DriversState();
  }

  /// Pull-to-refresh seam.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    // No state write before the await — the initial state IS loading.
    final result = await ref.read(adminRepoProvider).drivers();
    if (_disposed) return;

    if (result.isOk) {
      state = DriversState(drivers: result.data);
      return;
    }
    state = DriversState(
      drivers: state.drivers,
      error: localizedErrorFor(
        lookupAppLocalizations(ref.watch(appLocaleProvider)),
        result.code,
        serverMessage: result.message,
      ),
    );
  }

  /// Modal-confirmed action (PROJECT.md §6: verification and destructive
  /// actions both live behind confirm dialogs). Optimistic chip flip from
  /// the server's row, then a silent reconcile against fresh truth.
  Future<void> runAction(AdminDriver row, {required bool verify}) async {
    final result = verify
        ? await ref.read(adminRepoProvider).verifyDriver(row.driverId)
        : await ref.read(adminRepoProvider).suspendDriver(row.driverId);
    if (_disposed) return;

    if (!result.isOk) {
      state = DriversState(
        drivers: state.drivers,
        error: localizedErrorFor(
          lookupAppLocalizations(ref.watch(appLocaleProvider)),
          result.code,
          serverMessage: result.message,
        ),
      );
      return;
    }

    final updated = result.data!;
    final rows = [...(state.drivers ?? const <AdminDriver>[])];
    final index = rows.indexWhere((d) => d.driverId == updated.driverId);
    if (index >= 0) rows[index] = updated;
    state = DriversState(drivers: rows);

    await _load();
  }

  /// Seth directive — admin edits any driver "just like the driver side".
  /// Same rhythm as [runAction]: optimistic replace from the server's row,
  /// then a silent reconcile against fresh truth. Returns the mapped
  /// failure copy so the sheet keeps its error banner — null on success.
  Future<String?> editDriver(
    int driverRowId,
    Map<String, dynamic> fields,
  ) async {
    final result =
        await ref.read(adminRepoProvider).patchDriver(driverRowId, fields);
    if (_disposed) return null;

    if (!result.isOk) {
      final message = localizedErrorFor(
        lookupAppLocalizations(ref.watch(appLocaleProvider)),
        result.code,
        serverMessage: result.message,
      );
      state = DriversState(drivers: state.drivers, error: message);
      return message;
    }

    final updated = result.data!;
    final rows = [...(state.drivers ?? const <AdminDriver>[])];
    final index = rows.indexWhere((d) => d.driverId == updated.driverId);
    if (index >= 0) rows[index] = updated;
    state = DriversState(drivers: rows);

    await _load();
    return null;
  }
}

final driversProvider =
    AutoDisposeNotifierProvider<DriversNotifier, DriversState>(
  DriversNotifier.new,
);

/// Task 6.2 step 2 — driver verification table. Approve shows for unverified
/// rows, Suspend for active accounts; BOTH open a confirm dialog first.
class DriversTab extends ConsumerWidget {
  const DriversTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(driversProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(driversProvider.notifier).refresh(),
      child: drivers.error != null && drivers.drivers == null
          ? _ErrorView(
              message: drivers.error!,
              onRetry: () => ref.read(driversProvider.notifier).refresh(),
            )
          : drivers.drivers == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 140),
                    Center(child: CircularProgressIndicator(strokeWidth: 3)),
                  ],
                )
              : _Content(rows: drivers.drivers!),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.rows});

  final List<AdminDriver> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) return const _EmptyView();
    final bannerError = ref.watch(
      driversProvider.select((s) => s.drivers == null ? s.error : null),
    );

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: rows.length + (bannerError == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (bannerError != null && index == rows.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              bannerError,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.passRed),
            ),
          );
        }
        return _DriverRow(row: rows[index]);
      },
    );
  }
}

class _DriverRow extends ConsumerWidget {
  const _DriverRow({required this.row});

  final AdminDriver row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = context.l10n;
    final (chipLabel, chipBg, chipFg) = _statusChip(row, s);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.name,
                    style: theme.textTheme.titleMedium),
              ),
              _Pill(label: chipLabel, bg: chipBg, fg: chipFg),
              const SizedBox(width: 6),
              _onlineChip(context),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.email, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _warnBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "\$${row.pricePerKm.toStringAsFixed(2)}/km",
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: _warnFg, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Text("★ ${row.rating.toStringAsFixed(1)}",
                  style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: Key("approve-${row.driverId}"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: row.verified
                      ? null
                      : () => _confirmAndRun(context, ref,
                          title: s.approveDriverTitle,
                          body: s.approveDriverBody(row.name),
                          confirmLabel: s.approveButton,
                          confirmColor: AppColors.ink,
                          verify: true),
                  child: Text(s.approveButton),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: Key("suspend-${row.driverId}"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.passRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: !row.active
                      ? null
                      : () => _confirmAndRun(context, ref,
                          title: s.suspendDriverTitle,
                          body: s.suspendDriverBody(row.name),
                          confirmLabel: s.suspendButton,
                          confirmColor: AppColors.passRed,
                          verify: false),
                  child: Text(s.suspendButton),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: Key("edit-${row.driverId}"),
                tooltip: s.editDriverTitle,
                onPressed: () => _openEditSheet(context),
                icon: const Icon(Icons.edit_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onlineChip(BuildContext context) {
    final s = l10nOf(context);
    return _Pill(
      label: row.online ? s.chipOnline : s.chipOffline,
      bg: row.online
          ? AppColors.bookGreen.withValues(alpha: .14)
          : tokensOf(context).line,
      fg: row.online
          ? AppColors.bookGreen
          : tokensOf(context).textSecondary,
    );
  }

  (String, Color, Color) _statusChip(AdminDriver d, AppLocalizations s) {
    if (!d.active) return (s.chipSuspended, _badBg, _badFg);
    if (d.verified) return (s.verifiedChip, _okBg, _okFg);
    return (s.chipPending, _warnBg, _warnFg);
  }

  /// PROJECT.md §6 / DESIGN.md §5 — the modal IS the gate: no repo call on
  /// the button tap itself, only after explicit confirmation.
  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
    required bool verify,
  }) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokensOf(ctx).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: theme.textTheme.titleMedium),
        content: Text(body, style: theme.textTheme.bodyLarge),
        actions: [
          TextButton(
            key: const Key("dialog-cancel"),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10nOf(ctx).cancel),
          ),
          FilledButton(
            key: const Key("dialog-confirm"),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(driversProvider.notifier).runAction(row, verify: verify);
  }

  /// Seth directive — edit sheet opens pre-filled; the PATCH dispatches
  /// only from its Save button (same gate-as-modal rule as approve/suspend).
  Future<void> _openEditSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokensOf(context).card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: _EditDriverSheet(driver: row),
      ),
    );
  }
}

// --- driver edit sheet (account-screen form-sheet conventions) ---------------

Widget _dragHandle(BuildContext context) => Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.tokens.line,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );

InputDecoration _field(String label, IconData icon) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon, size: 18),
    );

TextFormField _sheetField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  TextInputAction action = TextInputAction.next,
}) =>
    TextFormField(
      controller: controller,
      decoration: _field(label, icon),
      keyboardType: keyboardType,
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

FilledButton _submitButton(
  BuildContext context, {
  required String label,
  required bool busy,
  required VoidCallback onPressed,
}) =>
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

/// PATCH /api/admin/drivers/:id form — six fields, snake_case wire keys.
/// The server echoes the fresh row, which [DriversNotifier.editDriver]
/// adopts as server truth before a silent reconcile reload.
class _EditDriverSheet extends ConsumerStatefulWidget {
  const _EditDriverSheet({required this.driver});

  final AdminDriver driver;

  @override
  ConsumerState<_EditDriverSheet> createState() => _EditDriverSheetState();
}

class _EditDriverSheetState extends ConsumerState<_EditDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.driver.name);
  late final _phone = TextEditingController(text: widget.driver.phone ?? "");
  late final _carModel =
      TextEditingController(text: widget.driver.carModel ?? "");
  late final _plate = TextEditingController(text: widget.driver.plate ?? "");
  late final _license =
      TextEditingController(text: widget.driver.licenseNo ?? "");
  late final _price = TextEditingController(
    text: widget.driver.pricePerKm.toStringAsFixed(2),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _carModel.dispose();
    _plate.dispose();
    _license.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref.read(driversProvider.notifier).editDriver(
          widget.driver.driverId,
          {
            "name": _name.text.trim(),
            "phone": _phone.text.trim(),
            "car_model": _carModel.text.trim(),
            "plate": _plate.text.trim(),
            "license_no": _license.text.trim(),
            "price_per_km": double.parse(_price.text.trim()),
          },
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(); // row already adopted server truth
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

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
                _dragHandle(context),
                const SizedBox(height: 8),
                Text(s.editDriverTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                _sheetField(
                  context,
                  controller: _name,
                  label: s.nameLabel,
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    final v = value?.trim() ?? "";
                    if (v.isEmpty) return s.enterName;
                    if (v.length < 2) return s.atLeast2Chars;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _sheetField(
                  context,
                  controller: _phone,
                  label: s.phoneLabel,
                  icon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final v = value?.trim() ?? "";
                    if (v.isEmpty) return s.enterYourPhone;
                    if (!_validPhone(v)) return s.enterValidPhone;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _sheetField(
                  context,
                  controller: _carModel,
                  label: s.carModelLabel,
                  icon: Icons.directions_car_rounded,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? s.enterCarModel
                      : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  context,
                  controller: _plate,
                  label: s.plateLabel,
                  icon: Icons.pin_rounded,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? s.enterPlate
                          : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  context,
                  controller: _license,
                  label: s.licenseRow,
                  icon: Icons.badge_outlined,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? s.enterLicense
                          : null,
                ),
                const SizedBox(height: 12),
                _sheetField(
                  context,
                  controller: _price,
                  label: s.pricePerKmDollarLabel,
                  icon: Icons.payments_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  action: TextInputAction.done,
                  validator: (value) {
                    final price = double.tryParse(value?.trim() ?? "");
                    if (price == null || price <= 0) {
                      return s.enterValidPricePerKm;
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_error!),
                ],
                const SizedBox(height: 16),
                _submitButton(context,
                    label: s.saveChanges, busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🏍️", style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text(l10nOf(context).noDriversYetTitle,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                l10nOf(context).noDriversHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10nOf(context).couldntLoadDrivers,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10nOf(context).tryAgain),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
