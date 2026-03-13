import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: screenHeight * 0.1),

                // ── Logo ─────────────────────────────
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(
                      Icons.local_gas_station_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Fuel Op',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'PRECISION LOGGING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.08),

                // ── Alerts ─────────────────────────────
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.sessionExpiredMessage != null) {
                      return _buildAlert(
                        message: auth.sessionExpiredMessage!,
                        color: AppColors.warning,
                      );
                    }
                    if (auth.error != null) {
                      return _buildAlert(
                        message: auth.error!,
                        color: AppColors.error,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // ── Input Fields ───────────────────────
                const _InputLabel(label: 'Identity'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'manager@fuelop.co',
                    prefixIcon: Icon(Icons.person_rounded, size: 18),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                const _InputLabel(label: 'Access Key'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 32),

                // ── Sign In Button ─────────────────────
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final isLoading = auth.status == AuthStatus.loading;
                    return SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: isLoading ? null : _login,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('AUTHORIZE ACCESS'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Forgot Password ───────────────────
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Open web forgot-password in browser
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Contact your station manager to reset your password.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          backgroundColor: AppColors.info,
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    'BUILD v1.0.0',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlert({required String message, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String label;
  const _InputLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
