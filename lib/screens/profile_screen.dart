import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reading_provider.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'customers_screen.dart';
import 'deliveries_screen.dart';
import 'tank_dips_screen.dart';
import 'alert_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditProfileSheet(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.user?.name ?? '');
    final emailController = TextEditingController(text: auth.user?.email ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormSheet(
        title: 'Edit Profile',
        icon: Icons.person_rounded,
        submitLabel: 'Save Changes',
        onSubmit: (setSheetState) async {
          final apiService = ApiService();
          await apiService.updateProfile(
            name: nameController.text.trim(),
            email: emailController.text.trim(),
          );
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            auth.checkAuth();
            _showSnack('Profile updated', AppColors.success);
          }
        },
        fields: [
          _SheetField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.badge_rounded,
          ),
          _SheetField(
            controller: emailController,
            label: 'Email Address',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormSheet(
        title: 'Change Password',
        icon: Icons.lock_rounded,
        submitLabel: 'Update Password',
        onSubmit: (setSheetState) async {
          if (newController.text != confirmController.text) {
            throw Exception('Passwords do not match');
          }
          final apiService = ApiService();
          await apiService.changePassword(
            currentPassword: currentController.text,
            newPassword: newController.text,
          );
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            _showSnack('Password changed successfully', AppColors.success);
          }
        },
        fields: [
          _SheetField(
            controller: currentController,
            label: 'Current Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          _SheetField(
            controller: newController,
            label: 'New Password',
            icon: Icons.lock_rounded,
            obscureText: true,
          ),
          _SheetField(
            controller: confirmController,
            label: 'Confirm New Password',
            icon: Icons.lock_reset_rounded,
            obscureText: true,
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),

            const Text(
              'Sign Out',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unsynced readings are stored locally and will sync automatically when you log back in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Sign Out'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.surfaceLight),
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncService>();
    final reading = context.watch<ReadingProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pagePadding,
          physics: const BouncingScrollPhysics(),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),

            // ── User Card ────────────────────────
            _HeroProfile(
              name: auth.user?.name ?? 'Manager',
              email: auth.user?.email ?? '',
              role: auth.user?.role ?? 'Manager',
            ),

            const SizedBox(height: 24),

            // ── Account Section ──────────────────────────
            _Label(text: 'Account'),
            const SizedBox(height: 8),
            _OptionCard(
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.edit_rounded,
                    label: 'Edit Profile',
                    color: AppColors.primary,
                    onTap: () => _showEditProfileSheet(context, auth),
                  ),
                  _ActionRow(
                    icon: Icons.lock_rounded,
                    label: 'Change Password',
                    color: AppColors.primary,
                    onTap: () => _showChangePasswordSheet(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Operations Section ────────────────────
            _Label(text: 'Operations'),
            const SizedBox(height: 8),
            _OptionCard(
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.people_rounded,
                    label: 'Customers',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomersScreen()),
                    ),
                  ),
                  _ActionRow(
                    icon: Icons.local_shipping_rounded,
                    label: 'Deliveries',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeliveriesScreen()),
                    ),
                  ),
                  _ActionRow(
                    icon: Icons.water_drop_rounded,
                    label: 'Tank Dips',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TankDipsScreen()),
                    ),
                  ),
                  _ActionRow(
                    icon: Icons.notifications_active_rounded,
                    label: 'Alert Settings',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AlertSettingsScreen()),
                    ),
                  ),
                  _ActionRow(
                    icon: Icons.history_toggle_off_rounded,
                    label: 'Alert Logs',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AlertLogsScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Sync Section ──────────────────────────
            _Label(text: 'System Sync'),
            const SizedBox(height: 8),
            _OptionCard(
              child: Column(
                children: [
                  _Row(
                    icon: Icons.sync_rounded,
                    label: 'Sync Status',
                    value: sync.isSyncing ? 'Syncing...' : 'Stable',
                    color: sync.isSyncing ? AppColors.warning : AppColors.success,
                  ),
                  _Row(
                    icon: Icons.data_usage_rounded,
                    label: 'Pending',
                    value: '${sync.pendingCount} Readings',
                    color: sync.pendingCount > 0 ? AppColors.warning : AppColors.textSecondary,
                  ),
                  if (sync.pendingCount > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pushNamed('/pending'),
                            child: const Text('Review', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: sync.isSyncing ? null : () => reading.syncNow(),
                            child: const Text('Sync Now', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── App Settings ──────────────────────────
            _Label(text: 'Application'),
            const SizedBox(height: 8),
            _OptionCard(
              child: Column(
                children: [
                  _Row(
                    icon: Icons.wifi_rounded,
                    label: 'Connection',
                    value: reading.isOnline ? 'Online' : 'Offline',
                    color: reading.isOnline ? AppColors.success : AppColors.error,
                  ),
                  _ActionRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AppColors.error,
                    onTap: () => _handleLogout(context, auth),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Center(
              child: Text(
                'FuelOp v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Bottom Sheet Form ─────────────────────────────────────────────

class _SheetField {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });
}

class _FormSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final String submitLabel;
  final List<_SheetField> fields;
  final Future<void> Function(StateSetter setSheetState) onSubmit;

  const _FormSheet({
    required this.title,
    required this.icon,
    required this.submitLabel,
    required this.fields,
    required this.onSubmit,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  bool _isSubmitting = false;
  String? _error;
  late final List<bool> _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.fields.map((f) => f.obscureText).toList();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(setState);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 36 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fields
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (int i = 0; i < widget.fields.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.surface, indent: 52),
                  _buildField(i),
                ],
              ],
            ),
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(int index) {
    final field = widget.fields[index];
    final isObscure = _obscured[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(field.icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: field.controller,
              obscureText: isObscure,
              keyboardType: field.keyboardType,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: field.label,
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: field.obscureText
                    ? GestureDetector(
                        onTap: () => setState(() => _obscured[index] = !isObscure),
                        child: Icon(
                          isObscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Components ────────────────────────────────────────────────────

class _HeroProfile extends StatelessWidget {
  final String name;
  final String email;
  final String role;

  const _HeroProfile({required this.name, required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final Widget child;
  const _OptionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _Row({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1),
      ),
    );
  }
}
