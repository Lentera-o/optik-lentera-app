import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../assets/optik_brand_assets.dart';

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

  /// Independent examination document, styled from the existing official receipt.
  /// It is generated in memory and uploaded to the official Drive flow.
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
    String v(String key) =>
        (values[key] ?? '').trim().isEmpty ? '-' : values[key]!.trim();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      pageTheme: pw.PageTheme(
        buildBackground: (_) => pw.Container(color: paper),
      ),
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 18),
      maxPages: 2,
      build: (_) => [
        brand(),
        pw.Center(child: heading('RESEP', 'HASIL PEMERIKSAAN REFRAKSI')),
        pw.Row(children: [
          pw.Expanded(child: pair('No. dokumen', examId)),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pair('Tanggal', date(examDate))),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pair('Nama pelanggan', name)),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pair('No. HP / WA', phone)),
        ]),
        pair('Alamat', address),
        section('HASIL PEMERIKSAAN'),
        dataTable(['MATA', 'SPH', 'CYL', 'AXIS', 'ADD', 'PD'], [
          ['OD • Kanan', v('odSph'), v('odCyl'), v('odAxis'), v('odAdd'), v('odPd')],
          ['OS • Kiri', v('osSph'), v('osCyl'), v('osAxis'), v('osAdd'), v('osPd')],
        ]),
        pw.SizedBox(height: 3),
        pair('Jenis lensa', values['lensType']),
        section('CATATAN / REKOMENDASI'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          constraints: const pw.BoxConstraints(minHeight: 30),
          decoration: pw.BoxDecoration(
            color: pink,
            border: pw.Border.all(color: line, width: .6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Text(v('note'), style: const pw.TextStyle(fontSize: 8, color: ink)),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: pink,
            border: pw.Border.all(color: line, width: .6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Row(children: [
            pw.SizedBox(width: 42, height: 42, child: qr(qrPayload)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text(
              'Dokumen pemeriksaan resmi OPTIK LENTERA. Pindai QR untuk memeriksa nomor dokumen: $examId',
              style: const pw.TextStyle(fontSize: 7, color: ink),
            )),
          ]),
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: .7, color: line),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(
          'OPTIK LENTERA · Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang · 0858 9312 8257',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 6, color: ink),
        )),
      ],
    ));
    return await pdf.save();
  }


  /// Separate paid examination receipt. This is not a merchandise invoice.
  static Future<Uint8List> examinationReceiptBytes({
    required String examId,
    required String receiptNo,
    required String qrPayload,
    required DateTime receiptDate,
    required String name,
    required String phone,
    required int amount,
    required String method,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      pageTheme: pw.PageTheme(buildBackground: (_) => pw.Container(color: paper)),
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 18),
      maxPages: 1,
      build: (_) => [
        brand(),
        pw.Center(child: heading('KUITANSI', 'BUKTI PEMBAYARAN PEMERIKSAAN OPTIK LENTERA')),
        pw.Row(children: [
          pw.Expanded(child: pair('No. kuitansi', receiptNo)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pair('Tanggal', date(receiptDate))),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pair('ID pemeriksaan', examId)),
        ]),
        pair('Nama pelanggan', name),
        pair('No. HP / WA', phone),
        section('RINCIAN PEMBAYARAN'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: pink,
            border: pw.Border.all(color: line, width: .7),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(children: [
            pw.Text('Telah diterima pembayaran pemeriksaan dari', style: const pw.TextStyle(fontSize: 9, color: ink)),
            pw.SizedBox(height: 5),
            pw.Text(name, style: pw.TextStyle(fontSize: 15, font: pw.Font.helveticaBold(), color: gold)),
            pw.SizedBox(height: 8),
            pw.Text(money(amount), style: pw.TextStyle(fontSize: 22, font: pw.Font.helveticaBold(), color: gold)),
            pw.SizedBox(height: 4),
            pw.Text('Terbilang: ${amount == 0 ? 'nol' : amount.toString()} rupiah', style: const pw.TextStyle(fontSize: 8, color: ink)),
          ]),
        ),
        pair('Jenis transaksi', 'Biaya pemeriksaan mata'),
        pair('Metode pembayaran', method),
        pair('Status pembayaran', 'LUNAS'),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.SizedBox(width: 54, height: 54, child: qr(qrPayload)),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Text(
            'Kuitansi ini merupakan bukti pembayaran pemeriksaan. Pemeriksaan tersimpan dengan ID $examId. Invoice pembelian kacamata, bila ada, diterbitkan terpisah.',
            style: const pw.TextStyle(fontSize: 8, color: ink),
          )),
        ]),
        pw.SizedBox(height: 6),
        pw.Container(height: .7, color: line),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(
          'OPTIK LENTERA · Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang · 0858 9312 8257',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 6, color: ink),
        )),
      ],
    ));
    return await pdf.save();
  }

}
