import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reading_provider.dart';
import '../models/tank.dart';
import '../models/tank_dip.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class TankDipsScreen extends StatefulWidget {
  const TankDipsScreen({super.key});

  @override
  State<TankDipsScreen> createState() => _TankDipsScreenState();
}

class _TankDipsScreenState extends State<TankDipsScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  List<TankDip> _dips = [];
  List<Tank> _tanks = [];
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

    final isOnline = context.read<ReadingProvider>().isOnline;
    List<TankDip> dips = [];
    List<Tank> tanks = [];
    String? dipError;

    if (!isOnline) {
      // Offline: serve from cache directly
      final cached = await _databaseService.getCachedTankDips();
      dips = cached.map(_rowToDip).toList();
      if (!mounted) return;
      setState(() {
        _dips = dips;
        _tanks = tanks;
        _error = null;
        _isLoading = false;
      });
      return;
    }

    // Online: load from API, cache result; fall back to cache on failure
    await Future.wait([
      () async {
        try {
          dips = (await _apiService.getTankDips()).map(TankDip.fromJson).toList();
          await _databaseService.upsertTankDips(dips.map(_dipToRow).toList());
        } on ApiException catch (e) {
          dipError = e.message;
          final cached = await _databaseService.getCachedTankDips();
          if (cached.isNotEmpty) dips = cached.map(_rowToDip).toList();
        } catch (_) {
          dipError = 'Failed to load tank dips.';
          final cached = await _databaseService.getCachedTankDips();
          if (cached.isNotEmpty) dips = cached.map(_rowToDip).toList();
        }
      }(),
      () async {
        try {
          tanks = (await _apiService.getTanks()).map(Tank.fromJson).toList();
        } catch (_) {
          // Non-critical: only affects new dip creation
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _dips = dips;
      _tanks = tanks;
      _error = dipError;
      _isLoading = false;
    });
  }

  // ── Row Mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _dipToRow(TankDip d) => {
        'id': d.id,
        'tank_id': d.tankId,
        'station_id': d.stationId,
        'recorded_by': d.recordedBy,
        'date': d.date,
        'opening_dip': d.openingDip,
        'closing_dip': d.closingDip,
        'deliveries_received': d.deliveriesReceived,
        'volume_dispensed': d.volumeDispensed,
        'expected_closing': d.expectedClosing,
        'variance': d.variance,
        'status': d.status,
        'notes': d.notes,
        'created_at': d.createdAt.toIso8601String(),
      };

  TankDip _rowToDip(Map<String, dynamic> r) => TankDip(
        id: r['id'] as int,
        tankId: r['tank_id'] as int,
        stationId: r['station_id'] as int,
        recordedBy: r['recorded_by'] as int,
        date: r['date'] as String,
        openingDip: (r['opening_dip'] as num).toDouble(),
        closingDip: r['closing_dip'] != null ? (r['closing_dip'] as num).toDouble() : null,
        deliveriesReceived: (r['deliveries_received'] as num).toDouble(),
        volumeDispensed: (r['volume_dispensed'] as num).toDouble(),
        expectedClosing: r['expected_closing'] != null ? (r['expected_closing'] as num).toDouble() : null,
        variance: r['variance'] != null ? (r['variance'] as num).toDouble() : null,
        status: r['status'] as String? ?? 'open',
        notes: r['notes'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  void _showNewDipSheet() {
    if (_tanks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tanks found. Configure tanks first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _NewDipSheet(
        tanks: _tanks,
        onCreated: (dip) {
          setState(() => _dips.insert(0, dip));
        },
      ),
    );
  }

  void _showCloseDipSheet(TankDip dip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _CloseDipSheet(
        dip: dip,
        onClosed: (updated) {
          final index = _dips.indexWhere((d) => d.id == updated.id);
          if (index != -1) {
            setState(() => _dips[index] = updated);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ReadingProvider>().isOnline;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'TANK DIPS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: (_isLoading || !isOnline) ? null : _showNewDipSheet,
            tooltip: 'New Dip Reading',
          ),
        ],
      ),
      body: _buildBody(isOnline),
    );
  }

  Widget _buildBody(bool isOnline) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    Widget content;
    if (_error != null) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton(onPressed: isOnline ? _load : null, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_dips.isEmpty) {
      content = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined, size: 48, color: AppColors.surfaceLight),
            SizedBox(height: 12),
            Text(
              'No Tank Dip Records',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    } else {
      content = RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView.builder(
          padding: AppSpacing.pagePadding,
          physics: const BouncingScrollPhysics(),
          itemCount: _dips.length,
          itemBuilder: (context, index) {
            final dip = _dips[index];
            return _TankDipTile(
              dip: dip,
              onClose: (dip.isOpen && isOnline) ? () => _showCloseDipSheet(dip) : null,
            );
          },
        ),
      );
    }

    return Column(
      children: [
        if (!isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.warning.withValues(alpha: 0.1),
            child: const Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 14),
                SizedBox(width: 8),
                Text(
                  'Offline — tank dips require connectivity',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
                ),
              ],
            ),
          ),
        Expanded(child: content),
      ],
    );
  }
}

