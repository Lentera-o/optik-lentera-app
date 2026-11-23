/**
 * OPTIK LENTERA — App-key Flutter transaction API (no Google sign-in)
 *
 * Add this file to the EXISTING Apps Script project that already contains
 * OPTIK_LENTERA_FINAL_AMAN.gs. It reuses the existing invoice, receipt,
 * numbering, spreadsheet, and PDF functions; it does not replace triggers.
 *
 * Required Script Properties:
 *   OL_SPREADSHEET_ID           = ID spreadsheet operasional OPTIK LENTERA
 *   OL_APP_API_KEY              = same long random key configured as GitHub Actions secret
 *
 * Deploy the existing Web App as "Execute as me". The endpoint may be
 * reachable publicly; every action requires the OL_APP_API_KEY configured
 * in Script Properties and injected into the APK at build time.
 *
 * Request JSON:
 * {
 *   "action": "readTable" | "createOrder" | "createPayment" |
 *             "saveExamination" | "uploadExaminationPdf",
 *   "requestId": "<unique UUID generated once per user submission>",
 *   "apiKey": "<application API key>",
 *   "data": { ... }
 * }
 *
 * Do not use this model for highly sensitive public-facing deployments.
 */

function doPost(e) {
  try {
    const raw = e && e.postData && e.postData.contents
      ? String(e.postData.contents)
      : '';
    if (!raw || raw.length > 2000000) {
      return olApiJson_({ ok: false, error: 'Payload kosong atau terlalu besar.' });
    }

    const request = JSON.parse(raw);
    if (!request || typeof request !== 'object' || Array.isArray(request)) {
      throw new Error('Format permintaan tidak valid.');
    }

    // Verify the app key before any read or write operation.
    const actor = olApiVerifyAppKey_(request.apiKey);
    const action = String(request.action || '');
    if (action === 'readTable') {
      if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
        throw new Error('Parameter pembacaan tidak valid.');
      }
      return olApiReadTable_(request.data, actor);
    }
    // Status pengerjaan adalah pembaruan operasional terpisah dari transaksi.
    // Aksi ini tidak membuat invoice/pembayaran dan tidak memerlukan requestId.
    if (action === 'updateOrderStatus') {
      if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
        throw new Error('Data pembaruan status tidak valid.');
      }
      const statusLock = LockService.getScriptLock();
      statusLock.waitLock(30000);
      try {
        return olApiUpdateOrderStatus_(request.data, actor);
      } finally {
        statusLock.releaseLock();
      }
    }
    const requestId = String(request.requestId || '');
    if (!/^[A-Za-z0-9_-]{16,80}$/.test(requestId)) {
      throw new Error('ID permintaan tidak valid.');
    }
    if (action === 'uploadExaminationPdf') {
      if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
        throw new Error('Data PDF pemeriksaan tidak valid.');
      }
      const uploadLock = LockService.getScriptLock();
      uploadLock.waitLock(30000);
      try {
        return olApiUploadExaminationPdf_(request.data, requestId, actor);
      } finally {
        uploadLock.releaseLock();
      }
    }
    if (action !== 'createOrder' && action !== 'createPayment' && action !== 'saveExamination') {
      throw new Error('Aksi transaksi tidak dikenal.');
    }
    if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
      throw new Error('Data transaksi tidak valid.');
    }

    const lock = LockService.getScriptLock();
    lock.waitLock(30000);
    try {
      if (action === 'createOrder') return olApiCreateOrder_(request.data, requestId, actor);
      if (action === 'createPayment') return olApiCreatePayment_(request.data, requestId, actor);
      return olApiSaveExamination_(request.data, requestId, actor);
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
  const expected = String(PropertiesService.getScriptProperties().getProperty('OL_APP_API_KEY') || '').trim();
  const supplied = String(providedKey || '').trim();
  if (expected.length < 32) throw new Error('Kunci aplikasi belum dipasang di Script Properties.');
  if (supplied.length !== expected.length) throw new Error('Kunci koneksi aplikasi tidak valid.');
  let mismatch = 0;
  for (let i = 0; i < expected.length; i++) mismatch |= expected.charCodeAt(i) ^ supplied.charCodeAt(i);
  if (mismatch !== 0) throw new Error('Kunci koneksi aplikasi tidak valid.');
  return { email: 'Aplikasi OPTIK LENTERA', name: 'APK' };
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

  // Keep the production processor result so the invoice verification URL
  // generated with the invoice token is returned to the Flutter app.
  const processedOrder = olProcessOrder_(answers, eventKey) || {};

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
    invoicePdf: String(olGetField_(sh, row, OL_FIELDS.invoicePdf) || processedOrder.invoicePdf || ''),
    invoiceVerificationUrl: String(processedOrder.invoiceVerificationUrl || processedOrder.verificationUrl || ''),
    verificationUrl: String(processedOrder.verificationUrl || processedOrder.invoiceVerificationUrl || ''),
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

/**
 * Update only the work-progress field on an existing order.
 * Existing invoice, payment, customer and prescription fields remain untouched.
 */
function olApiUpdateOrderStatus_(data, actor) {
  const invoice = olApiText_(data.invoice, 'Nomor invoice', 80, true);
  const status = olApiText_(data.status, 'Status pengerjaan', 40, true);
  const allowed = [
    'Menunggu diproses',
    'Sedang dikerjakan',
    'Siap diambil',
    'Sudah diserahkan'
  ];
  if (allowed.indexOf(status) < 0) {
    throw new Error('Pilihan status pengerjaan tidak valid.');
  }

  const spreadsheetId = String(
    PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID') || ''
  ).trim();
  if (!spreadsheetId) throw new Error('ID spreadsheet operasional belum dipasang.');

  const ss = SpreadsheetApp.openById(spreadsheetId);
  const sh = ss.getSheetByName(OL.SHEET_ORDER);
  if (!sh) throw new Error('Tab DATA_PESANAN tidak ditemukan.');

  const row = olFindRow_(sh, OL_FIELDS.invoice, invoice);
  if (!row) throw new Error('Invoice ' + invoice + ' tidak ditemukan di DATA_PESANAN.');

  const statusField = ['Status Pengerjaan'];
  olEnsureColumn_(sh, statusField);
  olSetField_(sh, row, statusField, status);
  SpreadsheetApp.flush();

  return olApiJson_({
    ok: true,
    action: 'updateOrderStatus',
    invoice: invoice,
    status: status,
    processedBy: actor && actor.email ? actor.email : 'Aplikasi OPTIK LENTERA'
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
  const allowed = [OL.SHEET_ORDER, OL.SHEET_PAY, 'DATA_PEMERIKSAAN'];
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
  const values = sh.getRange(1, 1, lastRow, lastCol).getDisplayValues();
  const headers = values[0].map((value, index) => {
    const header = String(value || '').trim();
    return header || ('Kolom ' + (index + 1));
  });
  const rows = values.slice(1).filter(row => row.some(value => String(value || '').trim() !== '')).map(row => {
    const record = {};
    headers.forEach((header, index) => { record[header] = String(row[index] || ''); });
    return record;
  });
  return olApiJson_({ ok: true, action: 'readTable', sheetName: sheetName, rows: rows, processedBy: actor.email });
}

function olApiJson_(value) {
  return ContentService
    .createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}


/**
 * Save an independent refractive examination without creating an order,
 * invoice, payment, or receipt. Creates only the dedicated examination tab.
 */
function olApiSaveExamination_(data, requestId, actor) {
  const eventKey = 'APP_EXAM_' + requestId;
  const spreadsheetId = String(PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID') || '').trim();
  if (!spreadsheetId) throw new Error('ID spreadsheet operasional belum dipasang.');

  const ss = SpreadsheetApp.openById(spreadsheetId);
  const sheetName = 'DATA_PEMERIKSAAN';
  const requiredHeaders = [
    'ID Pemeriksaan','Event Key','Tanggal Pemeriksaan','Nama Pelanggan','Nomor HP/WA','Alamat',
    'OD SPH','OD CYL','OD AXIS','OD ADD','OD PD',
    'OS SPH','OS CYL','OS AXIS','OS ADD','OS PD',
    'Jenis Lensa','Catatan Pemeriksaan','QR Payload','Dibuat Oleh'
  ];

  let sh = ss.getSheetByName(sheetName);
  if (!sh) sh = ss.insertSheet(sheetName);

  // Preserve the existing examination tab and all its data. Add only missing
  // API columns at the end; never replace or reorder existing columns.
  let lastCol = sh.getLastColumn();
  if (lastCol === 0) {
    sh.getRange(1, 1, 1, requiredHeaders.length).setValues([requiredHeaders]);
    sh.setFrozenRows(1);
    lastCol = requiredHeaders.length;
  } else {
    let headers = sh.getRange(1, 1, 1, lastCol).getDisplayValues()[0].map(v => String(v || '').trim());
    requiredHeaders.forEach(function(header) {
      if (headers.indexOf(header) < 0) {
        lastCol += 1;
        sh.getRange(1, lastCol).setValue(header);
        headers.push(header);
      }
    });
  }

  const headers = sh.getRange(1, 1, 1, sh.getLastColumn()).getDisplayValues()[0].map(v => String(v || '').trim());
  const col = {};
  headers.forEach(function(header, index) {
    if (header && col[header] === undefined) col[header] = index + 1;
  });

  const eventCol = col['Event Key'];
  if (sh.getLastRow() > 1) {
    const existing = sh.getRange(2, eventCol, sh.getLastRow() - 1, 1).getDisplayValues();
    for (let i = 0; i < existing.length; i++) {
      if (String(existing[i][0]) === eventKey) {
        const row = i + 2;
        return olApiJson_({
          ok: true,
          action: 'saveExamination',
          examId: String(sh.getRange(row, col['ID Pemeriksaan']).getDisplayValue()),
          qrPayload: String(sh.getRange(row, col['QR Payload']).getDisplayValue()),
          reused: true,
          processedBy: actor.email
        });
      }
    }
  }

  const date = olApiText_(data.examDate, 'Tanggal pemeriksaan', 40, true);
  if (isNaN(new Date(date).getTime())) throw new Error('Tanggal pemeriksaan tidak valid.');
  const name = olApiText_(data.name, 'Nama pelanggan', 120, true);
  const examId = 'RE-' + Utilities.formatDate(new Date(date), Session.getScriptTimeZone(), 'yyyyMMdd') + '-' + Utilities.getUuid().slice(0, 8).toUpperCase();
  const qrPayload = 'OPTIK-LENTERA|REFRAKSI|' + examId;

  const values = {
    'ID Pemeriksaan': examId,
    'Event Key': eventKey,
    'Tanggal Pemeriksaan': date,
    'Nama Pelanggan': name,
    'Nomor HP/WA': olApiText_(data.phone, 'Nomor HP/WA', 40, false),
    'Alamat': olApiText_(data.address, 'Alamat', 500, false),
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
    'Jenis Lensa': olApiText_(data.lensType, 'Jenis lensa', 160, false),
    'Catatan Pemeriksaan': olApiText_(data.note, 'Catatan pemeriksaan', 1000, false),
    'QR Payload': qrPayload,
    'Dibuat Oleh': String(actor.email || 'APK')
  };

  const newRow = sh.getLastRow() + 1;
  Object.keys(values).forEach(function(header) {
    sh.getRange(newRow, col[header]).setValue(values[header]);
  });

  return olApiJson_({
    ok: true,
    action: 'saveExamination',
    examId: examId,
    qrPayload: qrPayload,
    reused: false,
    processedBy: actor.email
  });
}

/**
 * Upload only the prescription PDF for an existing examination.
 * Does not create examination-fee receipts or fee statements.
 */
function olApiUploadExaminationPdf_(data, requestId, actor) {
  const examId = String(data.examId || '').trim();
  if (!examId || examId.length > 120) throw new Error('Nomor pemeriksaan tidak valid.');
  const safeId = examId.replace(/[^A-Za-z0-9_-]/g, '_');
  const fileName = 'Hasil_Pemeriksaan_' + safeId + '.pdf';
  if (String(data.fileName || '') !== fileName) throw new Error('Nama file PDF tidak sesuai dengan nomor pemeriksaan.');

  const pdfBase64 = String(data.pdfBase64 || '').trim();
  if (!pdfBase64 || pdfBase64.length > 1600000) throw new Error('Data PDF kosong atau melebihi batas ukuran.');
  let bytes;
  try { bytes = Utilities.base64Decode(pdfBase64); }
  catch (error) { throw new Error('Data PDF tidak dapat dibaca.'); }
  if (!bytes || bytes.length < 100 || bytes.length > 1200000) throw new Error('Ukuran PDF tidak valid.');
  const signature = String.fromCharCode(bytes[0]&255,bytes[1]&255,bytes[2]&255,bytes[3]&255,bytes[4]&255);
  if (signature !== '%PDF-') throw new Error('Berkas yang dikirim bukan PDF yang valid.');

  const folder = DriveApp.getFolderById('16cAhjCREFndJypd1GqvS79KklfhRhnn9');
  folder.getName();
  const incomingHash = Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.MD5,bytes));
  const existingFiles = folder.getFilesByName(fileName);
  while (existingFiles.hasNext()) {
    const oldFile = existingFiles.next();
    const oldHash = Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.MD5,oldFile.getBlob().getBytes()));
    if (oldHash === incomingHash) {
      olApiLinkExamPrescriptionPdf_(examId,oldFile.getUrl());
      return olApiJson_({ok:true,action:'uploadExaminationPdf',requestId:requestId,examId:examId,fileId:oldFile.getId(),fileUrl:oldFile.getUrl(),processedBy:actor&&actor.email?actor.email:'Aplikasi'});
    }
  }

  const file = folder.createFile(Utilities.newBlob(bytes,'application/pdf',fileName));
  if (file.getSize() !== bytes.length) { file.setTrashed(true); throw new Error('PDF gagal diverifikasi setelah diunggah ke Google Drive.'); }
  const savedHash = Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.MD5,file.getBlob().getBytes()));
  if (savedHash !== incomingHash) { file.setTrashed(true); throw new Error('Isi PDF di Google Drive tidak cocok dengan file sumber.'); }
  olApiLinkExamPrescriptionPdf_(examId,file.getUrl());
  return olApiJson_({ok:true,action:'uploadExaminationPdf',requestId:requestId,examId:examId,fileId:file.getId(),fileUrl:file.getUrl(),processedBy:actor&&actor.email?actor.email:'Aplikasi'});
}

