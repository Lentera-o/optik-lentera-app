import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../assets/optik_brand_assets.dart';
import '../models/optik_models.dart';

class OptikPdfService {
  static const gold = PdfColor.fromInt(0xFF98752A);
  static const pink = PdfColor.fromInt(0xFFF4E7EB);
  static const paper = PdfColor.fromInt(0xFFFFF8F7);
  static const line = PdfColor.fromInt(0xFFDDCBA8);
  static const ink = PdfColor.fromInt(0xFF51484A);
  static pw.MemoryImage get logo => pw.MemoryImage(base64Decode(optikLogoBase64));
  static pw.Widget qr(String value) => pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: value, width: 92, height: 92, drawText: false);

  static String money(int n) => 'Rp ' + n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  static String date(DateTime? d) {
    if (d == null) return '-';
    const months = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
    return d.day.toString().padLeft(2,'0') + ' ' + months[d.month-1] + ' ' + d.year.toString();
  }

  static pw.Widget brand() => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: gold, width: 2))),
    child: pw.Row(children: [
      pw.SizedBox(width: 66, height: 66, child: pw.Image(logo, fit: pw.BoxFit.contain)),
      pw.SizedBox(width: 12),
      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('OPTIK LENTERA', style: pw.TextStyle(fontSize: 20, font: pw.Font.helveticaBold(), color: gold, letterSpacing: 1)),
        pw.Text('Jernih Melihat, Nyaman Melangkah.', style: pw.TextStyle(fontSize: 9, font: pw.Font.helveticaOblique(), color: ink)),
        pw.Text('Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang', style: const pw.TextStyle(fontSize: 7, color: ink)),
        pw.Text('Telp/WA: 0858 9312 8257', style: const pw.TextStyle(fontSize: 7, color: ink)),
      ])),
    ]),
  );

  static pw.Widget heading(String title, String sub) => pw.Column(children: [
    pw.SizedBox(height: 12),
    pw.Text(title, style: pw.TextStyle(fontSize: 19, font: pw.Font.helveticaBold(), color: gold, letterSpacing: 2)),
    pw.SizedBox(height: 3),
    pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: ink)),
    pw.SizedBox(height: 10),
  ]);

  static pw.Widget section(String text) => pw.Container(
    width: double.infinity, margin: const pw.EdgeInsets.only(top: 8, bottom: 5),
    padding: const pw.EdgeInsets.all(6),
    decoration: const pw.BoxDecoration(color: pink, border: pw.Border(left: pw.BorderSide(color: gold, width: 2))),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold(), color: gold)),
  );

  static pw.Widget pair(String label, String? value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(children: [
      pw.SizedBox(width: 105, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: ink))),
      pw.Text(': ', style: const pw.TextStyle(fontSize: 8, color: ink)),
      pw.Expanded(child: pw.Text((value == null || value.isEmpty) ? '-' : value, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: ink))),
    ]),
  );

  static pw.Widget dataTable(List<String> headers, List<List<String>> rows) => pw.Table(
    border: pw.TableBorder.all(color: line, width: .6),
    children: [
      pw.TableRow(decoration: const pw.BoxDecoration(color: pink), children: headers.map((v) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(v, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, font: pw.Font.helveticaBold(), color: gold)))).toList()),
      ...rows.map((r) => pw.TableRow(children: r.map((v) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(v.isEmpty ? '-' : v, style: const pw.TextStyle(fontSize: 8, color: ink)))).toList())),
    ],
  );

  /// Independent examination document. No invoice, payment, signature, or stamp.
  static Future<Uint8List> examinationBytes({
    required String examId,
    required String qrPayload,
    required DateTime examDate,
    required String name,
    required String phone,
    required String address,
    required Map<String, String> values,
  }) async {
    final pdf = pw.Document();
    String v(String key) => (values[key] ?? '').trim().isEmpty ? '—' : values[key]!.trim();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 20),
      build: (_) => pw.Container(
        color: PdfColor.fromInt(0xFFFFFFFF),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            brand(),
            pw.Center(child: heading('HASIL PEMERIKSAAN REFRAKSI', 'RESEP KACAMATA')),
            pw.Row(children: [
              pw.Expanded(child: pair('No. dokumen', examId)),
              pw.SizedBox(width: 18),
              pw.Expanded(child: pair('Tanggal', date(examDate))),
            ]),
            pw.SizedBox(height: 6),
            section('DATA PELANGGAN'),
            pw.Row(children: [
              pw.Expanded(child: pair('Nama pelanggan', name)),
              pw.SizedBox(width: 18),
              pw.Expanded(child: pair('No. HP / WA', phone)),
            ]),
            pair('Alamat', address),
            section('HASIL PEMERIKSAAN'),
            dataTable(['MATA','SPH','CYL','AXIS','ADD','PD'], [
              ['OD • Kanan',v('odSph'),v('odCyl'),v('odAxis'),v('odAdd'),v('odPd')],
              ['OS • Kiri',v('osSph'),v('osCyl'),v('osAxis'),v('osAdd'),v('osPd')],
            ]),
            pair('Jenis lensa', values['lensType']),
            section('CATATAN / REKOMENDASI'),
            pw.Container(
              width: double.infinity,
              constraints: const pw.BoxConstraints(minHeight: 38),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: pink,
                border: pw.Border.all(color: line, width: .6),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(v('note'), style: const pw.TextStyle(fontSize: 8, color: ink)),
            ),
            pw.Spacer(),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(height: .7, color: line),
                pw.SizedBox(height: 5),
                pw.Text('OPTIK LENTERA • Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang • 0858 9312 8257',
                  style: const pw.TextStyle(fontSize: 7, color: ink)),
              ])),
              pw.SizedBox(width: 14),
              pw.Column(children: [
                pw.SizedBox(width: 66, height: 66, child: qr(qrPayload)),
                pw.Text('QR DOKUMEN', style: pw.TextStyle(fontSize: 6, font: pw.Font.helveticaBold(), color: gold)),
              ]),
            ]),
          ],
        ),
      ),
    ));
    return pdf.save();
  }

  static const MethodChannel _pdfSaveChannel = MethodChannel('optik_lentera/pdf_save');

  static Future<String> saveExaminationPdf({
    required String examId,
    required String qrPayload,
    required DateTime examDate,
    required String name,
    required String phone,
    required String address,
    required Map<String, String> values,
  }) async {
    final bytes = await examinationBytes(
      examId: examId, qrPayload: qrPayload, examDate: examDate,
      name: name, phone: phone, address: address, values: values,
    );
    final safeId = examId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileName = 'Hasil_Pemeriksaan_$safeId.pdf';
    final savedPath = await _pdfSaveChannel.invokeMethod<String>(
      'savePdf',
      <String, dynamic>{'fileName': fileName, 'bytes': bytes},
    );
    if (savedPath == null || savedPath.isEmpty) {
      throw Exception('PDF belum berhasil disimpan.');
    }
    return savedPath;
  }

  static Future<Uint8List> invoiceBytes(OptikOrder o, {required int paid, required int remaining}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
      build: (_) => pw.Container(
        color: paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            brand(),
            pw.Center(child: heading('INVOICE', 'RESEP KACAMATA & BUKTI PEMBAYARAN')),
            pair('Nomor invoice', o.invoiceNumber),
            pair('Tanggal', date(o.orderDate)),
            pair('Nama pelanggan', o.customer.name),
            pair('No. HP', o.customer.phone),
            pair('Alamat', o.customer.address),
            pair('Dokter / Optometris', o.prescription.doctor),
            section('01 — RESEP KACAMATA'),
            dataTable(['MATA','SPH','CYL','AXIS','ADD','PD'], [
              ['OD • Kanan',o.prescription.odSph,o.prescription.odCyl,o.prescription.odAxis,o.prescription.odAdd,o.prescription.odPd],
              ['OS • Kiri',o.prescription.osSph,o.prescription.osCyl,o.prescription.osAxis,o.prescription.osAdd,o.prescription.osPd],
            ]),
            pair('Jenis lensa', o.prescription.lensType),
            pair('Catatan resep', o.prescription.note),
            section('02 — RINCIAN PESANAN'),
            dataTable(['ITEM','KETERANGAN','HARGA'], [
              ['Frame',o.frame.description,money(o.frame.price)],
              ['Lensa',o.lens.description,money(o.lens.price)],
              ['Lain-lain',o.other.description,money(o.other.price)],
            ]),
            pw.SizedBox(height: 4),
            pair('TOTAL TAGIHAN', money(o.total)),
            pair('DP AWAL', money(o.initialPayment)),
            pair('TOTAL DIBAYAR', money(paid)),
            pair('SISA TAGIHAN', money(remaining)),
            pair('Metode DP', o.initialPaymentMethod),
            pair('Terbilang', terbilang(o.total) + ' rupiah'),
            pair('Catatan', o.note),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: pink, border: pw.Border.all(color: line)),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(width: 52, height: 52, child: qr(o.invoiceNumber)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Text(
                    'Pindai QR untuk membaca nomor invoice: ' + o.invoiceNumber + '. Terima kasih telah mempercayakan kebutuhan penglihatan Anda kepada OPTIK LENTERA.',
                    textAlign: pw.TextAlign.left,
                    style: const pw.TextStyle(fontSize: 7, color: ink),
                  )),
                ],
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Center(child: pw.Text('OPTIK LENTERA • 0858 9312 8257', style: const pw.TextStyle(fontSize: 6, color: ink))),
          ],
        ),
      ),
    ));
    return pdf.save();
  }

  static String terbilang(int value) {
    const words = ['', 'satu', 'dua', 'tiga', 'empat', 'lima', 'enam', 'tujuh', 'delapan', 'sembilan', 'sepuluh', 'sebelas'];
    String say(int n) {
      if (n < 12) return words[n];
      if (n < 20) return say(n - 10) + ' belas';
      if (n < 100) return say(n ~/ 10) + ' puluh ' + say(n % 10);
      if (n < 200) return 'seratus ' + say(n - 100);
      if (n < 1000) return say(n ~/ 100) + ' ratus ' + say(n % 100);
      if (n < 2000) return 'seribu ' + say(n - 1000);
      if (n < 1000000) return say(n ~/ 1000) + ' ribu ' + say(n % 1000);
      if (n < 1000000000) return say(n ~/ 1000000) + ' juta ' + say(n % 1000000);
      if (n < 1000000000000) return say(n ~/ 1000000000) + ' miliar ' + say(n % 1000000000);
      return say(n ~/ 1000000000000) + ' triliun ' + say(n % 1000000000000);
    }
    final n = value.abs();
    return (n == 0 ? 'nol' : say(n)).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Future<void> invoice(OptikOrder o, {required int paid, required int remaining}) async {
    final bytes = await invoiceBytes(o, paid: paid, remaining: remaining);
    await Printing.layoutPdf(name: 'Invoice_' + o.invoiceNumber + '.pdf', onLayout: (_) async => bytes);
  }

  static Future<Uint8List> receiptBytes(OptikOrder o, OptikPayment p, {required String receiptNumber, required int paid, required int remaining}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(26), build: (_) => pw.Container(
      color: paper,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        brand(), pw.Center(child: heading('KUITANSI', 'BUKTI PEMBAYARAN OPTIK LENTERA')),
        pw.Row(children: [pw.Expanded(child: pair('Nomor kuitansi', receiptNumber)), pw.SizedBox(width: 16), pw.Expanded(child: pair('Tanggal', date(p.paymentDate)))]),
        pw.Row(children: [pw.Expanded(child: pair('Nomor invoice', o.invoiceNumber)), pw.SizedBox(width: 16), pw.Expanded(child: pair('Nama pelanggan', o.customer.name))]),
        section('RINCIAN PEMBAYARAN'),
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(13), decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFFFF6DF), border: pw.Border.all(color: line)), child: pw.Column(children: [
          pw.Text('TELAH DITERIMA PEMBAYARAN DARI', style: const pw.TextStyle(fontSize: 9, color: ink)),
          pw.SizedBox(height: 5), pw.Text(o.customer.name, style: pw.TextStyle(fontSize: 15, font: pw.Font.helveticaBold(), color: gold)),
          pw.SizedBox(height: 5), pw.Text(money(p.amount), style: pw.TextStyle(fontSize: 21, font: pw.Font.helveticaBold(), color: gold)),
          pw.SizedBox(height: 4),
          pw.Text('Terbilang: ' + terbilang(p.amount) + ' rupiah', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: ink)),
        ])),
        pw.SizedBox(height: 7),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(children: [
            pair('Metode pembayaran', p.method), pair('Keterangan', p.note), pair('Total tagihan', money(o.total)),
            pair('Total dibayar', money(paid)), pair('Sisa tagihan', money(remaining)),
          ])),
          pw.SizedBox(width: 25),
          pw.Container(
            width: 112,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(color: pink, border: pw.Border.all(color: line)),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.SizedBox(width: 82, height: 82, child: qr(o.invoiceNumber + '|' + receiptNumber)),
                pw.SizedBox(height: 3),
                pw.Text('QR INVOICE • KUITANSI', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6, color: ink)),
              ],
            ),
          ),
        ]),
        pw.Spacer(), pw.Center(child: pw.Text('Terima kasih atas pembayaran Anda. Simpan kuitansi ini sebagai bukti pembayaran.', style: const pw.TextStyle(fontSize: 8, color: ink))),
        pw.SizedBox(height: 5), pw.Center(child: pw.Text('OPTIK LENTERA • 0858 9312 8257', style: const pw.TextStyle(fontSize: 7, color: ink))),
      ]),
    )));
    return pdf.save();
  }

  static Future<void> receipt(OptikOrder o, OptikPayment p, {required String receiptNumber, required int paid, required int remaining}) async {
    final bytes = await receiptBytes(o, p, receiptNumber: receiptNumber, paid: paid, remaining: remaining);
    await Printing.layoutPdf(name: 'Kuitansi_' + receiptNumber + '.pdf', onLayout: (_) async => bytes);
  }
}
