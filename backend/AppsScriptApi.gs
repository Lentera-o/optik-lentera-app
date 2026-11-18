/**
 * OPTIK LENTERA - JSON API BRIDGE
 *
 * Tambahkan file ini ke project Apps Script yang sama dengan
 * OPTIK_LENTERA_FINAL_AMAN.gs. File ini hanya menambahkan doGet/doPost;
 * pemrosesan invoice, kuitansi, dan penyimpanan tetap memakai fungsi lama.
 *
 * Konfigurasi sekali di Apps Script > Project Settings > Script properties:
 *   OL_API_TOKEN = token acak rahasia yang sama dengan GitHub Actions secret OL_API_TOKEN
 *
 * Jangan menaruh token di source code atau mengirimkannya lewat chat.
 */

function doGet() {
  return olApiJson_({
    ok: true,
    service: 'OPTIK_LENTERA',
    api: 'ready',
    actions: ['createOrder', 'createPayment']
  });
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    const raw = e && e.postData && e.postData.contents;
    if (!raw) return olApiJson_({ ok: false, message: 'Body JSON kosong.' });

    const body = JSON.parse(raw);
    const expected = PropertiesService.getScriptProperties().getProperty('OL_API_TOKEN');
    const supplied = String(body.token || '');
    if (!expected || !supplied || supplied !== expected) {
      return olApiJson_({ ok: false, message: 'Token API tidak valid atau belum dikonfigurasi.' });
    }

    lock.waitLock(30000);
    const action = String(body.action || '');
    const requestId = String(body.requestId || '').trim();
    if (!requestId) throw new Error('requestId wajib diisi.');

    if (action === 'createOrder') {
      const x = body.order || {};
      const date = x.orderDate ? new Date(x.orderDate) : new Date();
      if (isNaN(date.getTime())) throw new Error('Tanggal pesanan tidak valid.');
      const answers = {
        'Timestamp': date,
        'Nama pelanggan': x.name || '',
        'Nomor HP / WhatsApp': x.phone || '',
        'Alamat pelanggan': x.address || '',
        'Dokter / Optometris': x.doctor || '',
        'OD SPH': x.odSph || '', 'OD CYL': x.odCyl || '',
        'OD AXIS': x.odAxis || '', 'OD ADD': x.odAdd || '', 'OD PD': x.odPd || '',
        'OS SPH': x.osSph || '', 'OS CYL': x.osCyl || '',
        'OS AXIS': x.osAxis || '', 'OS ADD': x.osAdd || '', 'OS PD': x.osPd || '',
        'Jenis lensa': x.lensType || '',
        'Catatan resep': x.rxNote || '',
        'Frame - merek model warna': x.frameDesc || '',
        'Harga frame': x.framePrice || 0,
        'Lensa - jenis ukuran coating': x.lensDesc || '',
        'Harga lensa': x.lensPrice || 0,
        'Lain-lain': x.otherDesc || '',
        'Harga lain-lain': x.otherPrice || 0,
        'DP Awal': x.initialPayment || 0,
        'Metode pembayaran awal': x.initialPaymentMethod || '',
        'Catatan invoice': x.note || ''
      };
      olProcessOrder_(answers, requestId);
      const ss = SpreadsheetApp.openById(
        PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID')
      );
      const sh = ss.getSheetByName(OL.SHEET_ORDER);
      const row = olFindRow_(sh, OL_FIELDS.eventKey, requestId);
      if (!row) throw new Error('Pesanan tidak ditemukan setelah diproses.');
      const saved = olReadOrder_(sh, row);
      return olApiJson_({
        ok: true,
        action: action,
        requestId: requestId,
        invoiceNumber: saved.invoice,
        total: saved.total,
        paid: saved.paid,
        remaining: saved.remaining,
        status: saved.status
      });
    }

    if (action === 'createPayment') {
      const x = body.payment || {};
      const date = x.paymentDate ? new Date(x.paymentDate) : new Date();
      if (isNaN(date.getTime())) throw new Error('Tanggal pembayaran tidak valid.');
      const answers = {
        'Nomor Invoice': x.invoiceNumber || '',
        'Jumlah Pembayaran': x.amount || 0,
        'Metode Pembayaran': x.method || '',
        'Tanggal Pembayaran': date,
        'Catatan': x.note || ''
      };
      olProcessPayment_(answers, requestId);
      const ss = SpreadsheetApp.openById(
        PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID')
      );
      const sh = ss.getSheetByName(OL.SHEET_PAY);
      const row = olFindRow_(sh, OL_PAY_FIELDS.eventKey, requestId);
      if (!row) throw new Error('Pembayaran tidak ditemukan setelah diproses.');
      const saved = olReadPaymentForRetry_(sh, row);
      return olApiJson_({
        ok: true,
        action: action,
        requestId: requestId,
        invoiceNumber: saved.invoice,
        receiptNumber: saved.receipt,
        amount: saved.amount,
        paid: saved.paid,
        remaining: saved.remaining
      });
    }

    throw new Error('Action API tidak dikenal: ' + action);
  } catch (err) {
    console.error(err && err.stack ? err.stack : err);
    return olApiJson_({
      ok: false,
      message: err && err.message ? err.message : String(err)
    });
  } finally {
    try { lock.releaseLock(); } catch (ignored) {}
  }
}

function olApiJson_(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
