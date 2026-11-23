import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
        pw.Text('Jelas Melihat, Cerah Masa Depan', style: pw.TextStyle(fontSize: 9, font: pw.Font.helveticaOblique(), color: ink)),
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

  static Future<void> invoice(OptikOrder o, {required int paid, required int remaining}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (_) => pw.Container(
      color: paper,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        brand(), pw.Center(child: heading('INVOICE', 'DOKUMEN PRATINJAU • BELUM TERSINKRONISASI')),
        pair('Nomor invoice', o.invoiceNumber), pair('Tanggal', date(o.orderDate)),
        pair('Nama pelanggan', o.customer.name), pair('No. HP', o.customer.phone), pair('Alamat', o.customer.address),
        section('01 — RESEP KACAMATA'),
        dataTable(['MATA','SPH','CYL','AXIS','ADD','PD'], [
          ['OD • Kanan',o.prescription.odSph,o.prescription.odCyl,o.prescription.odAxis,o.prescription.odAdd,o.prescription.odPd],
          ['OS • Kiri',o.prescription.osSph,o.prescription.osCyl,o.prescription.osAxis,o.prescription.osAdd,o.prescription.osPd],
        ]),
        pair('Jenis lensa', o.prescription.lensType), pair('Dokter / optometris', o.prescription.doctor), pair('Catatan resep', o.prescription.note),
        section('02 — RINCIAN PESANAN'),
        dataTable(['ITEM','KETERANGAN','HARGA'], [
          ['Frame',o.frame.description,money(o.frame.price)], ['Lensa',o.lens.description,money(o.lens.price)], ['Lain-lain',o.other.description,money(o.other.price)],
        ]),
        pw.SizedBox(height: 7), pair('TOTAL TAGIHAN', money(o.total)), pair('DP AWAL', money(o.initialPayment)),
        pair('TOTAL DIBAYAR', money(paid)), pair('SISA TAGIHAN', money(remaining)),
        pair('Metode DP', o.initialPaymentMethod), pair('Catatan', o.note),
        pw.Spacer(),
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: pink, borderRadius: pw.BorderRadius.circular(5)), child: pw.Text('Terima kasih telah mempercayakan kebutuhan penglihatan Anda kepada OPTIK LENTERA. Harap simpan invoice ini sebagai bukti transaksi.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: ink))),
        pw.SizedBox(height: 7), pw.Center(child: pw.Text('OPTIK LENTERA • 0858 9312 8257', style: const pw.TextStyle(fontSize: 7, color: ink))),
      ]),
    )));
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (_) => pw.Container(
      color: paper,
      child: pw.Column(children: [
        brand(), pw.SizedBox(height: 30), pw.Text('KODE QR INVOICE', style: pw.TextStyle(fontSize: 16, font: pw.Font.helveticaBold(), color: gold)),
        pw.SizedBox(height: 65),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          pw.Column(children: [pw.Text('Pelanggan'), pw.SizedBox(height: 60), pw.Text('(____________________)')]),
          pw.Column(children: [pw.Text('Hormat kami,'), pw.SizedBox(height: 60), pw.Text('OPTIK LENTERA', style: pw.TextStyle(font: pw.Font.helveticaBold(), color: gold))]),
        ]),
        pw.SizedBox(height: 28), pw.SizedBox(width: 150, height: 150, child: qr(o.invoiceNumber)),
        pw.Spacer(), pw.Text('Pindai QR untuk membaca nomor invoice: ' + o.invoiceNumber, style: const pw.TextStyle(fontSize: 8, color: ink)),
      ]),
    )));
    await Printing.layoutPdf(name: 'Invoice_' + o.invoiceNumber + '.pdf', onLayout: (_) async => pdf.save());
  }


  static Future<Uint8List> prescriptionBytes(OptikOrder o) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Container(
        color: paper,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            brand(),
            pw.Center(child: heading('RESEP KACAMATA', 'HASIL PEMERIKSAAN REFRAKSI')),
            pair('Nomor referensi', o.invoiceNumber),
            pair('Tanggal pemeriksaan', date(o.orderDate)),
            pair('Nama pelanggan', o.customer.name),
            pair('No. HP', o.customer.phone),
            pair('Alamat', o.customer.address),
            section('01 — HASIL PEMERIKSAAN MATA'),
            dataTable(['MATA', 'SPH', 'CYL', 'AXIS', 'ADD', 'PD'], [
              ['OD • Kanan', o.prescription.odSph, o.prescription.odCyl, o.prescription.odAxis, o.prescription.odAdd, o.prescription.odPd],
              ['OS • Kiri', o.prescription.osSph, o.prescription.osCyl, o.prescription.osAxis, o.prescription.osAdd, o.prescription.osPd],
            ]),
            pair('Jenis lensa', o.prescription.lensType),
            pair('Dokter / optometris', o.prescription.doctor),
            section('02 — CATATAN PEMERIKSAAN'),
            pw.Container(
              width: double.infinity,
              constraints: const pw.BoxConstraints(minHeight: 54),
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFFFCF7),
                border: pw.Border.all(color: line, width: .6),
              ),
              child: pw.Text(
                o.prescription.note.isEmpty ? '-' : o.prescription.note,
                style: const pw.TextStyle(fontSize: 9, color: ink),
              ),
            ),
            pw.Spacer(),
            pw.Center(child: pw.Text('OPTIK LENTERA • 0858 9312 8257', style: const pw.TextStyle(fontSize: 7, color: ink))),
            pw.SizedBox(height: 7),
            pw.Center(child: pw.SizedBox(width: 76, height: 76, child: qr(o.invoiceNumber))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('QR referensi: ' + o.invoiceNumber, style: const pw.TextStyle(fontSize: 7, color: ink))),
          ],
        ),
      ),
    ));
    return pdf.save();
  }

  static Future<void> prescription(OptikOrder o) async {
    final bytes = await prescriptionBytes(o);
    await Printing.layoutPdf(
      name: 'Resep_' + o.invoiceNumber + '.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> receiptBytes(OptikOrder o, OptikPayment p, {required String receiptNumber, required int paid, required int remaining}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(26), build: (_) => pw.Container(
      color: paper,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        brand(), pw.Center(child: heading('KUITANSI', 'DOKUMEN PRATINJAU • BELUM TERSINKRONISASI')),
        pw.Row(children: [pw.Expanded(child: pair('Nomor kuitansi', receiptNumber)), pw.SizedBox(width: 16), pw.Expanded(child: pair('Tanggal', date(p.paymentDate)))]),
        pw.Row(children: [pw.Expanded(child: pair('Nomor invoice', o.invoiceNumber)), pw.SizedBox(width: 16), pw.Expanded(child: pair('Nama pelanggan', o.customer.name))]),
        section('RINCIAN PEMBAYARAN'),
        pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(13), decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFFFF6DF), border: pw.Border.all(color: line)), child: pw.Column(children: [
          pw.Text('TELAH DITERIMA PEMBAYARAN DARI', style: const pw.TextStyle(fontSize: 9, color: ink)),
          pw.SizedBox(height: 5), pw.Text(o.customer.name, style: pw.TextStyle(fontSize: 15, font: pw.Font.helveticaBold(), color: gold)),
          pw.SizedBox(height: 5), pw.Text(money(p.amount), style: pw.TextStyle(fontSize: 21, font: pw.Font.helveticaBold(), color: gold)),
        ])),
        pw.SizedBox(height: 7),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(children: [
            pair('Metode pembayaran', p.method), pair('Keterangan', p.note), pair('Total tagihan', money(o.total)),
            pair('Total dibayar', money(paid)), pair('Sisa tagihan', money(remaining)),
          ])),
          pw.SizedBox(width: 25), pw.SizedBox(width: 105, height: 105, child: qr(o.invoiceNumber + '|' + receiptNumber)),
        ]),
        pw.Spacer(), pw.Center(child: pw.Text('Terima kasih atas pembayaran Anda. Simpan kuitansi ini sebagai bukti pembayaran.', style: const pw.TextStyle(fontSize: 8, color: ink))),
        pw.SizedBox(height: 5), pw.Center(child: pw.Text('OPTIK LENTERA • 0858 9312 8257', style: const pw.TextStyle(fontSize: 7, color: ink))),
      ]),
    )));
    return pdf.save();
  }

  static Future<void> receipt(OptikOrder o, OptikPayment p, {required String receiptNumber, required int paid, required int remaining}) async {
    final bytes = await receiptBytes(o, p, receiptNumber: receiptNumber, paid: paid, remaining: remaining);
    await Printing.layoutPdf(
      name: 'Kuitansi_' + receiptNumber + '.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareReceiptAndPrescription(
    OptikOrder o,
    OptikPayment p, {
    required String receiptNumber,
    required int paid,
    required int remaining,
  }) async {
    final receiptPdf = await receiptBytes(
      o, p, receiptNumber: receiptNumber, paid: paid, remaining: remaining,
    );
    final prescriptionPdf = await prescriptionBytes(o);
    await SharePlus.instance.share(ShareParams(
      subject: 'Kuitansi dan Resep OPTIK LENTERA - ' + o.customer.name,
      text: 'Kuitansi pembayaran dan resep kacamata OPTIK LENTERA.',
      files: [
        XFile.fromData(receiptPdf, mimeType: 'application/pdf', name: 'Kuitansi_' + receiptNumber + '.pdf'),
        XFile.fromData(prescriptionPdf, mimeType: 'application/pdf', name: 'Resep_' + o.invoiceNumber + '.pdf'),
      ],
    ));
  }
}
