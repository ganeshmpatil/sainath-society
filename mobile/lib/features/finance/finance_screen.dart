import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import 'bill_generate_screen.dart';
import 'billing_structure_screen.dart';
import 'chart_of_accounts_screen.dart';
import 'journal_entries_screen.dart';

class _FD extends Equatable {
  final bool loading;
  final double pendingAmount;
  final int unpaidCount;
  final List<Map<String, dynamic>> bills;
  final String? rzpKeyId;
  final bool rzpEnabled;
  const _FD({this.loading = false, this.pendingAmount = 0, this.unpaidCount = 0, this.bills = const [], this.rzpKeyId, this.rzpEnabled = false});
  @override List<Object?> get props => [loading, pendingAmount, unpaidCount, bills, rzpKeyId, rzpEnabled];
}

class _FC extends Cubit<_FD> {
  _FC() : super(const _FD());
  Future<void> load([String? status]) async {
    emit(const _FD(loading: true));
    try {
      final futures = await Future.wait([
        api.get('/finance/bills/pending-dues').catchError((_) => Response(requestOptions: RequestOptions(), data: <String, dynamic>{})),
        api.get('/finance/bills', queryParams: status != null && status.isNotEmpty ? {'status': status} : null).catchError((_) => Response(requestOptions: RequestOptions(), data: <String, dynamic>{})),
        api.get('/payments/config').catchError((_) => Response(requestOptions: RequestOptions(), data: <String, dynamic>{})),
      ]);
      final dues = futures[0].data ?? {};
      final bd = futures[1].data ?? {};
      final cfg = futures[2].data ?? {};
      emit(_FD(
        pendingAmount: (dues['pendingAmount'] ?? 0).toDouble(),
        unpaidCount: dues['unpaidCount'] ?? 0,
        bills: (bd['bills'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
        rzpKeyId: cfg['keyId'],
        rzpEnabled: cfg['enabled'] == true,
      ));
    } catch (_) { emit(const _FD()); }
  }
}

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(create: (_) => _FC()..load(), child: const _FV());
}

class _FV extends StatefulWidget {
  const _FV();
  @override State<_FV> createState() => _FVS();
}

class _FVS extends State<_FV> {
  int _fi = 0;
  static const _fl = ['finance.allBills', 'finance.pending', 'finance.paid', 'finance.overdue'];
  static const _fv = ['', 'ISSUED', 'PAID', 'OVERDUE'];
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  bool get _isAdmin {
    final authState = context.read<AuthBloc>().state;
    return authState is Authenticated && authState.user.role == 'ADMIN';
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    // Show verifying overlay
    _showPaymentOverlay(AppLocalizations.of(context).t('payment.processing'));
    try {
      await api.post('/payments/verify', data: {
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss overlay
        _showPaymentResult(success: true);
        context.read<_FC>().load();
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showPaymentResult(success: false);
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (mounted) {
      _showPaymentResult(success: false, message: response.message);
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {}

  void _showPaymentOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 44, height: 44,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }

  void _showPaymentResult({required bool success, String? message}) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (success ? Colors.green : AppColors.urgent).withAlpha(20),
              ),
              child: Icon(
                success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 40,
                color: success ? Colors.green : AppColors.urgent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.t(success ? 'payment.success' : 'payment.failed'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
            if (!success && message != null && message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            ],
            if (success) ...[
              const SizedBox(height: 8),
              Text(l.t('payment.successDetail'), textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary, decoration: TextDecoration.none, fontWeight: FontWeight.w400)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.green : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l.t('common.ok'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showPayConfirmation(Map<String, dynamic> bill) {
    final l = AppLocalizations.of(context);
    final total = (bill['totalAmount'] ?? 0).toDouble();
    final paid = (bill['amountPaid'] ?? 0).toDouble();
    final due = total - paid;
    final period = bill['billingPeriod'] ?? '';
    final flat = bill['flat'];
    final flatNumber = flat?['flatNumber'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 24),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(20),
            ),
            child: Icon(Icons.payment_rounded, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(l.t('payment.confirmTitle'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _confirmRow(l.t('finance.maintenanceLabel'), period),
              if (flatNumber.isNotEmpty) _confirmRow(l.t('billing.flat'), flatNumber),
              const Divider(height: 20),
              Row(children: [
                Text(l.t('payment.amount'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const Spacer(),
                Text('\u20B9${due.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: AppColors.border),
              ),
              child: Text(l.t('common.cancel'), style: TextStyle(color: AppColors.textSecondary)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _startPayment(bill);
              },
              icon: const Icon(Icons.lock_rounded, size: 16),
              label: Text(l.t('payment.payNow'), style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _confirmRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ]),
  );

  Future<void> _startPayment(Map<String, dynamic> bill) async {
    final l = AppLocalizations.of(context);
    final state = context.read<_FC>().state;
    if (!state.rzpEnabled) {
      _showPaymentResult(success: false, message: l.t('payment.gatewayUnavailable'));
      return;
    }
    _showPaymentOverlay(l.t('payment.processing'));
    try {
      final res = await api.post('/payments/create-order', data: {'billId': bill['id']});
      final data = res.data;
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      _razorpay.open({
        'key': data['razorpayKeyId'],
        'amount': data['amount'],
        'currency': data['currency'],
        'name': 'New Sainath Apartment CHS',
        'description': data['description'],
        'order_id': data['razorpayOrderId'],
        'prefill': {'contact': '', 'email': ''},
        'theme': {'color': '#FF6B35'},
      });
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        final msg = (e is DioException) ? (e.response?.data?['error'] ?? 'Error') : 'Error';
        _showPaymentResult(success: false, message: msg.toString());
      }
    }
  }

  void _showBankDetails() async {
    try {
      final res = await api.get('/payments/bank-details');
      final cfg = res.data?['bankConfig'];
      if (cfg == null || !mounted) return;
      final l = AppLocalizations.of(context);
      showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('payment.bankDetails'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _bankRow(l.t('payment.accountName'), cfg['accountName']),
          _bankRow(l.t('payment.accountNumber'), cfg['accountNumber']),
          _bankRow(l.t('payment.bankName'), cfg['bankName']),
          _bankRow(l.t('payment.branch'), cfg['branchName']),
          _bankRow(l.t('payment.ifsc'), cfg['ifsc']),
          if (cfg['upiId'] != null && cfg['upiId'].toString().isNotEmpty)
            _bankRow(l.t('payment.upi'), cfg['upiId']),
          const SizedBox(height: 16),
        ])));
    } catch (_) {}
  }

  Widget _bankRow(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: Text(value ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  void _showBillDetail(Map<String, dynamic> bill) {
    final l = AppLocalizations.of(context);
    final isMr = context.read<LocaleCubit>().isMarathi;
    final lineItems = (bill['lineItems'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    final status = bill['status'] ?? 'ISSUED';
    final total = (bill['totalAmount'] ?? 0).toDouble();
    final paid = (bill['amountPaid'] ?? 0).toDouble();
    final arrear = (bill['arrearAmount'] ?? 0).toDouble();
    final interest = (bill['interestAmount'] ?? 0).toDouble();
    final period = bill['billingPeriod'] ?? '';
    final flat = bill['flat'];
    final member = bill['member'];
    final flatNumber = flat?['flatNumber'] ?? '';
    final memberName = member?['name'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            // Drag handle
            Center(child: Container(
              width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            )),

            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: status == 'PAID'
                      ? [Colors.green.withAlpha(20), Colors.green.withAlpha(20)]
                      : [AppColors.primary.withAlpha(20), AppColors.secondary.withAlpha(15)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (status == 'PAID' ? Colors.green : AppColors.primary).withAlpha(40)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusColor(status).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long_rounded, size: 22, color: AppColors.statusColor(status)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${l.t('finance.maintenanceLabel')} - $period',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (flatNumber.isNotEmpty || (_isAdmin && memberName.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [if (flatNumber.isNotEmpty) '${l.t('billing.flat')}: $flatNumber', if (_isAdmin && memberName.isNotEmpty) memberName].join(' \u2022 '),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                  ])),
                  StatusBadge.status(status),
                ]),
                if (bill['dueDate'] != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text('${l.t('finance.dueDate')}: ${_formatDate(bill['dueDate'])}',
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // Charges table
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: AppColors.primary.withAlpha(15),
                  child: Row(children: [
                    const SizedBox(width: 28),
                    Expanded(child: Text(l.t('billing.breakdown'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5))),
                    Text(l.t('payment.amount'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                  ]),
                ),

                if (lineItems.isNotEmpty)
                  ...lineItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final label = isMr ? (item['labelMr'] ?? item['label']) : item['label'];
                    final amount = (item['amount'] ?? 0).toDouble();
                    final isArr = item['isArrear'] == true;
                    final isInt = item['isInterest'] == true;
                    final method = item['calcMethod'] ?? '';
                    final rowColor = isArr ? Colors.orange.withAlpha(20) : isInt ? Colors.red.withAlpha(20) : (i.isEven ? AppColors.surface : AppColors.borderLight);
                    final textColor = isArr ? Colors.orange : isInt ? Colors.red.shade300 : AppColors.textPrimary;
                    final icon = isArr ? Icons.history_rounded : isInt ? Icons.percent_rounded : (method == 'PER_SQFT' ? Icons.square_foot_rounded : Icons.tag_rounded);
                    final iconColor = isArr ? Colors.orange : isInt ? Colors.red : (method == 'PER_SQFT' ? Colors.blue : Colors.green);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: rowColor,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: iconColor.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                          child: Icon(icon, size: 13, color: iconColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
                          if (method == 'PER_SQFT')
                            Text('\u20B9${item['rate']} \u00D7 ${(item['quantity'] as num?)?.toStringAsFixed(0) ?? ''} sqft',
                                style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                        ])),
                        Text('\u20B9${amount.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                      ]),
                    );
                  })
                else ...[
                  // Legacy rows
                  ..._legacyRows(l, bill, arrear, interest),
                ],

                // Total row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    border: Border(top: BorderSide(color: AppColors.primary.withAlpha(40), width: 1.5)),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 34),
                    Expanded(child: Text(l.t('finance.totalAmount'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    Text('\u20B9${total.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Payment summary
            if (paid > 0 || (status != 'PAID' && (total - paid) > 0))
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  if (paid > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: Colors.green.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l.t('finance.paid'), style: const TextStyle(fontSize: 13, color: Colors.green))),
                        Text('-\u20B9${paid.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                      ]),
                    ),
                  if (status != 'PAID' && (total - paid) > 0)
                    Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(color: AppColors.urgent.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.pending_rounded, size: 14, color: AppColors.urgent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.t('finance.balanceDue'),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.urgent))),
                      Text('\u20B9${(total - paid).toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.urgent)),
                    ]),
                ]),
              ),

            // Action buttons based on role
            if (status != 'PAID' && (total - paid) > 0) ...[
              const SizedBox(height: 16),
              if (_isAdmin)
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () => _markBillPaid(bill),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(l.t('finance.markPaid')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ))
              else if (context.read<_FC>().state.rzpEnabled)
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _showPayConfirmation(bill); },
                  icon: const Icon(Icons.payment, size: 18),
                  label: Text(l.t('payment.payNow')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _markBillPaid(Map<String, dynamic> bill) async {
    final l = AppLocalizations.of(context);
    final total = (bill['totalAmount'] ?? 0).toDouble();
    final paid = (bill['amountPaid'] ?? 0).toDouble();
    final due = total - paid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('finance.markPaid')),
        content: Text('${l.t('finance.markPaidConfirm')}\n\n\u20B9${due.toStringAsFixed(0)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('common.cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text(l.t('finance.markPaid')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await api.post('/finance/bills/${bill['id']}/mark-paid', data: {'amount': due});
      if (mounted) {
        Navigator.pop(context); // close detail sheet
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.t('finance.markedPaid')),
          backgroundColor: Colors.green,
        ));
        context.read<_FC>().load();
      }
    } catch (e) {
      if (mounted) {
        final msg = (e is DioException) ? (e.response?.data?['error'] ?? 'Error') : 'Error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg'), backgroundColor: Colors.red));
      }
    }
  }

  List<Widget> _legacyRows(AppLocalizations l, Map<String, dynamic> bill, double arrear, double interest) {
    final entries = <MapEntry<String, double>>[];
    final mc = ((bill['maintenanceCharge'] ?? 0) as num).toDouble();
    final sf = ((bill['sinkingFund'] ?? 0) as num).toDouble();
    final rf = ((bill['repairFund'] ?? 0) as num).toDouble();
    final wc = ((bill['waterCharge'] ?? 0) as num).toDouble();
    final oc = ((bill['otherCharges'] ?? 0) as num).toDouble();
    if (mc > 0) entries.add(MapEntry(l.t('finance.monthlyMaintenance'), mc));
    if (sf > 0) entries.add(MapEntry(l.t('finance.sinkingFund'), sf));
    if (rf > 0) entries.add(MapEntry(l.t('finance.repairFund'), rf));
    if (wc > 0) entries.add(MapEntry(l.t('finance.waterCharge'), wc));
    if (oc > 0) entries.add(MapEntry(l.t('finance.otherCharges'), oc));
    if (arrear > 0) entries.add(MapEntry(l.t('finance.arrears'), arrear));
    if (interest > 0) entries.add(MapEntry(l.t('finance.interest'), interest));

    return entries.asMap().entries.map((e) {
      final i = e.key;
      final label = e.value.key;
      final amount = e.value.value;
      final isSpecial = label == l.t('finance.arrears') || label == l.t('finance.interest');
      final color = label == l.t('finance.arrears') ? Colors.orange : label == l.t('finance.interest') ? Colors.red : Colors.green;
      final icon = label == l.t('finance.arrears') ? Icons.history_rounded : label == l.t('finance.interest') ? Icons.percent_rounded : Icons.tag_rounded;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSpecial ? color.withAlpha(20) : (i.isEven ? AppColors.surface : AppColors.borderLight),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: isSpecial ? color : AppColors.textPrimary))),
          Text('\u20B9${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isSpecial ? color : AppColors.textPrimary)),
        ]),
      );
    }).toList();
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
    } catch (_) { return d.toString(); }
  }
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.role == 'ADMIN';

    return Scaffold(body: SafeArea(child: RefreshIndicator(
      onRefresh: () => context.read<_FC>().load(), color: AppColors.primary,
      child: BlocBuilder<_FC, _FD>(builder: (context, state) {
        if (state.loading) return const ShimmerLoading(itemCount: 5);
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('finance.title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(l.t('finance.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]))),

          // Pending dues card
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withAlpha(25), AppColors.secondary.withAlpha(25)]),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(50))),
            child: Column(children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.t(isAdmin ? 'finance.societyPendingDues' : 'finance.myPendingDues'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('\u20B9${state.pendingAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${state.unpaidCount} ${l.t('finance.billsOverdue')}', style: const TextStyle(fontSize: 11, color: AppColors.urgent)),
                ])),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _showBankDetails,
                  icon: const Icon(Icons.account_balance, size: 16),
                  label: Text(l.t('payment.viewBankDetails'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withAlpha(100))),
                )),
              ]),
            ]),
          )),

          // Admin quick actions
          if (isAdmin)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _AdminActionChip(
                  icon: Icons.tune,
                  label: l.t('billing.structure'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingStructureScreen())),
                )),
                const SizedBox(width: 8),
                Expanded(child: _AdminActionChip(
                  icon: Icons.receipt_long,
                  label: l.t('billing.generateBills'),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BillGenerateScreen()));
                    if (mounted) context.read<_FC>().load();
                  },
                )),
              ]),
            )),
          if (isAdmin)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Expanded(child: _AdminActionChip(
                  icon: Icons.account_tree,
                  label: l.t('coa.title'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartOfAccountsScreen())),
                )),
                const SizedBox(width: 8),
                Expanded(child: _AdminActionChip(
                  icon: Icons.book_outlined,
                  label: l.t('journal.title'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalEntriesScreen())),
                )),
              ]),
            )),

          // Filter chips
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12, bottom: 12), child: FilterChipsRow(
            labels: _fl.map((k) => l.t(k)).toList(), selectedIndex: _fi,
            onSelected: (i) { setState(() => _fi = i); context.read<_FC>().load(_fv[i]); },
          ))),
          if (state.bills.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary))))),
          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _BC(
            bill: state.bills[i],
            rzpEnabled: state.rzpEnabled,
            isAdmin: isAdmin,
            onPay: () => _showPayConfirmation(state.bills[i]),
            onTap: () => _showBillDetail(state.bills[i]),
          ), childCount: state.bills.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]);
      }),
    )));
  }
}

