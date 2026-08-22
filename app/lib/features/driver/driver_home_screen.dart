import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../core/api/api_client.dart";
import "../../core/api/error_messages.dart";
import "../../core/api/ride_repo.dart";
import "../../core/models/driver.dart";
import "../../core/theme/app_theme.dart";
import "../customer/customer_home_screen.dart";
import "driver_provider.dart";
import "request_card.dart";
import "ride_controls.dart";

/// The driver's working screen (Task 4.6): presence toggle + heartbeats,
/// vehicle card / first-time setup, incoming request card, ride controls.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(driverProvider);

    return Scaffold(
      body: SafeArea(
        child: home.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          error: (error, _) => _BootError(message: _messageFor(error)),
          data: (state) => RefreshIndicator(
            onRefresh: () async =>
                ref.read(driverProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text("MotoDub Driver",
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: () => context.push("/history"),
                      icon: const Icon(Icons.history_rounded),
                      tooltip: "Your rides",
                    ),
                    const LogoutButton(),
                  ],
                ),
                const SizedBox(height: 16),
                if (state.vehicle != null) ...[
                  _StatusCard(state: state),
                  const SizedBox(height: 14),
                ],
                if (state.error != null) ...[
                  _ErrorBanner(message: state.error!),
                  const SizedBox(height: 14),
                ],
                state.vehicle == null
                    ? _VehicleSetupForm(submit: (fields) => ref
                        .read(driverProvider.notifier)
                        .submitVehicle(
                          carModel: fields.carModel,
                          plate: fields.plate,
                          licenseNo: fields.licenseNo,
                          pricePerKm: fields.pricePerKm,
                        ))
                    : _VehicleCard(vehicle: state.vehicle!),
                if (state.incoming != null) ...[
                  const SizedBox(height: 14),
                  RequestCard(
                    request: state.incoming!,
                    onAccept: () =>
                        ref.read(driverProvider.notifier).accept(),
                    onDecline: () =>
                        ref.read(driverProvider.notifier).decline(),
                  ),
                ],
                if (state.active != null) ...[
                  const SizedBox(height: 14),
                  RideControls(
                    ride: state.active!,
                    onStart: () => ref
                        .read(driverProvider.notifier)
                        .advance(RideAction.start),
                    onStartRide: () => ref
                        .read(driverProvider.notifier)
                        .advance(RideAction.startRide),
                    onComplete: () => ref
                        .read(driverProvider.notifier)
                        .advance(RideAction.complete),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _messageFor(Object error) {
  if (error is ApiException) return error.message;
  return networkUnreachableMessage;
}

/// Presence card — grey dot offline → green online; the switch is hidden
/// entirely until a vehicle profile exists (the server rejects toggles
/// without one anyway).
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.state});

  final DriverHomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _PresenceDot(online: state.online),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.online ? "You're online" : "You're offline",
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  state.online
                      ? "Receiving ride requests"
                      : "Go online to receive requests",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: state.online,
            onChanged: (value) =>
                ref.read(driverProvider.notifier).toggleOnline(value),
            activeTrackColor: AppColors.bookGreen,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.bookGreen : AppColors.faint,
        boxShadow: online
            ? [BoxShadow(color: AppColors.bookGreen.withValues(alpha: .4), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final Driver vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = vehicle.verified;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${vehicle.carModel} · ${vehicle.plate}",
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text("${vehicle.pricePerKm.toStringAsFixed(2)} /km",
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: AppColors.amberDeep)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: verified ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              verified ? "Verified" : "Pending review",
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    verified ? const Color(0xFF047857) : AppColors.amberDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleFields {
  const VehicleFields({
    required this.carModel,
    required this.plate,
    required this.licenseNo,
    required this.pricePerKm,
  });

  final String carModel;
  final String plate;
  final String licenseNo;
  final double pricePerKm;
}

/// First-time setup — create-once vehicle profile (`POST /drivers`).
class _VehicleSetupForm extends StatefulWidget {
  const _VehicleSetupForm({required this.submit});

  final Future<void> Function(VehicleFields fields) submit;

  @override
  State<_VehicleSetupForm> createState() => _VehicleSetupFormState();
}

class _VehicleSetupFormState extends State<_VehicleSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _carModel = TextEditingController();
  final _plate = TextEditingController();
  final _license = TextEditingController();
  final _price = TextEditingController();
  bool _saving = false;

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
    setState(() => _saving = true);
    await widget.submit(VehicleFields(
      carModel: _carModel.text.trim(),
      plate: _plate.text.trim(),
      licenseNo: _license.text.trim(),
      pricePerKm: double.tryParse(_price.text.replaceAll(",", ".")) ?? 0,
    ));
    if (mounted) setState(() => _saving = false);
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Set up your vehicle", style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text("One profile per driver — admin review follows.",
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            TextFormField(
              controller: _carModel,
              decoration: const InputDecoration(labelText: "Car model"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _plate,
              decoration: const InputDecoration(labelText: "Plate"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _license,
              decoration: const InputDecoration(labelText: "License no"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: "Price per km"),
              validator: (v) =>
                  double.tryParse(v?.replaceAll(",", ".") ?? "") == null
                      ? "Enter a number"
                      : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Save vehicle"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: const Color(0xFFB91C1C)),
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load your dashboard",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
