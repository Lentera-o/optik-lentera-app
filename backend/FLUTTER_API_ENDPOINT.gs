/**
 * OPTIK LENTERA — Flutter API adapter
 *
 * Tempelkan fungsi-fungsi ini di BAGIAN PALING BAWAH project Apps Script aktif.
 * Jangan hapus/ganti fungsi, trigger, tab, atau data yang sudah ada.
 *
 * Sebelum deploy:
 * 1. Isi konstanta OL_FLUTTER_API_TOKEN di bawah dengan token yang sama
 *    dengan GitHub Actions Secret OL_API_TOKEN.
 * 2. Tidak perlu menambah Script Properties.
 * 3. Deploy > Manage deployments > Edit Web app > New version > Deploy.
 * 4. Web app tetap berjalan sebagai pemilik script. Batasi penggunaan URL/token.
 *
 * POST JSON:
 * { "token":"...", "action":"createOrder", "requestId":"unik",
 *   "order": { "name":"...", "phone":"...", "framePrice":100000, ... } }
 * { "token":"...", "action":"createPayment", "requestId":"unik",
 *   "payment": { "invoiceNumber":"INV-2026-0001", "amount":50000, ... } }
 */

// Token adapter Flutter — tidak memakai Script Properties.
// Samakan nilainya dengan GitHub Actions Secret OL_API_TOKEN.
const OL_FLUTTER_API_TOKEN = 'GANTI_DENGAN_TOKEN_RAHASIA_DI_APPS_SCRIPT';

function doGet(e) {
  return olApiJson_({
    ok: true,
    service: 'OPTIK LENTERA Flutter API',
    status: 'ready',
    timestamp: new Date().toISOString()
  });
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    const raw = e && e.postData && e.postData.contents;
    if (!raw) throw new Error('Body JSON wajib diisi.');
    const body = JSON.parse(raw);

    if (!OL_FLUTTER_API_TOKEN || String(body.token || '') !== OL_FLUTTER_API_TOKEN) {
      return olApiJson_({ ok:false, error:'UNAUTHORIZED', message:'Token API tidak valid atau belum disetel.' });
    }

    const action = String(body.action || '');
    const requestId = String(body.requestId || '').trim();
    if (!/^[A-Za-z0-9_-]{12,100}$/.test(requestId)) {
      throw new Error('requestId wajib unik (12–100 karakter: huruf, angka, _ atau -).');
    }

    lock.waitLock(30000);
    const eventKey = 'FLUTTER_' + (action === 'createOrder' ? 'ORDER_' : 'PAYMENT_') + requestId;
    const ssId = PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID');
    if (!ssId) throw new Error('Database OPTIK LENTERA belum terhubung.');

    if (action === 'createOrder') {
      const p = body.order || {};
      const answers = {
        'Cap waktu': p.orderDate || new Date(),
        'Nama pelanggan': p.name || '',
        'Nomor HP / WhatsApp': p.phone || '',
        'Alamat pelanggan': p.address || '',
        'Dokter / Optometris': p.doctor || '',
        'OD SPH': p.odSph || '', 'OD CYL': p.odCyl || '', 'OD AXIS': p.odAxis || '',
        'OD ADD': p.odAdd || '', 'OD PD': p.odPd || '',
        'OS SPH': p.osSph || '', 'OS CYL': p.osCyl || '', 'OS AXIS': p.osAxis || '',
        'OS ADD': p.osAdd || '', 'OS PD': p.osPd || '',
        'Jenis lensa': p.lensType || '', 'Catatan resep': p.rxNote || '',
        'Frame - merek model warna': p.frameDesc || '',
        'Harga frame': p.framePrice || 0,
        'Lensa - jenis ukuran coating': p.lensDesc || '',
        'Harga lensa': p.lensPrice || 0,
        'Lain-lain': p.otherDesc || '',
        'Harga lain-lain': p.otherPrice || 0,
        'DP Awal': p.initialPayment || 0,
        'Metode pembayaran awal': p.initialPaymentMethod || '',
        'Catatan invoice': p.note || ''
      };
      olProcessOrder_(answers, eventKey);
      const sh = SpreadsheetApp.openById(ssId).getSheetByName(OL.SHEET_ORDER);
      const row = olFindRow_(sh, ['Kunci Proses Internal'], eventKey);
      if (!row) throw new Error('Pesanan diproses tetapi baris database tidak ditemukan.');
      return olApiJson_({
        ok:true, action:action, requestId:requestId,
        invoiceNumber:olGetField_(sh,row,OL_FIELDS.invoice),
        invoicePdf:olGetField_(sh,row,OL_FIELDS.invoicePdf),
        status:olGetField_(sh,row,OL_FIELDS.status)
      });
    }

    if (action === 'createPayment') {
      const p = body.payment || {};
      const answers = {
        'Nomor Invoice': p.invoiceNumber || '',
        'Tanggal Pembayaran': p.paymentDate || new Date(),
        'Jumlah Pembayaran': p.amount || 0,
        'Metode Pembayaran': p.method || '',
        'Keterangan Pembayaran': p.category || '',
        'Catatan': p.note || ''
      };
      olProcessPayment_(answers, eventKey);
      const pays = SpreadsheetApp.openById(ssId).getSheetByName(OL.SHEET_PAY);
      const row = olFindRow_(pays, ['Kunci Proses Internal'], eventKey);
      if (!row) throw new Error('Pembayaran diproses tetapi baris kuitansi tidak ditemukan.');
      return olApiJson_({
        ok:true, action:action, requestId:requestId,
        receiptNumber:olGetField_(pays,row,OL_PAY_FIELDS.receipt),
        invoiceNumber:olGetField_(pays,row,OL_PAY_FIELDS.invoice),
        receiptPdf:olGetField_(pays,row,OL_PAY_FIELDS.pdf),
        remaining:olGetField_(pays,row,OL_PAY_FIELDS.remaining)
      });
    }

    throw new Error('Action tidak dikenal. Gunakan createOrder atau createPayment.');
  } catch (err) {
    console.error(err && err.stack ? err.stack : err);
    return olApiJson_({ ok:false, error:'REQUEST_FAILED', message:String(err && err.message || err) });
  } finally {
    try { if (lock.hasLock()) lock.releaseLock(); } catch (_) {}
  }
}

function olApiJson_(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
