import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/auth/auth_state.dart";
import "../../core/l10n/l10n.dart";
import "../../core/theme/app_theme.dart";
import "auth_hero.dart";

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = "customer";
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _role,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccountTitle)),
      body: Column(
        children: [
          const AuthHero(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: authFieldDecoration(
                          context,
                          label: l10n.nameLabel,
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (value) =>
                            ((value?.trim().length ?? 0) < 2)
                                ? l10n.enterName
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        decoration: authFieldDecoration(
                          context,
                          label: l10n.phoneLabel,
                          icon: Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            ((value?.trim().length ?? 0) < 6)
                                ? l10n.enterValidPhone
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        decoration: authFieldDecoration(
                          context,
                          label: l10n.emailLabel,
                          icon: Icons.mail_outline_rounded,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        validator: (value) {
                          final v = value?.trim() ?? "";
                          if (v.isEmpty) return l10n.registerEnterEmail;
                          if (!v.contains("@")) return l10n.enterValidEmail;
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: authFieldDecoration(
                          context,
                          label: l10n.passwordMinLabel,
                          icon: Icons.lock_outline_rounded,
                        ),
                        validator: (value) =>
                            ((value?.length ?? 0) < 8)
                                ? l10n.passwordTooShort
                                : null,
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                              value: "customer",
                              label: Text(l10n.roleCustomer)),
                          ButtonSegment(
                              value: "driver", label: Text(l10n.roleDriver)),
                          ButtonSegment(
                              value: "admin", label: Text(l10n.roleAdmin)),
                        ],
                        selected: {_role},
                        onSelectionChanged: (selection) =>
                            setState(() => _role = selection.first),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.ink,
                          disabledBackgroundColor:
                              AppColors.amber.withValues(alpha: .4),
                          disabledForegroundColor:
                              AppColors.ink.withValues(alpha: .5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(l10n.createAccountTitle),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push("/login"),
                        child: Text(l10n.alreadyHaveAccount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
