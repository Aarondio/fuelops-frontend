import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final ApiService _apiService = ApiService();
  final _whatsappController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool _alertEnabled = true;
  double _varianceThresholdPercent = 2.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.getAlertSettings();
      if (!mounted) return;
      setState(() {
        _alertEnabled = data['alertEnabled'] as bool? ?? true;
        _varianceThresholdPercent = (data['varianceThresholdPercent'] as num?)?.toDouble() ?? 2.0;
        _whatsappController.text = data['whatsappNumber'] as String? ?? '';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load alert settings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _apiService.updateAlertSettings(
        alertEnabled: _alertEnabled,
        varianceThresholdPercent: _varianceThresholdPercent,
        whatsappNumber: _whatsappController.text.trim().isNotEmpty
            ? _whatsappController.text.trim()
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ALERT SETTINGS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      padding: AppSpacing.pagePadding,
      physics: const BouncingScrollPhysics(),
      children: [
        // Enable/disable alerts
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Alerts Enabled',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'Send WhatsApp/SMS alerts on variance',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _alertEnabled,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _alertEnabled = val),
          ),
        ),

        const SizedBox(height: 24),
        _SectionLabel(text: 'Variance Threshold'),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Alert when variance exceeds',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_varianceThresholdPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _varianceThresholdPercent,
                min: 0.5,
                max: 10.0,
                divisions: 19,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.surfaceLight,
                onChanged: (val) => setState(() => _varianceThresholdPercent = val),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('0.5%', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  Text('10%', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _SectionLabel(text: 'WhatsApp Notifications'),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            decoration: const InputDecoration(
              labelText: 'WHATSAPP NUMBER',
              labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              hintText: '+234 800 000 0000',
              prefixIcon: Icon(Icons.phone_rounded, size: 18, color: AppColors.textMuted),
              border: InputBorder.none,
              fillColor: Colors.transparent,
            ),
          ),
        ),

        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : const Text('SAVE SETTINGS'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1),
      ),
    );
  }
}

// Alert Logs screen embedded at bottom of this file for proximity
class AlertLogsScreen extends StatefulWidget {
  const AlertLogsScreen({super.key});

  @override
  State<AlertLogsScreen> createState() => _AlertLogsScreenState();
}

class _AlertLogsScreenState extends State<AlertLogsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await _apiService.getAlertLogs();
      if (!mounted) return;
      setState(() => _logs = raw);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load alert logs.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ALERT LOGS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 48, color: AppColors.surfaceLight),
            SizedBox(height: 12),
            Text(
              'No Alert Logs',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _load,
      child: ListView.builder(
        padding: AppSpacing.pagePadding,
        physics: const BouncingScrollPhysics(),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          final status = log['status'] as String? ?? 'unknown';
          final channel = log['channel'] as String? ?? '';
          final sentAt = log['sentAt'] != null
              ? DateFormat('MMM d, HH:mm').format(DateTime.tryParse(log['sentAt'] as String) ?? DateTime.now())
              : '—';
          final isSuccess = status == 'sent';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isSuccess ? AppColors.success : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Text(
                        log['recipient'] as String? ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: isSuccess ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sentAt,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
