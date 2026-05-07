import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reading_provider.dart';
import '../models/delivery.dart';
import '../models/tank.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  final ApiService _apiService = ApiService();
  final DatabaseService _databaseService = DatabaseService();
  List<Delivery> _deliveries = [];
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
    List<Delivery> deliveries = [];
    List<Tank> tanks = [];
    String? deliveryError;

    if (!isOnline) {
      // Offline: serve from cache directly
      final cached = await _databaseService.getCachedDeliveries();
      deliveries = cached.map(_rowToDelivery).toList();
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
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
          deliveries = (await _apiService.getDeliveries()).map(Delivery.fromJson).toList();
          await _databaseService.upsertDeliveries(deliveries.map(_deliveryToRow).toList());
        } on ApiException catch (e) {
          deliveryError = e.message;
          final cached = await _databaseService.getCachedDeliveries();
          if (cached.isNotEmpty) deliveries = cached.map(_rowToDelivery).toList();
        } catch (_) {
          deliveryError = 'Failed to load deliveries.';
          final cached = await _databaseService.getCachedDeliveries();
          if (cached.isNotEmpty) deliveries = cached.map(_rowToDelivery).toList();
        }
      }(),
      () async {
        try {
          tanks = (await _apiService.getTanks()).map(Tank.fromJson).toList();
        } catch (_) {
          // Non-critical: only affects adding new deliveries
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _deliveries = deliveries;
      _tanks = tanks;
      _error = deliveryError;
      _isLoading = false;
    });
  }

  // ── Row Mapping ────────────────────────────────────────────────────────────

  Map<String, dynamic> _deliveryToRow(Delivery d) => {
        'id': d.id,
        'station_id': d.stationId,
        'tank_id': d.tankId,
        'product_type': d.productType,
        'quantity': d.quantity,
        'actual_received_volume': d.actualReceivedVolume,
        'unit_price': d.unitPrice,
        'total_amount': d.totalAmount,
        'supplier_name': d.supplierName,
        'delivery_note_number': d.deliveryNoteNumber,
        'delivered_at': d.deliveredAt.toIso8601String(),
        'notes': d.notes,
        'created_at': d.createdAt.toIso8601String(),
      };

  Delivery _rowToDelivery(Map<String, dynamic> r) => Delivery(
        id: r['id'] as int,
        stationId: r['station_id'] as int,
        tankId: r['tank_id'] as int,
        productType: r['product_type'] as String,
        quantity: (r['quantity'] as num).toDouble(),
        actualReceivedVolume: r['actual_received_volume'] != null
            ? (r['actual_received_volume'] as num).toDouble()
            : null,
        unitPrice: (r['unit_price'] as num).toDouble(),
        totalAmount: (r['total_amount'] as num).toDouble(),
        supplierName: r['supplier_name'] as String,
        deliveryNoteNumber: r['delivery_note_number'] as String?,
        deliveredAt: DateTime.tryParse(r['delivered_at'] as String? ?? '') ?? DateTime.now(),
        notes: r['notes'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  void _showAddDeliverySheet() {
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
      builder: (ctx) => _AddDeliverySheet(
        tanks: _tanks,
        onSaved: (delivery) {
          setState(() => _deliveries.insert(0, delivery));
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
          'DELIVERIES',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: (_isLoading || !isOnline) ? null : _showAddDeliverySheet,
            tooltip: 'Log Delivery',
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
    } else if (_deliveries.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping_outlined, size: 48, color: AppColors.surfaceLight),
            const SizedBox(height: 12),
            const Text(
              'No Deliveries',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isOnline ? _showAddDeliverySheet : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Log Delivery'),
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
          itemCount: _deliveries.length,
          itemBuilder: (context, index) {
            return _DeliveryTile(delivery: _deliveries[index]);
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
                  'Offline — deliveries require connectivity',
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

class _DeliveryTile extends StatelessWidget {
  final Delivery delivery;

  const _DeliveryTile({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.supplierName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${delivery.productType} • ${FormatService.formatDecimal(delivery.quantity)} L',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  dateFormat.format(delivery.deliveredAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatService.formatCurrency(delivery.totalAmount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.success),
              ),
              Text(
                '${FormatService.formatCurrency(delivery.unitPrice)}/L',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddDeliverySheet extends StatefulWidget {
  final List<Tank> tanks;
  final Function(Delivery) onSaved;

  const _AddDeliverySheet({required this.tanks, required this.onSaved});

  @override
  State<_AddDeliverySheet> createState() => _AddDeliverySheetState();
}

class _AddDeliverySheetState extends State<_AddDeliverySheet> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final _supplierController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _noteNumberController = TextEditingController();
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
    _supplierController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _noteNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a tank'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final raw = await _apiService.storeDelivery(
        tankId: _selectedTank!.id,
        productType: _selectedTank!.productType,
        quantity: double.parse(_quantityController.text),
        unitPrice: double.parse(_unitPriceController.text),
        supplierName: _supplierController.text.trim(),
        deliveryNoteNumber: _noteNumberController.text.trim().isNotEmpty
            ? _noteNumberController.text.trim()
            : null,
        deliveredAt: DateTime.now().toIso8601String().split('T')[0],
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      final delivery = Delivery.fromJson(raw);
      if (mounted) {
        widget.onSaved(delivery);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery logged', style: TextStyle(fontWeight: FontWeight.w700)),
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'LOG DELIVERY',
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
                child: DropdownButtonFormField<Tank>(
                  value: _selectedTank,
                  decoration: const InputDecoration(
                    labelText: 'TANK',
                    labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
                    border: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                  dropdownColor: AppColors.surface,
                  items: widget.tanks.map((tank) {
                    return DropdownMenuItem<Tank>(
                      value: tank,
                      child: Text(
                        '${tank.displayName} (${FormatService.formatDecimal(tank.currentLevel)}/${FormatService.formatDecimal(tank.capacity)} L)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (tank) => setState(() => _selectedTank = tank),
                  validator: (v) => v == null ? 'REQUIRED' : null,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'SUPPLIER NAME'),
                style: const TextStyle(fontWeight: FontWeight.w600),
                validator: (v) => (v == null || v.isEmpty) ? 'REQUIRED' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'QUANTITY (L)', suffixText: 'L'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'REQUIRED';
                        if (double.tryParse(v) == null) return 'INVALID';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'UNIT PRICE', prefixText: '₦'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'REQUIRED';
                        if (double.tryParse(v) == null) return 'INVALID';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _noteNumberController,
                decoration: const InputDecoration(labelText: 'DELIVERY NOTE # (optional)'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'NOTES (optional)'),
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
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
                      : const Text('LOG DELIVERY'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