class _TankDipTile extends StatelessWidget {
  final TankDip dip;
  final VoidCallback? onClose;

  const _TankDipTile({required this.dip, this.onClose});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isOpen = dip.isOpen;
    final statusColor = isOpen ? AppColors.amber : AppColors.success;

    Color? varianceColor;
    if (dip.variance != null) {
      varianceColor = dip.variance! < -100
          ? AppColors.error
          : dip.variance! < 0
              ? AppColors.warning
              : AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOpen ? 'OPEN' : 'CLOSED',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tank #${dip.tankId}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                dateFormat.format(DateTime.tryParse(dip.date) ?? DateTime.now()),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DipStat(label: 'OPENING', value: '${FormatService.formatDecimal(dip.openingDip)} L'),
              if (dip.closingDip != null) ...[
                const SizedBox(width: 16),
                _DipStat(label: 'CLOSING', value: '${FormatService.formatDecimal(dip.closingDip!)} L'),
              ],
              if (dip.variance != null) ...[
                const SizedBox(width: 16),
                _DipStat(
                  label: 'VARIANCE',
                  value: '${FormatService.formatDecimal(dip.variance!)} L',
                  color: varianceColor,
                ),
              ],
            ],
          ),
          if (isOpen && onClose != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onClose,
                child: const Text('Close Dip', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DipStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _DipStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _NewDipSheet extends StatefulWidget {
  final List<Tank> tanks;
  final Function(TankDip) onCreated;

  const _NewDipSheet({required this.tanks, required this.onCreated});

  @override
  State<_NewDipSheet> createState() => _NewDipSheetState();
}

class _NewDipSheetState extends State<_NewDipSheet> {
  final ApiService _apiService = ApiService();
  final _openingController = TextEditingController();
  final _notesController = TextEditingController();
  Tank? _selectedTank;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.tanks.isNotEmpty) {
      _selectedTank = widget.tanks.first;
    }
  }

  @override
  void dispose() {
    _openingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = double.tryParse(_openingController.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid opening dip value'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_selectedTank == null) return;

    setState(() => _isSubmitting = true);
    try {
      final raw = await _apiService.storeTankDip(
        tankId: _selectedTank!.id,
        date: DateTime.now().toIso8601String().split('T')[0],
        openingDip: value,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      final dip = TankDip.fromJson(raw);
      if (mounted) {
        widget.onCreated(dip);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dip opened', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text(
            'NEW DIP READING',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),

          // Tank selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<Tank>(
              value: _selectedTank,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              underline: const SizedBox.shrink(),
              items: widget.tanks.map((tank) {
                return DropdownMenuItem<Tank>(
                  value: tank,
                  child: Text(
                    '${tank.displayName} (${FormatService.formatDecimal(tank.currentLevel)} L)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (tank) => setState(() => _selectedTank = tank),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _openingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              labelText: 'OPENING DIP (L)',
              labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              suffixText: 'L',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'NOTES (optional)'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : const Text('OPEN DIP'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseDipSheet extends StatefulWidget {
  final TankDip dip;
  final Function(TankDip) onClosed;

  const _CloseDipSheet({required this.dip, required this.onClosed});

  @override
  State<_CloseDipSheet> createState() => _CloseDipSheetState();
}

class _CloseDipSheetState extends State<_CloseDipSheet> {
  final ApiService _apiService = ApiService();
  final _closingController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _closingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = double.tryParse(_closingController.text);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid closing dip value'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final raw = await _apiService.closeTankDip(
        widget.dip.id,
        closingDip: value,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      final updated = TankDip.fromJson(raw);
      if (mounted) {
        widget.onClosed(updated);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dip closed', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text(
            'CLOSE DIP READING',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Opening: ${FormatService.formatDecimal(widget.dip.openingDip)} L',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _closingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              labelText: 'CLOSING DIP (L)',
              labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
              suffixText: 'L',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'NOTES (optional)'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                    )
                  : const Text('CLOSE DIP'),
            ),
          ),
        ],
      ),
    );
  }
}
