/**
 * OPTIK LENTERA — Secure Flutter transaction API
 *
 * Add this file to the EXISTING Apps Script project that already contains
 * OPTIK_LENTERA_FINAL_AMAN.gs. It reuses the existing invoice, receipt,
 * numbering, spreadsheet, and PDF functions; it does not replace triggers.
 *
 * Required Script Properties:
 *   OL_SPREADSHEET_ID           = ID spreadsheet operasional OPTIK LENTERA
 *   OL_APP_API_KEY              = random access key (minimum 32 characters)
 *
 * Deploy the existing Web App as "Execute as me". The endpoint may be
 * reachable publicly, but every action requires OL_APP_API_KEY. This removes
 * Google Sign-In. A key embedded in an APK can be extracted, so this is a basic
 * access gate, not strong staff authentication. Restrict APK distribution.
 *
 * Request JSON:
 * {
 *   "action": "readTable" | "createOrder" | "createPayment",
 *   "requestId": "<unique UUID generated once per user submission>",
 *   "apiKey": "<app access key>",
 *   "data": { ... }
 * }
 *
 * Do not treat an APK-embedded key as a secret against a determined attacker.
 */

function doPost(e) {
  try {
    const raw = e && e.postData && e.postData.contents
      ? String(e.postData.contents)
      : '';
    if (!raw || raw.length > 50000) {
      return olApiJson_({ ok: false, error: 'Payload kosong atau terlalu besar.' });
    }

    const request = JSON.parse(raw);
    if (!request || typeof request !== 'object' || Array.isArray(request)) {
      throw new Error('Format permintaan tidak valid.');
    }

    // Verify app access key before reading or changing operational data.
    const actor = olApiVerifyAppKey_(request.apiKey);
    const action = String(request.action || '');
    if (action === 'readTable') {
      if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
        throw new Error('Parameter pembacaan tidak valid.');
      }
      return olApiReadTable_(request.data, actor);
    }
    const requestId = String(request.requestId || '');
    if (!/^[A-Za-z0-9_-]{16,80}$/.test(requestId)) {
      throw new Error('ID permintaan tidak valid.');
    }
    if (action !== 'createOrder' && action !== 'createPayment') {
      throw new Error('Aksi transaksi tidak dikenal.');
    }
    if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
      throw new Error('Data transaksi tidak valid.');
    }

    const lock = LockService.getScriptLock();
    lock.waitLock(30000);
    try {
      if (action === 'createOrder') {
        return olApiCreateOrder_(request.data, requestId, actor);
      }
      return olApiCreatePayment_(request.data, requestId, actor);
    } finally {
      lock.releaseLock();
    }
  } catch (err) {
    console.error('OPTIK LENTERA API:', err && err.stack ? err.stack : err);
    return olApiJson_({
      ok: false,
      error: err && err.message ? String(err.message).slice(0, 240) : 'Permintaan gagal diproses.'
    });
  }
}

function olApiVerifyAppKey_(providedKey) {
  const expected = String(PropertiesService.getScriptProperties().getProperty('OL_APP_API_KEY') || '');
  const supplied = String(providedKey || '');
  if (expected.length < 32) throw new Error('Kunci akses aplikasi belum dikonfigurasi administrator.');
  if (supplied.length !== expected.length || supplied.length > 256) throw new Error('Akses aplikasi tidak valid.');
  let mismatch = 0;
  for (let i = 0; i < expected.length; i++) mismatch |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  if (mismatch !== 0) throw new Error('Akses aplikasi tidak valid.');
  return { email: 'Aplikasi OPTIK LENTERA', name: 'Aplikasi' };
}

