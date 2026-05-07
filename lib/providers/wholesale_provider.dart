import 'package:flutter/material.dart';
import '../models/wholesale_customer.dart';
import '../models/wholesale_transaction.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

class WholesaleProvider extends ChangeNotifier {
  final ApiService _apiService;
  final ConnectivityService _connectivityService;
  final DatabaseService _databaseService;

  List<WholesaleCustomer> _customers = [];
  List<WholesaleTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPrefetching = false;
  String? _error;

  List<WholesaleCustomer> get customers => _customers;
  List<WholesaleTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get isOnline => _connectivityService.isConnected;

  WholesaleProvider({
    required ApiService apiService,
    required ConnectivityService connectivityService,
    required DatabaseService databaseService,
  })  : _apiService = apiService,
        _connectivityService = connectivityService,
        _databaseService = databaseService;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Customers ────────────────────────────────────────────────────────────

  Future<void> loadCustomers({String? search, String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (isOnline) {
        final raw = await _apiService.getWholesaleCustomers(search: search, status: status);
        _customers = raw.map(WholesaleCustomer.fromJson).toList();
        // Cache all loaded (no search filter in cache — full dataset only)
        if (search == null && status == null) {
          await _databaseService.upsertWholesaleCustomers(
            _customers.map(_customerToRow).toList(),
          );
        }
      } else {
        final cached = await _databaseService.getCachedWholesaleCustomers(
          search: search,
          status: status,
        );
        _customers = cached.map(_rowToCustomer).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      final cached = await _databaseService.getCachedWholesaleCustomers(search: search, status: status);
      _customers = cached.map(_rowToCustomer).toList();
    } catch (_) {
      _error = 'Failed to load customers.';
      final cached = await _databaseService.getCachedWholesaleCustomers(search: search, status: status);
      if (cached.isNotEmpty) _customers = cached.map(_rowToCustomer).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create — requires connectivity
  Future<bool> createCustomer({
    required String name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    required double creditLimit,
    String status = 'active',
    String? notes,
  }) async {
    if (!isOnline) {
      _error = 'Cannot create customer while offline.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _apiService.createWholesaleCustomer(
        name: name,
        companyName: companyName,
        phone: phone,
        email: email,
        address: address,
        creditLimit: creditLimit,
        status: status,
        notes: notes,
      );
      final customer = WholesaleCustomer.fromJson(raw);
      _customers = [customer, ..._customers];
      await _databaseService.upsertWholesaleCustomers([_customerToRow(customer)]);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Failed to create customer.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update — requires connectivity
  Future<bool> updateCustomer(
    int id, {
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
    String? status,
    String? notes,
  }) async {
    if (!isOnline) {
      _error = 'Cannot update customer while offline.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _apiService.updateWholesaleCustomer(
        id,
        name: name,
        companyName: companyName,
        phone: phone,
        email: email,
        address: address,
        creditLimit: creditLimit,
        status: status,
        notes: notes,
      );
      final updated = WholesaleCustomer.fromJson(raw);
      _customers = _customers.map((c) => c.id == id ? updated : c).toList();
      await _databaseService.upsertWholesaleCustomers([_customerToRow(updated)]);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Failed to update customer.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete — requires connectivity
  Future<bool> deleteCustomer(int id) async {
    if (!isOnline) {
      _error = 'Cannot delete customer while offline.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _apiService.deleteWholesaleCustomer(id);
      _customers = _customers.where((c) => c.id != id).toList();
      _transactions = _transactions.where((t) => t.wholesaleCustomerId != id).toList();
      await _databaseService.deleteWholesaleCustomerFromCache(id);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Failed to delete customer.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<void> loadTransactions({int? customerId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (isOnline) {
        final raw = await _apiService.getWholesaleTransactions(customerId: customerId);
        _transactions = raw.map(WholesaleTransaction.fromJson).toList();
        await _databaseService.upsertWholesaleTransactions(
          _transactions.map(_transactionToRow).toList(),
        );
      } else {
        final cached = await _databaseService.getCachedWholesaleTransactions(customerId: customerId);
        _transactions = cached.map(_rowToTransaction).toList();
      }
    } on ApiException catch (e) {
      _error = e.message;
      final cached = await _databaseService.getCachedWholesaleTransactions(customerId: customerId);
      _transactions = cached.map(_rowToTransaction).toList();
    } catch (_) {
      _error = 'Failed to load transactions.';
      final cached = await _databaseService.getCachedWholesaleTransactions(customerId: customerId);
      if (cached.isNotEmpty) _transactions = cached.map(_rowToTransaction).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create transaction — requires connectivity
  Future<bool> createTransaction({
    required int wholesaleCustomerId,
    required String productType,
    required double quantity,
    required double unitPrice,
    required String paymentStatus,
    double? amountPaid,
    String? notes,
  }) async {
    if (!isOnline) {
      _error = 'Cannot record transaction while offline.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _apiService.createWholesaleTransaction(
        wholesaleCustomerId: wholesaleCustomerId,
        productType: productType,
        quantity: quantity,
        unitPrice: unitPrice,
        paymentStatus: paymentStatus,
        amountPaid: amountPaid,
        notes: notes,
      );
      final tx = WholesaleTransaction.fromJson(raw);
      _transactions = [tx, ..._transactions];
      await _databaseService.upsertWholesaleTransactions([_transactionToRow(tx)]);
      // Refresh customers to get updated balance; suppress any refresh errors
      await loadCustomers();
      _error = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Failed to record transaction.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update payment on existing transaction — requires connectivity
  Future<bool> updateTransaction(
    int id, {
    String? paymentStatus,
    double? amountPaid,
    String? notes,
  }) async {
    if (!isOnline) {
      _error = 'Cannot update transaction while offline.';
      notifyListeners();
      return false;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _apiService.updateWholesaleTransaction(
        id,
        paymentStatus: paymentStatus,
        amountPaid: amountPaid,
        notes: notes,
      );
      final updated = WholesaleTransaction.fromJson(raw);
      _transactions = _transactions.map((t) => t.id == id ? updated : t).toList();
      await _databaseService.upsertWholesaleTransactions([_transactionToRow(updated)]);
      // Refresh customers to get updated balance; suppress any refresh errors
      await loadCustomers();
      _error = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Failed to update transaction.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Offline Prefetch ──────────────────────────────────────────────────────

  /// Silently seed both customers and transactions into SQLite for offline use.
  /// Guard: concurrent calls are no-ops.
  Future<void> prefetchAll() async {
    if (!isOnline || _isPrefetching) return;
    _isPrefetching = true;
    try {
      final customerRaw = await _apiService.getWholesaleCustomers();
      if (customerRaw.isNotEmpty) {
        await _databaseService.upsertWholesaleCustomers(
          customerRaw.map((r) => _customerToRow(WholesaleCustomer.fromJson(r))).toList(),
        );
      }
      final txRaw = await _apiService.getWholesaleTransactions();
      if (txRaw.isNotEmpty) {
        await _databaseService.upsertWholesaleTransactions(
          txRaw.map((r) => _transactionToRow(WholesaleTransaction.fromJson(r))).toList(),
        );
      }
    } catch (_) {
      // Silent failure — prefetch is best-effort
    } finally {
      _isPrefetching = false;
    }
  }

  // ── Row Mapping ───────────────────────────────────────────────────────────

  Map<String, dynamic> _customerToRow(WholesaleCustomer c) => {
        'id': c.id,
        'station_id': c.stationId,
        'name': c.name,
        'company_name': c.companyName,
        'phone': c.phone,
        'email': c.email,
        'address': c.address,
        'credit_limit': c.creditLimit,
        'current_balance': c.currentBalance,
        'status': c.status,
        'notes': c.notes,
        'created_at': c.createdAt.toIso8601String(),
      };

  WholesaleCustomer _rowToCustomer(Map<String, dynamic> r) => WholesaleCustomer(
        id: r['id'] as int,
        stationId: r['station_id'] as int,
        name: r['name'] as String,
        companyName: r['company_name'] as String?,
        phone: r['phone'] as String?,
        email: r['email'] as String?,
        address: r['address'] as String?,
        creditLimit: (r['credit_limit'] as num).toDouble(),
        currentBalance: (r['current_balance'] as num).toDouble(),
        status: r['status'] as String? ?? 'active',
        notes: r['notes'] as String?,
        createdAt: r['created_at'] != null
            ? DateTime.tryParse(r['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> _transactionToRow(WholesaleTransaction t) => {
        'id': t.id,
        'station_id': t.stationId,
        'wholesale_customer_id': t.wholesaleCustomerId,
        'product_type': t.productType,
        'quantity': t.quantity,
        'unit_price': t.unitPrice,
        'total_amount': t.totalAmount,
        'payment_status': t.paymentStatus,
        'amount_paid': t.amountPaid,
        'reference_number': t.referenceNumber,
        'transaction_date': t.transactionDate.toIso8601String(),
        'notes': t.notes,
        'customer_name': t.customer?.name,
        'customer_company_name': t.customer?.companyName,
        'created_at': t.createdAt.toIso8601String(),
      };

  WholesaleTransaction _rowToTransaction(Map<String, dynamic> r) {
    // Reconstruct minimal customer from denormalized columns
    WholesaleCustomer? customer;
    if (r['customer_name'] != null) {
      customer = WholesaleCustomer(
        id: r['wholesale_customer_id'] as int,
        stationId: r['station_id'] as int,
        name: r['customer_name'] as String,
        companyName: r['customer_company_name'] as String?,
        creditLimit: 0,
        currentBalance: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );
    }
    return WholesaleTransaction(
      id: r['id'] as int,
      stationId: r['station_id'] as int,
      wholesaleCustomerId: r['wholesale_customer_id'] as int,
      productType: r['product_type'] as String,
      quantity: (r['quantity'] as num).toDouble(),
      unitPrice: (r['unit_price'] as num).toDouble(),
      totalAmount: (r['total_amount'] as num).toDouble(),
      paymentStatus: r['payment_status'] as String? ?? 'credit',
      amountPaid: (r['amount_paid'] as num? ?? 0).toDouble(),
      referenceNumber: r['reference_number'] as String?,
      transactionDate: r['transaction_date'] != null
          ? DateTime.tryParse(r['transaction_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: r['notes'] as String?,
      customer: customer,
      createdAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
