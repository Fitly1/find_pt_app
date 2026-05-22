// File: invoice_generator_page.dart
// Generates, previews and prints a PDF invoice for an active trainer.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'feature_flags.dart';

class InvoiceGeneratorPage extends StatefulWidget {
  final String trainerId;

  const InvoiceGeneratorPage({super.key, required this.trainerId});

  @override
  State<InvoiceGeneratorPage> createState() => _InvoiceGeneratorPageState();
}

class _InvoiceGeneratorPageState extends State<InvoiceGeneratorPage> {
  /* ───────────────── Fitly colours ───────────────── */
  static const Color _bg = Color(0xFF07080A);
  static const Color _card = Color(0xFF111318);
  static const Color _raised = Color(0xFF171B22);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _goldDeep = Color(0xFFC98E2B);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);
  static const Color _danger = Color(0xFFE05A5A);

  /* ───────────────── State ───────────────── */
  bool _loading = true;
  bool _isActive = false;
  bool _generating = false;
  String? _error;

  String? _logoUrl;
  Uint8List? _logoBytes;

  final _formKey = GlobalKey<FormState>();

  final _bizNameCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  final _clientCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _invoiceDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _bizNameCtrl,
      _abnCtrl,
      _addrCtrl,
      _emailCtrl,
      _bankCtrl,
      _clientCtrl,
      _serviceCtrl,
      _hoursCtrl,
      _rateCtrl,
      _notesCtrl,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  /* ───────────────── Firestore ───────────────── */
  Future<void> _fetchProfile() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(widget.trainerId)
          .get()
          .timeout(const Duration(seconds: 12));

      if (!snap.exists) {
        _error = 'Trainer profile not found.';
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};

      _isActive = (data['isActive'] ?? false) == true;

      if (!isTrainerPaymentsEnabled) {
        _isActive = true;
      }

      if (!_isActive) return;

      final inv = data['invoiceSettings'] is Map
          ? Map<String, dynamic>.from(data['invoiceSettings'])
          : <String, dynamic>{};

      _bizNameCtrl.text = (inv['businessName'] ?? '').toString();
      _abnCtrl.text = (inv['abn'] ?? '').toString();
      _addrCtrl.text = (inv['address'] ?? '').toString();
      _emailCtrl.text = (inv['email'] ?? '').toString();
      _bankCtrl.text = (inv['bankDetails'] ?? '').toString();

      final logo = (inv['logoUrl'] ?? '').toString().trim();
      _logoUrl = logo.isEmpty ? null : logo;
    } catch (e) {
      debugPrint('Invoice profile load error: $e');
      _error = 'Failed to load invoice details.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* ───────────────── Helpers ───────────────── */
  String get _dateLabel => DateFormat('dd/MM/yyyy').format(_invoiceDate);

  double get _hours => double.tryParse(_hoursCtrl.text.trim()) ?? 0;

  double get _rate => double.tryParse(_rateCtrl.text.trim()) ?? 0;

  double get _total => _hours * _rate;

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _raised,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: _textMuted.withValues(alpha: 0.55),
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(
        color: _danger,
        fontWeight: FontWeight.w700,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _gold, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _danger, width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _gold,
              surface: _card,
              onSurface: _textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _invoiceDate = picked);
    }
  }

  Future<Uint8List?> _getLogoBytes() async {
    if (_logoBytes != null || _logoUrl == null || _logoUrl!.isEmpty) {
      return _logoBytes;
    }

    try {
      _logoBytes =
          await FirebaseStorage.instance.refFromURL(_logoUrl!).getData();
    } catch (e) {
      debugPrint('Error downloading logo: $e');
    }

    return _logoBytes;
  }

  /* ───────────────── PDF generation ───────────────── */
  Future<void> _generateInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_generating) return;

    setState(() => _generating = true);

    try {
      final biz = _bizNameCtrl.text.trim();
      final abn = _abnCtrl.text.trim();
      final addr = _addrCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final bank = _bankCtrl.text.trim();

      final client = _clientCtrl.text.trim();
      final desc = _serviceCtrl.text.trim();
      final hours = _hours;
      final rate = _rate;
      final total = _total;
      final notes = _notesCtrl.text.trim();
      final dateStr = _dateLabel;

      final logoBytes = await _getLogoBytes();

      final ByteData robotoBD =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final ByteData robotoBoldBD =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

      final baseFont = pw.Font.ttf(robotoBD);
      final boldFont = pw.Font.ttf(robotoBoldBD);
      final pdf = pw.Document();

      pw.TextStyle style(
          {bool bold = false, double size = 12, PdfColor? color}) {
        return pw.TextStyle(
          font: bold ? boldFont : baseFont,
          fontSize: size,
          color: color ?? PdfColors.black,
        );
      }

      pw.Widget text(
        String value, {
        bool bold = false,
        double size = 12,
        PdfColor? color,
      }) {
        return pw.Text(value,
            style: style(bold: bold, size: size, color: color));
      }

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(32),
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          text('INVOICE', bold: true, size: 26),
                          pw.SizedBox(height: 8),
                          text('Date: $dateStr', color: PdfColors.grey700),
                          text('Bill To: $client', color: PdfColors.grey700),
                        ],
                      ),
                    ),
                    if (logoBytes != null)
                      pw.Container(
                        height: 58,
                        width: 58,
                        child: pw.Image(pw.MemoryImage(logoBytes),
                            fit: pw.BoxFit.contain),
                      ),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text(biz, bold: true, size: 15),
                      if (abn.isNotEmpty)
                        text('ABN: $abn', color: PdfColors.grey700),
                      if (addr.isNotEmpty) text(addr, color: PdfColors.grey700),
                      if (email.isNotEmpty)
                        text(email, color: PdfColors.grey700),
                      if (bank.isNotEmpty)
                        text('Payment: $bank', color: PdfColors.grey700),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey400, width: 0.7),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3),
                    1: pw.FlexColumnWidth(1),
                    2: pw.FlexColumnWidth(1),
                    3: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfCell('Description',
                            bold: true, textStyle: style(bold: true)),
                        _pdfCell('Hours',
                            bold: true, textStyle: style(bold: true)),
                        _pdfCell('Rate',
                            bold: true, textStyle: style(bold: true)),
                        _pdfCell('Total',
                            bold: true, textStyle: style(bold: true)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfCell(desc, textStyle: style()),
                        _pdfCell(hours.toStringAsFixed(2), textStyle: style()),
                        _pdfCell('\$${rate.toStringAsFixed(2)}',
                            textStyle: style()),
                        _pdfCell('\$${total.toStringAsFixed(2)}',
                            textStyle: style()),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey900,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      bold: true,
                      size: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: 24),
                  text('Notes', bold: true),
                  pw.SizedBox(height: 5),
                  text(notes, color: PdfColors.grey700),
                ],
              ],
            );
          },
        ),
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              title: const Text(
                'Invoice Preview',
                style: TextStyle(color: _textMain, fontWeight: FontWeight.w800),
              ),
              backgroundColor: _bg,
              iconTheme: const IconThemeData(color: _textMain),
              surfaceTintColor: Colors.transparent,
            ),
            body: PdfPreview(
              build: (format) => pdf.save(),
              useActions: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  pw.Widget _pdfCell(
    String value, {
    required pw.TextStyle textStyle,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(value, style: textStyle),
    );
  }

  /* ───────────────── UI ───────────────── */
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            logoUrl: _logoUrl,
            title: 'Create invoice',
            subtitle:
                'Fill in the client and session details, then preview the PDF.',
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Your business details',
            subtitle: 'Pulled from your saved invoice setup.',
            child: Column(
              children: [
                TextFormField(
                  controller: _bizNameCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Business name *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _abnCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('ABN'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addrCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Address'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Contact email / phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Payment instructions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Invoice details',
            subtitle: 'Client, service and pricing for this invoice.',
            child: Column(
              children: [
                TextFormField(
                  controller: _clientCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Client name *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _serviceCtrl,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Service description *',
                      hint: 'e.g. 1:1 personal training session'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: _dec('Date'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dateLabel,
                          style: const TextStyle(
                            color: _textMain,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded,
                            size: 18, color: _gold),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hoursCtrl,
                        cursorColor: _gold,
                        style: const TextStyle(
                            color: _textMain, fontWeight: FontWeight.w600),
                        decoration: _dec('Hours'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _rateCtrl,
                        cursorColor: _gold,
                        style: const TextStyle(
                            color: _textMain, fontWeight: FontWeight.w600),
                        decoration: _dec('Hourly rate'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  cursorColor: _gold,
                  style: const TextStyle(
                      color: _textMain, fontWeight: FontWeight.w600),
                  decoration: _dec('Additional notes'),
                ),
                const SizedBox(height: 14),
                _TotalPreview(total: _total),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(color: _gold),
    );
  }

  Widget _messageView(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, color: _gold, size: 34),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Generate Invoice',
          style: TextStyle(
            color: _textMain,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _textMain),
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? _loadingView()
          : _error != null
              ? _messageView('Invoice unavailable', _error!)
              : !_isActive
                  ? _messageView(
                      'Invoice locked',
                      'This feature is only available to active subscribers.',
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                        child: _buildForm(),
                      ),
                    ),
      bottomNavigationBar: _error == null && _isActive && !_loading
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_gold, _goldDeep],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF121212),
                      disabledBackgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _generating ? null : _generateInvoice,
                    child: _generating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: _textMain,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Text(
                            'Preview invoice',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String? logoUrl;
  final String title;
  final String subtitle;

  const _HeaderCard({
    required this.logoUrl,
    required this.title,
    required this.subtitle,
  });

  static const Color _card = Color(0xFF111318);
  static const Color _border = Color(0xFF303540);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _border),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasLogo
                ? Image.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(Icons.receipt_long_rounded,
                          color: _gold);
                    },
                  )
                : const Icon(Icons.receipt_long_rounded,
                    color: _gold, size: 30),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 13.1,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  static const Color _card = Color(0xFF111318);
  static const Color _border = Color(0xFF303540);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13.1,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TotalPreview extends StatelessWidget {
  final double total;

  const _TotalPreview({required this.total});

  static const Color _raised = Color(0xFF171B22);
  static const Color _gold = Color(0xFFE7B95C);
  static const Color _textMain = Color(0xFFF5F6F8);
  static const Color _textMuted = Color(0xFFA6ADB8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: _raised,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_rounded, color: _gold, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Estimated total',
              style: TextStyle(
                color: _textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _textMain,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
