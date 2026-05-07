import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wholesale_customer.dart';
import '../providers/wholesale_provider.dart';
import '../services/format_service.dart';
import '../theme/app_theme.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; // null = all, 'active', 'inactive'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholesaleProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WholesaleCustomer> _filtered(List<WholesaleCustomer> all) {
    return all.where((c) {
      final matchSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery) ||
          (c.companyName?.toLowerCase().contains(_searchQuery) ?? false) ||
          (c.phone?.contains(_searchQuery) ?? false);
      final matchStatus = _statusFilter == null || c.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();
  }

  void _showAddCustomerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddCustomerSheet(
        onSaved: () => context.read<WholesaleProvider>().loadCustomers(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WholesaleProvider>();
    final filtered = _filtered(provider.customers);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Customers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.loadCustomers(),
          ),
        ],
      ),
      floatingActionButton: provider.isOnline
          ? FloatingActionButton(
              onPressed: _showAddCustomerSheet,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          // Offline banner
          if (!provider.isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 14),
                  SizedBox(width: 8),
                  Text(
                    'Offline — showing cached data',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
                  ),
                ],
              ),
            ),

          // Error banner
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => provider.clearError(),
                    child: const Icon(Icons.close, color: AppColors.error, size: 14),
                  ),
                ],
              ),
            ),

          // Search + filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name or company...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusChip(
                  label: 'All',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Active',
                  selected: _statusFilter == 'active',
                  color: AppColors.success,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'active' ? null : 'active'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: 'Inactive',
                  selected: _statusFilter == 'inactive',
                  color: AppColors.textMuted,
                  onTap: () => setState(() => _statusFilter = _statusFilter == 'inactive' ? null : 'inactive'),
                ),
              ],
            ),
          ),

          // Summary bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _SummaryChip(
                  label: 'CUSTOMERS',
                  value: '${filtered.length}',
                  icon: Icons.people_rounded,
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  label: 'OUTSTANDING',
                  value: FormatService.formatCurrency(
                    filtered.fold<double>(0, (s, c) => s + c.currentBalance),
                  ),
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.warning,
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => provider.loadCustomers(),
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _CustomerTile(
                            customer: filtered[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CustomerDetailScreen(customer: filtered[i]),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: AppColors.surfaceLight),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty || _statusFilter != null
                    ? 'No matching customers'
                    : 'No customers yet',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _searchQuery.isNotEmpty ? 'Try a different keyword' : 'Tap + to add your first customer',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Customer Tile ─────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final WholesaleCustomer customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final usagePct = customer.creditUsagePercent;
    final isOverLimit = customer.isOverLimit;
    final barColor = isOverLimit
        ? AppColors.error
        : usagePct >= 80
            ? AppColors.warning
            : AppColors.success;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      customer.displayName.isNotEmpty ? customer.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (customer.companyName != null && customer.name != customer.displayName)
                        Text(
                          customer.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: customer.isActive
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    customer.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: customer.isActive ? AppColors.success : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Credit usage bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance: ${FormatService.formatCurrency(customer.currentBalance)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isOverLimit ? AppColors.error : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Limit: ${FormatService.formatCurrency(customer.creditLimit)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: usagePct / 100,
                          minHeight: 5,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
              ],
            ),
            if (customer.phone != null || customer.email != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  if (customer.phone != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(customer.phone!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  if (customer.email != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(customer.email!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Add Customer Sheet ────────────────────────────────────────────────────────

class _AddCustomerSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddCustomerSheet({required this.onSaved});

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'active';
  bool _submitting = false;

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
    final ok = await provider.createCustomer(
      name: _nameController.text.trim(),
      companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      creditLimit: double.tryParse(_creditLimitController.text) ?? 0,
      status: _status,
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
              const Text(
                'NEW CUSTOMER',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Contact Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: 'Company Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
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
                    labelStyle: TextStyle(
                      color: _status == 'active' ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Inactive'),
                    selected: _status == 'inactive',
                    onSelected: (_) => setState(() => _status = 'inactive'),
                    selectedColor: AppColors.textMuted,
                    labelStyle: TextStyle(
                      color: _status == 'inactive' ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
                    : const Text('Create Customer', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? c : AppColors.surfaceLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? c : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryChip({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c)),
                Text(label,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