function olApiCreateOrder_(data, requestId, actor) {
  const eventKey = 'APP_ORDER_' + requestId;
  const initialPayment = olApiMoney_(data.initialPayment, 'DP awal');
  const orderDate = data.orderDate ? String(data.orderDate).trim() : new Date().toISOString();
  if (isNaN(new Date(orderDate).getTime())) throw new Error('Tanggal pesanan tidak valid.');
  const answers = {
    'Cap waktu': orderDate,
    'Nama pelanggan': olApiText_(data.name, 'Nama pelanggan', 120, true),
    'Nomor HP / WhatsApp': olApiText_(data.phone, 'Nomor WhatsApp', 40, false),
    'Alamat pelanggan': olApiText_(data.address, 'Alamat pelanggan', 500, false),
    'Dokter / Optometris': olApiText_(data.doctor, 'Dokter / optometris', 120, false),
    'OD SPH': olApiText_(data.odSph, 'OD SPH', 30, false),
    'OD CYL': olApiText_(data.odCyl, 'OD CYL', 30, false),
    'OD AXIS': olApiText_(data.odAxis, 'OD AXIS', 30, false),
    'OD ADD': olApiText_(data.odAdd, 'OD ADD', 30, false),
    'OD PD': olApiText_(data.odPd, 'OD PD', 30, false),
    'OS SPH': olApiText_(data.osSph, 'OS SPH', 30, false),
    'OS CYL': olApiText_(data.osCyl, 'OS CYL', 30, false),
    'OS AXIS': olApiText_(data.osAxis, 'OS AXIS', 30, false),
    'OS ADD': olApiText_(data.osAdd, 'OS ADD', 30, false),
    'OS PD': olApiText_(data.osPd, 'OS PD', 30, false),
    'Jenis lensa': olApiText_(data.lensType, 'Jenis lensa', 160, false),
    'Catatan resep': olApiText_(data.rxNote, 'Catatan resep', 1000, false),
    'Frame - merek model warna': olApiText_(data.frameDescription, 'Deskripsi frame', 240, false),
    'Harga frame': olApiMoney_(data.framePrice, 'Harga frame'),
    'Lensa - jenis ukuran coating': olApiText_(data.lensDescription, 'Deskripsi lensa', 240, false),
    'Harga lensa': olApiMoney_(data.lensPrice, 'Harga lensa'),
    'Lain-lain': olApiText_(data.otherDescription, 'Keterangan biaya lain', 240, false),
    'Harga lain-lain': olApiMoney_(data.otherPrice, 'Harga lain-lain'),
    'DP Awal': initialPayment,
    'Metode pembayaran awal': olApiMethod_(data.initialPaymentMethod, initialPayment > 0),
    'Catatan invoice': olApiText_(data.note, 'Catatan invoice', 1000, false)
  };

  olProcessOrder_(answers, eventKey);

  const ss = SpreadsheetApp.openById(PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID'));
  const sh = ss.getSheetByName(OL.SHEET_ORDER);
  const row = olFindRow_(sh, OL_FIELDS.eventKey, eventKey);
  if (!row) throw new Error('Pesanan belum dapat diverifikasi di DATA_PESANAN.');
  const order = olReadOrder_(sh, row);
  return olApiJson_({
    ok: true,
    action: 'createOrder',
    requestId: requestId,
    invoice: order.invoice,
    total: order.total,
    paid: order.paid,
    remaining: order.remaining,
    status: order.status,
    invoicePdf: String(olGetField_(sh, row, OL_FIELDS.invoicePdf) || ''),
    processedBy: actor.email
  });
}

function olApiCreatePayment_(data, requestId, actor) {
  const eventKey = 'APP_PAYMENT_' + requestId;
  const invoice = olApiText_(data.invoice, 'Nomor invoice', 80, true);
  const date = olApiText_(data.paymentDate, 'Tanggal pembayaran', 30, true);
  if (isNaN(new Date(date).getTime())) throw new Error('Tanggal pembayaran tidak valid.');
  const category = String(data.category || '').trim();
  if (['DP tambahan', 'Cicilan', 'Pelunasan', 'Lainnya'].indexOf(category) < 0) {
    throw new Error('Keterangan pembayaran tidak valid.');
  }

  const answers = {
    'Nomor Invoice': invoice,
    'Tanggal Pembayaran': date,
    'Jumlah Pembayaran': olApiMoney_(data.amount, 'Jumlah pembayaran'),
    'Metode Pembayaran': olApiMethod_(data.method, true),
    'Keterangan Pembayaran': category,
    'Catatan': olApiText_(data.note, 'Catatan pembayaran', 1000, false)
  };

  olProcessPayment_(answers, eventKey);

  const ss = SpreadsheetApp.openById(PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID'));
  const paySheet = ss.getSheetByName(OL.SHEET_PAY);
  const payRow = olFindRow_(paySheet, OL_PAY_FIELDS.eventKey, eventKey);
  if (!payRow) throw new Error('Pembayaran belum dapat diverifikasi di DATA_PEMBAYARAN.');
  const payment = olReadPaymentForRetry_(paySheet, payRow);
  const orderSheet = ss.getSheetByName(OL.SHEET_ORDER);
  const orderRow = olFindRow_(orderSheet, OL_FIELDS.invoice, invoice);
  if (!orderRow) throw new Error('Invoice tidak ditemukan setelah pembayaran diproses.');
  const order = olReadOrder_(orderSheet, orderRow);

  return olApiJson_({
    ok: true,
    action: 'createPayment',
    requestId: requestId,
    invoice: invoice,
    receipt: String(payment.receipt || ''),
    amount: olMoney_(payment.amount),
    paid: order.paid,
    remaining: order.remaining,
    status: order.status,
    receiptPdf: String(payment.pdf || ''),
    processedBy: actor.email
  });
}

function olApiMoney_(value, label) {
  if (value === null || value === undefined || String(value).trim() === '') return 0;
  const amount = typeof value === 'number' ? value : Number(String(value).trim());
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new Error((label || 'Nominal') + ' harus berupa bilangan bulat nol atau lebih.');
  }
  return amount;
}

function olApiText_(value, label, maxLength, required) {
  const text = value === null || value === undefined ? '' : String(value).trim();
  if (required && !text) throw new Error(label + ' wajib diisi.');
  if (text.length > maxLength) throw new Error(label + ' terlalu panjang.');
  return text;
}

function olApiMethod_(value, required) {
  const method = String(value || '').trim();
  const allowed = ['Tunai', 'Transfer', 'QRIS', 'Debit/kartu', 'Lainnya'];
  if (!method && !required) return '';
  if (allowed.indexOf(method) < 0) throw new Error('Metode pembayaran tidak valid.');
  return method;
}


/** Read only the two operational tables after app-key verification. */
function olApiReadTable_(data, actor) {
  const sheetName = String(data.sheetName || '').trim();
  const allowed = [OL.SHEET_ORDER, OL.SHEET_PAY];
  if (allowed.indexOf(sheetName) < 0) throw new Error('Tab yang diminta tidak diizinkan.');

  const ss = SpreadsheetApp.openById(PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID'));
  const sh = ss.getSheetByName(sheetName);
  if (!sh) throw new Error('Tab ' + sheetName + ' tidak ditemukan.');
  const lastRow = sh.getLastRow();
  const lastCol = sh.getLastColumn();
  if (lastRow < 1 || lastCol < 1) {
    return olApiJson_({ ok: true, action: 'readTable', sheetName: sheetName, rows: [], processedBy: actor.email });
  }
  if (lastRow > 5001 || lastCol > 100) {
    throw new Error('Ukuran tabel melebihi batas aman pembacaan API.');
  }
  const range = sh.getRange(1, 1, lastRow, lastCol);
  const values = range.getDisplayValues();
  const rich = range.getRichTextValues();
  const formulas = range.getFormulas();
  const headers = values[0].map((value, index) => {
    const header = String(value || '').trim();
    return header || ('Kolom ' + (index + 1));
  });
  const rows = values.slice(1).filter(row => row.some(value => String(value || '').trim() !== '')).map((row, rowIndex) => {
    const record = {};
    headers.forEach((header, colIndex) => {
      let value = String(row[colIndex] || '').trim();
      // A Sheets cell may display friendly text while its actual PDF URL is
      // stored as a rich-text link or as =HYPERLINK(url, label). Return the
      // real URL to the APK instead of the visible label.
      if (/pdf|invoice|kuitansi|kwitansi/i.test(header)) {
        const richUrl = rich[rowIndex + 1][colIndex] &&
          rich[rowIndex + 1][colIndex].getLinkUrl();
        if (richUrl) {
          value = richUrl;
        } else {
          const formula = String(formulas[rowIndex + 1][colIndex] || '');
          const match = formula.match(/^=HYPERLINK\\(\\s*"((?:[^"]|"")+)"/i);
          if (match) value = match[1].replace(/""/g, '"');
        }
      }
      record[header] = value;
    });
    return record;
  });
  return olApiJson_({ ok: true, action: 'readTable', sheetName: sheetName, rows: rows, processedBy: actor.email });
}

function olApiJson_(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
