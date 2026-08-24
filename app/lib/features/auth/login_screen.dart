import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";

import "../../core/auth/auth_state.dart";
import "../../core/theme/app_theme.dart";
import "auth_hero.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
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

    final error = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // Hero band fills the top half; the form scrolls below.
              SizedBox(
                height: constraints.maxHeight * 0.42,
                child: const AuthHero(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: authFieldDecoration(
                              label: "Email",
                              icon: Icons.mail_outline_rounded,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            validator: (value) {
                              final v = value?.trim() ?? "";
                              if (v.isEmpty) return "Enter your email";
                              if (!v.contains("@")) {
                                return "Enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: authFieldDecoration(
                              label: "Password",
                              icon: Icons.lock_outline_rounded,
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? "Enter your password"
                                    : null,
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
                                : const Text("Log in"),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.push("/register"),
                            child: const Text("No account? Register"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
