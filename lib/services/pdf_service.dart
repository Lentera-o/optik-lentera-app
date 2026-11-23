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

  /// Prescription document styled to match the approved OPTIK LENTERA receipt.
  /// No stamp/signature seal is added. The verification QR remains on the document.
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
    String optional(String key) => (values[key] ?? '').trim();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      pageTheme: pw.PageTheme(
        buildBackground: (_) => pw.Container(color: PdfColors.white),
      ),
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 18),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          brand(),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text(
            'HASIL PEMERIKSAAN REFRAKSI',
            style: pw.TextStyle(fontSize: 19, font: pw.Font.helveticaBold(), color: gold),
          )),
          pw.SizedBox(height: 3),
          pw.Center(child: pw.Text(
            'RESEP KACAMATA',
            style: pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold(), color: ink),
          )),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            pw.Expanded(child: _examField('NO. DOKUMEN', examId)),
            pw.SizedBox(width: 7),
            pw.Expanded(child: _examField('TANGGAL', date(examDate))),
            pw.SizedBox(width: 7),
            pw.Expanded(child: _examField('ID PEMERIKSAAN', examId)),
            pw.SizedBox(width: 7),
            pw.Expanded(child: _examField('NAMA PELANGGAN', name)),
          ]),
          section('DATA PELANGGAN'),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: line, width: .6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Row(children: [
              pw.Expanded(child: pair('Nama', name)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: pair('Tanggal lahir / No. identitas (opsional)',
                optional('birthDate').isNotEmpty ? optional('birthDate') : optional('identityNo'))),
            ]),
          ),
          section('HASIL PEMERIKSAAN'),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: .6),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.15),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pink),
                children: ['MATA','SPH','CYL','AXIS','ADD','PD'].map((h) =>
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                    child: pw.Text(h, textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 8, font: pw.Font.helveticaBold(), color: ink)))
                ).toList(),
              ),
              ...[
                ['OD (KANAN)',v('odSph'),v('odCyl'),v('odAxis'),v('odAdd'),v('odPd')],
                ['OS (KIRI)',v('osSph'),v('osCyl'),v('osAxis'),v('osAdd'),v('osPd')],
              ].map((row) => pw.TableRow(children: row.map((cell) =>
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 5),
                  child: pw.Text(cell, textAlign: row.first == cell ? pw.TextAlign.left : pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8, color: ink)))
              ).toList())),
            ],
          ),
          pw.SizedBox(height: 5),
          pair('Jenis lensa', values['lensType']),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 5),
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(
              color: paper,
              border: pw.Border.all(color: pink, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CATATAN / REKOMENDASI',
                style: pw.TextStyle(fontSize: 8, font: pw.Font.helveticaBold(), color: gold)),
              pw.SizedBox(height: 5),
              pw.Container(height: 24, alignment: pw.Alignment.topLeft,
                child: pw.Text(v('note'), style: const pw.TextStyle(fontSize: 8, color: ink))),
            ]),
          ),
          pw.SizedBox(height: 7),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: line, width: .6),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Row(children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: .6)),
                child: pw.Column(children: [
                  pw.SizedBox(width: 54, height: 54, child: qr(qrPayload)),
                  pw.SizedBox(height: 2),
                  pw.Text('QR VERIFIKASI', style: const pw.TextStyle(fontSize: 5.5, color: ink)),
                ]),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Dokumen hasil pemeriksaan OPTIK LENTERA',
                    style: const pw.TextStyle(fontSize: 8, color: ink)),
                  pw.SizedBox(height: 4),
                  pw.Text('Data resep mengikuti hasil pemeriksaan yang tercatat.',
                    style: const pw.TextStyle(fontSize: 8, color: ink)),
                  pw.SizedBox(height: 4),
                  pw.Text('Jelas Lihatnya, Jelas Rekomendasinya.',
                    style: pw.TextStyle(fontSize: 8, font: pw.Font.helveticaBold(), color: gold)),
                ],
              )),
            ]),
          ),
          pw.Spacer(),
          pw.Container(height: .7, color: line),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(
            'OPTIK LENTERA  ·  Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang  ·  0858 9312 8257',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6, color: ink),
          )),
        ],
      ),
    ));
    return await pdf.save();
  }

  static pw.Widget _examField(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: pink, width: .8),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 6.5, font: pw.Font.helveticaBold(), color: ink)),
      pw.SizedBox(height: 3),
      pw.Text(value.isEmpty ? '-' : value, maxLines: 1,
        style: const pw.TextStyle(fontSize: 7.5, color: ink)),
    ]),
  );

  /// Separate paid examination receipt, landscape A4 and visually paired
  /// with the approved landscape prescription document.
  static Future<Uint8List> examinationReceiptBytes({
    required String examId,
    required String receiptNo,
    required String qrPayload,
    required DateTime receiptDate,
    required String name,
    required String phone,
    required int amount,
    required String method,
    String paymentStatus = 'LUNAS',
  }) async {
    final pdf = pw.Document();
    final isPaid = paymentStatus == 'LUNAS';
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      pageTheme: pw.PageTheme(buildBackground: (_) => pw.Container(color: PdfColors.white)),
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 18),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          brand(),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text(
            isPaid ? 'KUITANSI PEMERIKSAAN' : 'RINCIAN BIAYA PEMERIKSAAN',
            style: pw.TextStyle(fontSize: 19, font: pw.Font.helveticaBold(), color: gold, letterSpacing: 1),
          )),
          pw.SizedBox(height: 3),
          pw.Center(child: pw.Text(
            isPaid ? 'BUKTI PEMBAYARAN JASA PEMERIKSAAN MATA' : 'PEMBERITAHUAN BIAYA JASA PEMERIKSAAN MATA',
            style: const pw.TextStyle(fontSize: 8, color: ink),
          )),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            pw.Expanded(child: _examField(isPaid ? 'NO. KUITANSI' : 'NO. REFERENSI', receiptNo)),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _examField('TANGGAL', date(receiptDate))),
            pw.SizedBox(width: 8),
            pw.Expanded(child: _examField('ID PEMERIKSAAN', examId)),
          ]),
          section('IDENTITAS PELANGGAN'),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: .6), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
            child: pw.Row(children: [
              pw.Expanded(child: pair('Nama pelanggan', name)),
              pw.SizedBox(width: 18),
              pw.Expanded(child: pair('No. HP / WhatsApp', phone)),
            ]),
          ),
          section('RINCIAN PEMBAYARAN'),
          pw.Table(
            border: pw.TableBorder.all(color: line, width: .6),
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(1.5)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pink),
                children: ['KETERANGAN','JUMLAH','TOTAL'].map((label) => pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Text(label, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, font: pw.Font.helveticaBold(), color: gold)),
                )).toList(),
              ),
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(9), child: pw.Text('Jasa pemeriksaan mata', style: const pw.TextStyle(fontSize: 9, color: ink))),
                pw.Padding(padding: const pw.EdgeInsets.all(9), child: pw.Text('1', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9, color: ink))),
                pw.Padding(padding: const pw.EdgeInsets.all(9), child: pw.Text(money(amount), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, font: pw.Font.helveticaBold(), color: gold))),
              ]),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(color: paper, border: pw.Border.all(color: pink, width: .8), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(isPaid ? 'TELAH DITERIMA DARI' : 'TAGIHAN DITUJUKAN KEPADA', style: pw.TextStyle(fontSize: 7, font: pw.Font.helveticaBold(), color: ink)),
                pw.SizedBox(height: 4),
                pw.Text(name, style: pw.TextStyle(fontSize: 13, font: pw.Font.helveticaBold(), color: gold)),
                pw.SizedBox(height: 5),
                pw.Text(isPaid ? 'Pembayaran jasa pemeriksaan telah diterima.' : 'Biaya pemeriksaan belum dinyatakan lunas.', style: const pw.TextStyle(fontSize: 8, color: ink)),
              ]),
            )),
            pw.SizedBox(width: 10),
            pw.Container(
              width: 190,
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(color: pink, border: pw.Border.all(color: line, width: .7), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('TOTAL ${isPaid ? 'DIBAYAR' : 'BIAYA'}', style: pw.TextStyle(fontSize: 7, font: pw.Font.helveticaBold(), color: ink)),
                pw.SizedBox(height: 4),
                pw.Text(money(amount), style: pw.TextStyle(fontSize: 17, font: pw.Font.helveticaBold(), color: gold)),
                pw.SizedBox(height: 5),
                pair('Metode', method),
                pair('Status', paymentStatus),
              ]),
            ),
          ]),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: .6), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
            child: pw.Row(children: [
              pw.SizedBox(width: 48, height: 48, child: qr(qrPayload)),
              pw.SizedBox(width: 9),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('QR VERIFIKASI DOKUMEN', style: pw.TextStyle(fontSize: 7, font: pw.Font.helveticaBold(), color: gold)),
                pw.SizedBox(height: 3),
                pw.Text('Dokumen ini terkait dengan pemeriksaan $examId. ${isPaid ? 'Kuitansi ini merupakan bukti pembayaran jasa pemeriksaan, bukan invoice pembelian barang.' : 'Simpan dokumen ini sebagai rincian biaya; kuitansi diterbitkan setelah pembayaran diterima.'}', style: const pw.TextStyle(fontSize: 7, color: ink)),
              ])),
            ]),
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: .7, color: line),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(
            'OPTIK LENTERA  ·  Jl. Cibarengkok RT.03 RW.01 Peusar, Kec. Panongan, Kab. Tangerang  ·  0858 9312 8257',
            textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6, color: ink),
          )),
        ],
      ),
    ));
    return await pdf.save();
  }

}
