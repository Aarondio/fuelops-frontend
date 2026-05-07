import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/wholesale_customer.dart';
import '../models/wholesale_transaction.dart';
import '../providers/wholesale_provider.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';

class CustomerDetailScreen extends StatefulWidget {
  final WholesaleCustomer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  // Local copy — refreshed after updates
  late WholesaleCustomer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholesaleProvider>().loadTransactions(customerId: _customer.id);
    });
  }

  void _showEditCustomerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditCustomerSheet(
        customer: _customer,
        onSaved: (updated) {
          setState(() => _customer = updated);
        },
      ),
    );
  }

  void _showNewTransactionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewTransactionSheet(
        customer: _customer,
        onSaved: () => context.read<WholesaleProvider>().loadTransactions(customerId: _customer.id),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<WholesaleProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Customer', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: Text(
          'Delete ${_customer.displayName}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok = await provider.deleteCustomer(_customer.id);
      if (ok && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WholesaleProvider>();
    final transactions = provider.transactions.where((t) => t.wholesaleCustomerId == _customer.id).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _customer.displayName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (provider.isOnline) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: _showEditCustomerSheet,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
      floatingActionButton: provider.isOnline
          ? FloatingActionButton.extended(
              onPressed: _showNewTransactionSheet,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            )
          : null,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => provider.loadTransactions(customerId: _customer.id),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Offline indicator
                  if (!provider.isOnline)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 14),
                          SizedBox(width: 8),
                          Text('Offline — cached data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
                        ],
                      ),
                    ),

                  // Error
                  if (provider.error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(provider.error!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
                    ),

                  const SizedBox(height: 16),

                  // Credit header card
                  _buildCreditCard(),

                  const SizedBox(height: 16),

                  // Contact details
                  _buildContactSection(),

                  const SizedBox(height: 16),

                  // Transaction summary
                  _buildTransactionSummary(transactions),

                  const SizedBox(height: 16),

                  // Transaction list
                  const _SectionTitle(title: 'ORDER HISTORY'),
                  const SizedBox(height: 8),

                  if (transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.surfaceLight),
                          const SizedBox(height: 8),
                          const Text('No orders yet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const Text('Tap "+ New Order" to record one', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  else
                    ...transactions.map((tx) => _TransactionTile(transaction: tx)),
                ],
              ),
            ),
    );
  }

  Widget _buildCreditCard() {
    final usagePct = _customer.creditUsagePercent;
    final isOver = _customer.isOverLimit;
    final barColor = isOver
        ? AppColors.error
        : usagePct >= 80
            ? AppColors.warning
            : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            barColor.withValues(alpha: 0.15),
            barColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: barColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isOver ? 'OVER LIMIT' : _customer.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: barColor, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CreditStatChip(
                  label: 'BALANCE',
                  value: FormatService.formatCurrency(_customer.currentBalance),
                  color: isOver ? AppColors.error : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CreditStatChip(
                  label: 'AVAILABLE',
                  value: FormatService.formatCurrency(_customer.availableCredit.clamp(0, double.infinity)),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CreditStatChip(
                  label: 'LIMIT',
                  value: FormatService.formatCurrency(_customer.creditLimit),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: usagePct / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${usagePct.toStringAsFixed(1)}% of credit used',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    final hasContact = _customer.phone != null || _customer.email != null || _customer.address != null;
    if (!hasContact && _customer.notes == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'CONTACT'),
          const SizedBox(height: 12),
          if (_customer.phone != null)
            _ContactRow(icon: Icons.phone_rounded, text: _customer.phone!),
          if (_customer.email != null)
            _ContactRow(icon: Icons.email_rounded, text: _customer.email!),
          if (_customer.address != null)
            _ContactRow(icon: Icons.location_on_rounded, text: _customer.address!),
          if (_customer.notes != null && _customer.notes!.isNotEmpty)
            _ContactRow(icon: Icons.notes_rounded, text: _customer.notes!),
        ],
      ),
    );
  }

  Widget _buildTransactionSummary(List<WholesaleTransaction> transactions) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    final totalOrders = transactions.length;
    final totalValue = transactions.fold<double>(0, (s, t) => s + t.totalAmount);
    final totalPaid = transactions.fold<double>(0, (s, t) => s + t.amountPaid);
    final totalOutstanding = transactions.fold<double>(0, (s, t) => s + t.outstanding);
    final creditCount = transactions.where((t) => t.isCredit || t.isPartial).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'ACCOUNT SUMMARY'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'ORDERS', value: '$totalOrders', color: AppColors.primary)),
              Container(width: 1, height: 32, color: AppColors.surfaceLight),
              Expanded(child: _MiniStat(label: 'TOTAL VALUE', value: FormatService.formatCurrency(totalValue), color: AppColors.primary)),
              Container(width: 1, height: 32, color: AppColors.surfaceLight),
              Expanded(child: _MiniStat(label: 'OUTSTANDING', value: FormatService.formatCurrency(totalOutstanding), color: totalOutstanding > 0 ? AppColors.warning : AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'TOTAL PAID', value: FormatService.formatCurrency(totalPaid), color: AppColors.success)),
              Container(width: 1, height: 32, color: AppColors.surfaceLight),
              Expanded(child: _MiniStat(label: 'CREDIT ORDERS', value: '$creditCount', color: creditCount > 0 ? AppColors.warning : AppColors.textMuted)),
              Container(width: 1, height: 32, color: AppColors.surfaceLight),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Transaction Tile ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final WholesaleTransaction transaction;

  const _TransactionTile({required this.transaction});

  Color get _statusColor {
    if (transaction.isPaid) return AppColors.success;
    if (transaction.isPartial) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(transaction.transactionDate);
    final provider = context.read<WholesaleProvider>();

    return GestureDetector(
      onTap: provider.isOnline ? () => _showUpdatePaymentSheet(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: transaction.isPaid ? Colors.transparent : _statusColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.referenceNumber ?? 'No Ref',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${FormatService.formatDecimal(transaction.quantity)}L ${transaction.productType} @ ${FormatService.formatCurrency(transaction.unitPrice)}/L',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        transaction.paymentStatus.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _statusColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _AmountChip(label: 'Total', value: FormatService.formatCurrency(transaction.totalAmount), color: AppColors.primary),
                const SizedBox(width: 8),
                _AmountChip(label: 'Paid', value: FormatService.formatCurrency(transaction.amountPaid), color: AppColors.success),
                if (transaction.outstanding > 0) ...[
                  const SizedBox(width: 8),
                  _AmountChip(label: 'Owed', value: FormatService.formatCurrency(transaction.outstanding), color: AppColors.error),
                ],
              ],
            ),
            if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(transaction.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ],
            if (provider.isOnline && !transaction.isPaid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tap to update payment',
                  style: TextStyle(fontSize: 10, color: AppColors.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showUpdatePaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UpdatePaymentSheet(transaction: transaction),
    );
  }
}

