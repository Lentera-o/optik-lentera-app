/**
 * OPTIK LENTERA — read-only official document lookup for Flutter.
 *
 * Install into the ACTIVE Apps Script project. Do not add another doGet().
 * Add this branch at the VERY TOP of the existing doGet(e), before token lookup:
 *
 *   if (e && e.parameter && e.parameter.action === 'documents') {
 *     return olApiGetDocuments_(e);
 *   }
 *
 * Existing Index route and receipt/invoice token verification remain unchanged.
 * No Script Properties, doPost, transaction writes, or PDF generation are used.
 */

function olApiGetDocuments_(e) {
  const p = e && e.parameter ? e.parameter : {};
  const invoice = String(p.invoice || '').trim();
  const phone = olApiNormalizePhone_(p.phone || '');

  if (!invoice || !phone) {
    return olApiJson_({
      ok: false,
      error: 'MISSING_INPUT',
      message: 'Nomor invoice dan nomor HP wajib diisi.'
    });
  }

  const ssId = PropertiesService.getScriptProperties().getProperty('OL_SPREADSHEET_ID');
  if (!ssId) {
    return olApiJson_({ ok: false, error: 'DATABASE_NOT_CONFIGURED', message: 'Database OPTIK LENTERA belum terhubung.' });
  }

  const ss = SpreadsheetApp.openById(ssId);
  const orderSheet = ss.getSheetByName(OL.SHEET_ORDER);
  const paySheet = ss.getSheetByName(OL.SHEET_PAY);

  if (!orderSheet) {
    return olApiJson_({ ok: false, error: 'ORDER_SHEET_NOT_FOUND', message: 'Tab data pesanan tidak ditemukan.' });
  }

  const orderRow = olFindRow_(orderSheet, OL_FIELDS.invoice, invoice);
  if (!orderRow) {
    return olApiJson_({ ok: false, error: 'DOCUMENT_NOT_FOUND', message: 'Invoice tidak ditemukan.' });
  }

  const orderPhone = olApiNormalizePhone_(olGetField_(orderSheet, orderRow, OL_FIELDS.phone));
  if (!orderPhone || orderPhone !== phone) {
    return olApiJson_({ ok: false, error: 'DOCUMENT_NOT_FOUND', message: 'Invoice tidak ditemukan atau data pelanggan tidak cocok.' });
  }

  const getOrder = key => olGetField_(orderSheet, orderRow, OL_FIELDS[key]);
  const receipts = [];

  if (paySheet && paySheet.getLastRow() > 1) {
    for (let row = 2; row <= paySheet.getLastRow(); row++) {
      const rowInvoice = String(olGetField_(paySheet, row, OL_PAY_FIELDS.invoice) || '').trim();
      if (rowInvoice !== invoice) continue;

      receipts.push({
        receiptNumber: olGetField_(paySheet, row, OL_PAY_FIELDS.receipt) || '',
        date: olDate_(olGetField_(paySheet, row, OL_PAY_FIELDS.date)),
        amount: olGetField_(paySheet, row, OL_PAY_FIELDS.amount) || 0,
        method: olGetField_(paySheet, row, OL_PAY_FIELDS.method) || '',
        remaining: olGetField_(paySheet, row, OL_PAY_FIELDS.remaining) || 0,
        receiptPdf: olGetField_(paySheet, row, OL_PAY_FIELDS.pdf) || ''
      });
    }
  }

  return olApiJson_({
    ok: true,
    invoiceNumber: getOrder('invoice') || invoice,
    date: olDate_(getOrder('date')),
    status: getOrder('invoiceDocStatus') || getOrder('status') || '',
    invoicePdf: getOrder('invoicePdf') || '',
    receipts: receipts
  });
}

function olApiNormalizePhone_(value) {
  let digits = String(value || '').replace(/\D/g, '');
  if (digits.indexOf('0062') === 0) {
    digits = '62' + digits.substring(4);
  } else if (digits.indexOf('0') === 0) {
    digits = '62' + digits.substring(1);
  } else if (digits.indexOf('8') === 0) {
    digits = '62' + digits;
  }
  return digits;
}

/**
 * JSON response helper. If the active project already defines olApiJson_,
 * keep the existing helper and remove this duplicate definition.
 */
function olApiJson_(data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
