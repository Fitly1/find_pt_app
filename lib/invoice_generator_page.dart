// File: invoice_generator_page.dart
//
// Generates, previews and prints a PDF invoice for an active trainer.
//
// ---------------------------------------------------------------------------

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceGeneratorPage extends StatefulWidget {
  final String trainerId;

  const InvoiceGeneratorPage({
    super.key,
    required this.trainerId,
  });

  @override
  State<InvoiceGeneratorPage> createState() => _InvoiceGeneratorPageState();
}

class _InvoiceGeneratorPageState extends State<InvoiceGeneratorPage> {
  /* ─────────────────────────  STATE  ───────────────────────── */

  bool _loading = true;
  bool _isActive = false;
  String? _error;

  String? _logoUrl;

  final _formKey = GlobalKey<FormState>();

  // Business details controllers
  final _bizNameCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  // Invoice details controllers
  final _clientCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _invoiceDate = DateTime.now();

  /* ───────────────────────  LIFECYCLE  ─────────────────────── */

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _bizNameCtrl.dispose();
    _abnCtrl.dispose();
    _addrCtrl.dispose();
    _emailCtrl.dispose();
    _bankCtrl.dispose();
    _clientCtrl.dispose();
    _serviceCtrl.dispose();
    _hoursCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /* ─────────────────────  FIRESTORE FETCH  ───────────────────── */

  Future<void> _fetchData() async {
    try {
      final trainerDoc = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(widget.trainerId)
          .get();

      if (!trainerDoc.exists) {
        _error = 'Trainer profile not found.';
        _loading = false;
        setState(() {});
        return;
      }

      final data = trainerDoc.data()!;
      _isActive = (data['isActive'] ?? false) == true;

      if (_isActive) {
        final inv = data['invoiceSettings'] is Map
            ? Map<String, dynamic>.from(data['invoiceSettings'])
            : <String, dynamic>{};

        _bizNameCtrl.text = inv['businessName'] ?? '';
        _abnCtrl.text = inv['abn'] ?? '';
        _addrCtrl.text = inv['address'] ?? '';
        _emailCtrl.text = inv['email'] ?? '';
        _bankCtrl.text = inv['bankDetails'] ?? '';
        _logoUrl = inv['logoUrl'] as String?;
      }
    } catch (e) {
      _error = 'Failed to load data: ${e.toString()}';
    }

    if (mounted) setState(() => _loading = false);
  }

  /* ────────────────────────  HELPERS  ───────────────────────── */

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFFA726)),
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  /* ─────────────────────  PDF GENERATION  ───────────────────── */

  Future<void> _generateInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final biz = _bizNameCtrl.text.trim();
    final abn = _abnCtrl.text.trim();
    final addr = _addrCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final bank = _bankCtrl.text.trim();

    final client = _clientCtrl.text.trim();
    final desc = _serviceCtrl.text.trim();
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final total = hours * rate;
    final notes = _notesCtrl.text.trim();

    Uint8List? logoBytes;
    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      try {
        logoBytes =
            await FirebaseStorage.instance.refFromURL(_logoUrl!).getData();
      } catch (_) {}
    }

    final pdf = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), height: 60)),
            if (logoBytes != null) pw.SizedBox(height: 12),
            pw.Text(biz,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (abn.isNotEmpty) pw.Text('ABN: $abn'),
            if (addr.isNotEmpty) pw.Text(addr),
            if (email.isNotEmpty) pw.Text('Email: $email'),
            if (bank.isNotEmpty) pw.Text('Bank: $bank'),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Invoice',
                style:
                    pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Date: ${dateFmt.format(_invoiceDate)}'),
            pw.Text('Bill To: $client'),
            pw.SizedBox(height: 24),
            _table(desc, hours, rate, total),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total (incl. GST): \$${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            if (notes.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text('Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(notes),
            ],
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      name: 'invoice.pdf',
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _table(String desc, double hrs, double rate, double total) =>
      pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              _tblHeader('Description'),
              _tblHeader('Hours'),
              _tblHeader('Rate'),
              _tblHeader('Total'),
            ],
          ),
          pw.TableRow(
            children: [
              _tblCell(desc),
              _tblCell(hrs.toStringAsFixed(2)),
              _tblCell('\$${rate.toStringAsFixed(2)}'),
              _tblCell('\$${total.toStringAsFixed(2)}'),
            ],
          ),
        ],
      );

  pw.Widget _tblHeader(String txt) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child:
            pw.Text(txt, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _tblCell(String txt) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(txt));

  /* ─────────────────────────  FORM WIDGET  ───────────────────────── */

  Widget _buildForm() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_logoUrl != null && _logoUrl!.isNotEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Image.network(
                  _logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                      size: 48, color: Color.fromARGB(255, 255, 255, 255)),
                ),
              ),
            const SizedBox(height: 16),

            // Business details
            TextFormField(
              controller: _bizNameCtrl,
              decoration: _dec('Business Name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _abnCtrl,
              decoration: _dec('ABN'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addrCtrl,
              decoration: _dec('Address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: _dec('Contact Email / Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankCtrl,
              decoration: _dec('Payment Instructions'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Invoice details
            TextFormField(
              controller: _clientCtrl,
              decoration: _dec('Client Name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serviceCtrl,
              decoration: _dec('Service Description *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: _dec('Date'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_invoiceDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Icon(Icons.calendar_today,
                        size: 18, color: Color.fromARGB(255, 255, 249, 249)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hoursCtrl,
              decoration: _dec('Hours'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rateCtrl,
              decoration: _dec('Hourly Rate'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _dec('Additional Notes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );

  /* ─────────────────────────  BUILD  ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFFA726);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invoice'),
        backgroundColor: primary,
      ),

      // 1️⃣ Scrollable content
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : !_isActive
                  ? const Center(
                      child: Text(
                        'This feature is only available to active subscribers.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _buildForm(),
                      ),
                    ),

      // 2️⃣ Pinned action button (always above system nav / home bar)
      bottomNavigationBar: _error == null && _isActive
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                  onPressed: _generateInvoice,
                  child: const Text('Generate Invoice',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            )
          : null,
    );
  }
}
