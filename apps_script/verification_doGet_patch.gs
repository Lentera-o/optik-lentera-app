/**
 * PATCH VERIFIKASI QR INVOICE OPTIK LENTERA
 *
 * Tambahkan fungsi ini ke project Apps Script AKTIF yang sudah berisi
 * OL_FIELDS, OL, olFindRow_(), dan olReadOrder_().
 * Jangan mengganti doPost atau fungsi transaksi yang sudah ada.
 *
 * Setelah ditambahkan, deploy ulang Web App dengan URL /exec yang sama.
 */
function doGet(e) {
  const invoice = String((e && e.parameter && e.parameter.verify) || '').trim();
  if (!invoice) {
    return olVerifyPage_('Verifikasi Invoice', '<p>Nomor invoice tidak ditemukan pada tautan.</p>');
  }

  try {
    const id = PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID');
    if (!id) throw new Error('Database invoice belum terhubung.');
    const ss = SpreadsheetApp.openById(id);
    const sh = ss.getSheetByName(OL.SHEET_ORDER);
    if (!sh) throw new Error('Data invoice belum tersedia.');

    const row = olFindRow_(sh, OL_FIELDS.invoice, invoice);
    if (!row) {
      return olVerifyPage_('Invoice Tidak Ditemukan',
        '<p>Nomor invoice <strong>' + olVerifyEscape_(invoice) + '</strong> tidak ditemukan pada database OPTIK LENTERA.</p>');
    }

    const o = olReadOrder_(sh, row);
    const dateText = o.date
      ? Utilities.formatDate(new Date(o.date), OL.ZONA || 'Asia/Jakarta', 'dd MMMM yyyy')
      : '-';
    const status = String(o.status || (Number(o.remaining) <= 0 ? 'LUNAS' : (Number(o.paid) > 0 ? 'DP' : 'BELUM LUNAS'))).toUpperCase();
    const statusColor = status === 'LUNAS' ? '#287a45' : '#98752a';

    const body = [
      '<div class="status" style="color:' + statusColor + '">' + olVerifyEscape_(status) + '</div>',
      '<div class="number">' + olVerifyEscape_(o.invoice) + '</div>',
      '<div class="row"><span>Tanggal invoice</span><strong>' + olVerifyEscape_(dateText) + '</strong></div>',
      '<div class="row"><span>Total tagihan</span><strong>' + olVerifyEscape_(olRp_(o.total)) + '</strong></div>',
      '<div class="row"><span>Total dibayar</span><strong>' + olVerifyEscape_(olRp_(o.paid)) + '</strong></div>',
      '<div class="row balance"><span>Sisa tagihan</span><strong>' + olVerifyEscape_(olRp_(o.remaining)) + '</strong></div>',
      '<p class="note">Data ini dicocokkan langsung dengan database transaksi OPTIK LENTERA.</p>'
    ].join('');

    return olVerifyPage_('Verifikasi Invoice', body);
  } catch (err) {
    console.error('Verifikasi invoice gagal: ' + (err && err.stack ? err.stack : err));
    return olVerifyPage_('Verifikasi Belum Tersedia',
      '<p>Data invoice belum dapat diverifikasi. Silakan hubungi OPTIK LENTERA.</p>');
  }
}

function olVerifyEscape_(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function olVerifyPage_(title, body) {
  const html = '<!doctype html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + olVerifyEscape_(title) + ' - OPTIK LENTERA</title>' +
    '<style>' +
    'body{margin:0;padding:24px 14px;background:#fff8f7;font:15px Arial,sans-serif;color:#51484a}' +
    '.card{max-width:520px;margin:28px auto;background:#fff;border:1px solid #ddcba8;border-radius:18px;padding:24px;box-shadow:0 8px 28px #51484a12}' +
    '.brand{text-align:center;color:#98752a;font-weight:800;letter-spacing:2px;font-size:20px}' +
    'h1{text-align:center;font-size:17px;color:#51484a;margin:22px 0}' +
    '.status{text-align:center;font-weight:800;font-size:13px;letter-spacing:1px;background:#fff8f7;padding:10px;border-radius:10px}' +
    '.number{text-align:center;font-weight:800;font-size:19px;color:#98752a;margin:14px 0 22px}' +
    '.row{display:flex;justify-content:space-between;gap:14px;padding:12px 0;border-bottom:1px solid #f0e7e0}' +
    '.row span{color:#766c6d}.row strong{text-align:right}.balance{color:#98752a}' +
    '.note{text-align:center;color:#887f80;font-size:12px;line-height:1.5;margin:22px 0 0}' +
    '.foot{text-align:center;color:#887f80;font-size:11px;margin-top:20px}' +
    '</style></head><body><main class="card">' +
    '<div class="brand">OPTIK LENTERA</div><h1>' + olVerifyEscape_(title) + '</h1>' +
    body + '<div class="foot">Jernih Melihat, Nyaman Melangkah.</div>' +
    '</main></body></html>';
  return HtmlService.createHtmlOutput(html).setTitle(title + ' - OPTIK LENTERA');
}
