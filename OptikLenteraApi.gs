/**
 * OPTIK LENTERA — Secure Flutter transaction API
 *
 * Add this file to the EXISTING Apps Script project that already contains
 * OPTIK_LENTERA_FINAL_AMAN.gs. It reuses the existing invoice, receipt,
 * numbering, spreadsheet, and PDF functions; it does not replace triggers.
 *
 * Required Script Properties:
 *   OL_GOOGLE_WEB_CLIENT_ID     = OAuth Web client ID used as ID-token audience
 *
 * Deploy the existing Web App as "Execute as me". The endpoint may be
 * reachable publicly, but every write is rejected unless its Google ID token
 * is valid and its email is ACTIVE in PENGATURAN_PETUGAS.
 *
 * Request JSON:
 * {
 *   "action": "createOrder" | "createPayment",
 *   "requestId": "<unique UUID generated once per user submission>",
 *   "idToken": "<Google Sign-In ID token>",
 *   "data": { ... }
 * }
 *
 * Never put OAuth client secrets or shared API passwords in the Flutter app.
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

    // Verify Google identity before taking the spreadsheet lock.
    const actor = olApiVerifyGoogleIdToken_(request.idToken);
    const action = String(request.action || '');
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
      // Re-check active staff status immediately before any write.
      olApiAssertActiveStaff_(actor.email);
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

function olApiVerifyGoogleIdToken_(token) {
  token = String(token || '');
  if (!token || token.length > 10000 || token.split('.').length !== 3) {
    throw new Error('Silakan masuk kembali dengan Google.');
  }

  const props = PropertiesService.getScriptProperties();
  const webClientId = String(props.getProperty('OL_GOOGLE_WEB_CLIENT_ID') || '').trim();
  if (!webClientId) {
    throw new Error('Autentikasi Google belum dikonfigurasi oleh administrator.');
  }

  const url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(token);
  const response = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (response.getResponseCode() !== 200) {
    throw new Error('Sesi Google tidak valid atau sudah kedaluwarsa. Silakan masuk kembali.');
  }

  const claims = JSON.parse(response.getContentText());
  const issuer = String(claims.iss || '');
  const expiresAt = Number(claims.exp || 0);
  const now = Math.floor(Date.now() / 1000);
  const verified = claims.email_verified === true || String(claims.email_verified).toLowerCase() === 'true';

  if (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') {
    throw new Error('Penerbit token Google tidak valid.');
  }
  if (String(claims.aud || '') !== webClientId) {
    throw new Error('Token bukan untuk aplikasi OPTIK LENTERA.');
  }
  if (!expiresAt || expiresAt <= now || expiresAt > now + 3600) {
    throw new Error('Sesi Google tidak valid atau sudah kedaluwarsa.');
  }
  if (!verified) throw new Error('Email Google belum terverifikasi.');

  const email = String(claims.email || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Akun Google tidak memiliki email yang valid.');
  }
  olApiAssertActiveStaff_(email);
  return { email: email, name: String(claims.name || '') };
}

function olApiAssertActiveStaff_(email) {
  const normalized = String(email || '').trim().toLowerCase();
  const active = olGetStaffEmails_().some(person => person.email === normalized);
  if (!active) throw new Error('Akun ini tidak terdaftar sebagai petugas AKTIF OPTIK LENTERA.');
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

function olApiJson_(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
