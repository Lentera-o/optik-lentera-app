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


  /// Customer-facing PROGRESS prescription, designed as a clear single-page
  /// portrait document with readable patient and OD/OS values.
  static Future<Uint8List> progressPrescriptionBytes({
    required String examId,
    required String qrPayload,
    required DateTime examDate,
    required String name,
    required String phone,
    required String address,
    required Map<String, String> values,
  }) async {
    final pdf = pw.Document();
    String v(String key) {
      final value = (values[key] ?? '').trim();
      return value.isEmpty ? '—' : value;
    }
    final table = pw.Table(
      border: pw.TableBorder.all(color: line, width: .8),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.55),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: pink),
          children: ['MATA','SPH','CYL','AXIS','ADD','PD'].map((label) =>
            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 5),
              child: pw.Text(label, textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, font: pw.Font.helveticaBold(), color: gold)))
            ).toList(),
        ),
        ...[
          ['OD  ·  KANAN',v('odSph'),v('odCyl'),v('odAxis'),v('odAdd'),v('odPd')],
          ['OS  ·  KIRI',v('osSph'),v('osCyl'),v('osAxis'),v('osAdd'),v('osPd')],
        ].map((row) => pw.TableRow(children: row.map((value) =>
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 5),
            child: pw.Text(value, textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10, color: ink)))
          ).toList())),
      ],
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 28),
      build: (_) => pw.Container(
        color: paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            brand(),
            pw.SizedBox(height: 18),
            pw.Center(child: pw.Text('RESEP KACAMATA',
              style: pw.TextStyle(fontSize: 22, font: pw.Font.helveticaBold(), color: gold, letterSpacing: 1.2))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('LENSA PROGRESS',
              style: pw.TextStyle(fontSize: 12, font: pw.Font.helveticaBold(), color: ink))),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: pink, border: pw.Border.all(color: line, width: .7),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
              child: pw.Column(children: [
                pair('No. resep', examId),
                pair('Tanggal', date(examDate)),
                pair('Nama', name),
                pair('No. HP / WhatsApp', phone),
                pair('Alamat', address),
              ]),
            ),
            pw.SizedBox(height: 18),
            pw.Text('HASIL UKURAN LENSA', style: pw.TextStyle(fontSize: 11, font: pw.Font.helveticaBold(), color: gold)),
            pw.SizedBox(height: 7),
            table,
            pw.SizedBox(height: 12),
            pair('Jenis lensa', 'PROGRESS'),
            pw.SizedBox(height: 12),
            pw.Text('CATATAN / REKOMENDASI', style: pw.TextStyle(fontSize: 10, font: pw.Font.helveticaBold(), color: gold)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity, height: 56, padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: .7),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Text(v('note'), style: const pw.TextStyle(fontSize: 9, color: ink)),
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 9),
              decoration: pw.BoxDecoration(color: pink, border: pw.Border.all(color: line, width: .7),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                pw.SizedBox(width: 54, height: 54, child: qr(qrPayload)),
                pw.SizedBox(width: 10),
                pw.Expanded(child: pw.Text('Resep lensa PROGRESS OPTIK LENTERA.\nNomor resep: $examId',
                  style: const pw.TextStyle(fontSize: 8, color: ink))),
              ]),
            ),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('Harap konfirmasi kembali ukuran dan kenyamanan lensa sebelum produksi.',
              textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, color: ink))),
          ],
        ),
      ),
    ));
    return await pdf.save();
  }

}