// ─── Admin Action Chip ──────────────────────────────────────────

class _AdminActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AdminActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withAlpha(15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}

// ─── Bill Card ──────────────────────────────────────────────────

class _BC extends StatelessWidget {
  final Map<String, dynamic> bill;
  final bool rzpEnabled;
  final bool isAdmin;
  final VoidCallback onPay;
  final VoidCallback onTap;
  const _BC({required this.bill, required this.rzpEnabled, this.isAdmin = false, required this.onPay, required this.onTap});
  @override Widget build(BuildContext context) {
    final status = bill['status'] ?? 'ISSUED';
    final amount = (bill['totalAmount'] ?? 0).toDouble();
    final paid = (bill['amountPaid'] ?? 0).toDouble();
    final arrear = (bill['arrearAmount'] ?? 0).toDouble();
    final period = bill['billingPeriod'] ?? '';
    final sc = AppColors.statusColor(status);
    final isPaid = status == 'PAID';
    final due = amount - paid;
    final hasArrear = arrear > 0;
    final flat = bill['flat'];
    final member = bill['member'];
    final flatNumber = flat?['flatNumber'] ?? '';
    final memberName = member?['name'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: sc.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.currency_rupee_rounded, size: 20, color: sc)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${AppLocalizations.of(context).t('finance.maintenanceLabel')} - $period', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            if (isAdmin && (flatNumber.isNotEmpty || memberName.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  [if (flatNumber.isNotEmpty) flatNumber, if (memberName.isNotEmpty) memberName].join(' \u2022 '),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Row(children: [
              Text('\u20B9${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              if (hasArrear)
                Text('  (${AppLocalizations.of(context).t('finance.inclArrears')})', style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
            ]),
          ])),
          StatusBadge.status(status),
        ]),
        if (!isPaid && due > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            Text('${AppLocalizations.of(context).t('finance.dueLabel')}: \u20B9${due.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.urgent)),
            const Spacer(),
            if (rzpEnabled && !isAdmin)
              SizedBox(height: 32, child: ElevatedButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payment, size: 14),
                label: Text(AppLocalizations.of(context).t('payment.payNow'), style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
          ]),
        ],
      ])),
    );
  }
}