function olApiLinkExamPrescriptionPdf_(examId,fileUrl) {
  const spreadsheetId = PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID');
  if (!spreadsheetId) throw new Error('ID spreadsheet operasional belum dipasang.');
  const ss = SpreadsheetApp.openById(spreadsheetId);
  const sh = ss.getSheetByName('DATA_PEMERIKSAAN');
  if (!sh || sh.getLastRow() < 2) throw new Error('Data pemeriksaan untuk resep tidak ditemukan.');
  const headers = sh.getRange(1,1,1,sh.getLastColumn()).getDisplayValues()[0].map(String);
  const idCol = headers.indexOf('ID Pemeriksaan') + 1;
  if (idCol < 1) throw new Error('Kolom ID pemeriksaan belum tersedia.');
  let pdfCol = headers.indexOf('PDF Resep Pemeriksaan') + 1;
  if (pdfCol < 1) {
    pdfCol = sh.getLastColumn()+1;
    sh.getRange(1,pdfCol).setValue('PDF Resep Pemeriksaan');
  }
  const ids = sh.getRange(2,idCol,sh.getLastRow()-1,1).getDisplayValues();
  for (let i=0;i<ids.length;i++) {
    if (String(ids[i][0]) === examId) {
      sh.getRange(i+2,pdfCol).setValue(fileUrl);
      return;
    }
  }
  throw new Error('ID pemeriksaan tidak ditemukan untuk menautkan PDF resep.');
}