// ── Edit Customer Sheet ───────────────────────────────────────────────────────

class _EditCustomerSheet extends StatefulWidget {
  final WholesaleCustomer customer;
  final void Function(WholesaleCustomer updated) onSaved;

  const _EditCustomerSheet({required this.customer, required this.onSaved});

  @override
  State<_EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends State<_EditCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _notesController;
  late String _status;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c.name);
    _companyController = TextEditingController(text: c.companyName ?? '');
    _phoneController = TextEditingController(text: c.phone ?? '');
    _emailController = TextEditingController(text: c.email ?? '');
    _addressController = TextEditingController(text: c.address ?? '');
    _creditLimitController = TextEditingController(text: c.creditLimit.toStringAsFixed(2));
    _notesController = TextEditingController(text: c.notes ?? '');
    _status = c.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final provider = context.read<WholesaleProvider>();
    final ok = await provider.updateCustomer(
      widget.customer.id,
      name: _nameController.text.trim(),
      companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      creditLimit: double.tryParse(_creditLimitController.text),
      status: _status,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    setState(() => _submitting = false);
    if (ok && mounted) {
      // Find updated customer in provider
      final updated = provider.customers.firstWhere(
        (c) => c.id == widget.customer.id,
        orElse: () => widget.customer,
      );
      widget.onSaved(updated);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('EDIT CUSTOMER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Contact Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company Name')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _creditLimitController,
                decoration: const InputDecoration(labelText: 'Credit Limit (₦) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d < 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Status:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Active'),
                    selected: _status == 'active',
                    onSelected: (_) => setState(() => _status = 'active'),
                    selectedColor: AppColors.success,
                    labelStyle: TextStyle(color: _status == 'active' ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Inactive'),
                    selected: _status == 'inactive',
                    onSelected: (_) => setState(() => _status = 'inactive'),
                    selectedColor: AppColors.textMuted,
                    labelStyle: TextStyle(color: _status == 'inactive' ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── New Transaction Sheet ─────────────────────────────────────────────────────

class _NewTransactionSheet extends StatefulWidget {
  final WholesaleCustomer customer;
  final VoidCallback onSaved;

  const _NewTransactionSheet({required this.customer, required this.onSaved});

  @override
  State<_NewTransactionSheet> createState() => _NewTransactionSheetState();
}

class _NewTransactionSheetState extends State<_NewTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
  String _productType = 'PMS';
  String _paymentStatus = 'credit';
  bool _submitting = false;

  double get _total =>
      (double.tryParse(_quantityController.text) ?? 0) *
      (double.tryParse(_unitPriceController.text) ?? 0);

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final amountPaid = _paymentStatus == 'paid'
        ? _total
        : double.tryParse(_amountPaidController.text) ?? 0;

    final ok = await context.read<WholesaleProvider>().createTransaction(
          wholesaleCustomerId: widget.customer.id,
          productType: _productType,
          quantity: double.tryParse(_quantityController.text) ?? 0,
          unitPrice: double.tryParse(_unitPriceController.text) ?? 0,
          paymentStatus: _paymentStatus,
          amountPaid: amountPaid,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
    setState(() => _submitting = false);
    if (ok && mounted) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NEW ORDER — ${widget.customer.displayName.toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1),
              ),
              const SizedBox(height: 16),

              // Product type
              const Text('Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['PMS', 'AGO', 'DPK', 'LPG'].map((p) => ChoiceChip(
                  label: Text(p),
                  selected: _productType == p,
                  onSelected: (_) => setState(() => _productType = p),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _productType == p ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity (L) *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d <= 0) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      decoration: const InputDecoration(labelText: 'Unit Price (₦) *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final d = double.tryParse(v ?? '');
                        if (d == null || d <= 0) return 'Required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // Live total
              if (_total > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: ${FormatService.formatCurrency(_total)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Payment status
              const Text('Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ('paid', 'Paid', AppColors.success),
                  ('partial', 'Partial', AppColors.warning),
                  ('credit', 'Credit', AppColors.error),
                ].map((entry) => ChoiceChip(
                  label: Text(entry.$2),
                  selected: _paymentStatus == entry.$1,
                  onSelected: (_) => setState(() => _paymentStatus = entry.$1),
                  selectedColor: entry.$3,
                  labelStyle: TextStyle(
                    color: _paymentStatus == entry.$1 ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                )).toList(),
              ),

              if (_paymentStatus == 'partial') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountPaidController,
                  decoration: const InputDecoration(labelText: 'Amount Paid (₦) *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (_paymentStatus != 'partial') return null;
                    final d = double.tryParse(v ?? '');
                    if (d == null || d < 0) return 'Enter amount paid';
                    if (_total > 0 && d >= _total) return 'Must be less than total';
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Record Order', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Update Payment Sheet ──────────────────────────────────────────────────────

class _UpdatePaymentSheet extends StatefulWidget {
  final WholesaleTransaction transaction;
  const _UpdatePaymentSheet({required this.transaction});

  @override
  State<_UpdatePaymentSheet> createState() => _UpdatePaymentSheetState();
}

class _UpdatePaymentSheetState extends State<_UpdatePaymentSheet> {
  late String _paymentStatus;
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.transaction.paymentStatus;
    _amountPaidController.text = widget.transaction.amountPaid.toStringAsFixed(2);
    _notesController.text = widget.transaction.notes ?? '';
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final amountPaid = _paymentStatus == 'paid'
        ? widget.transaction.totalAmount
        : double.tryParse(_amountPaidController.text) ?? widget.transaction.amountPaid;

    final ok = await context.read<WholesaleProvider>().updateTransaction(
          widget.transaction.id,
          paymentStatus: _paymentStatus,
          amountPaid: amountPaid,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
    setState(() => _submitting = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'UPDATE PAYMENT — ${widget.transaction.referenceNumber ?? '#${widget.transaction.id}'}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${FormatService.formatCurrency(widget.transaction.totalAmount)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text('Payment Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ('paid', 'Paid', AppColors.success),
              ('partial', 'Partial', AppColors.warning),
              ('credit', 'Credit', AppColors.error),
            ].map((entry) => ChoiceChip(
              label: Text(entry.$2),
              selected: _paymentStatus == entry.$1,
              onSelected: (_) => setState(() => _paymentStatus = entry.$1),
              selectedColor: entry.$3,
              labelStyle: TextStyle(
                color: _paymentStatus == entry.$1 ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            )).toList(),
          ),
          if (_paymentStatus == 'partial') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountPaidController,
              decoration: const InputDecoration(labelText: 'Amount Paid (₦)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Update Payment', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1),
      );
}

class _CreditStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CreditStatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5), textAlign: TextAlign.center),
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
