/*
 * PATCH TERPISAH: upload PDF pemeriksaan ke folder Drive yang sudah ditentukan.
 *
 * Folder tujuan: 16cAhjCREFndJypd1GqvS79KklfhRhnn9
 *
 * A) Di doPost(e), naikkan batas raw.length dari 50000 menjadi 2000000.
 * B) Setelah requestId divalidasi dan sebelum validasi action transaksi,
 *    tambahkan route uploadExaminationPdf seperti di bawah.
 * C) Tambahkan fungsi olApiUploadExaminationPdf_ ini sebagai fungsi baru.
 *
 * Jangan mengganti doPost seluruhnya. Jangan mengubah fungsi invoice,
 * kuitansi, spreadsheet, trigger, atau konfigurasi folder yang sudah ada.
 */

function olApiUploadExaminationPdf_(data, requestId, actor) {
  const examId = String(data.examId || '').trim();
  if (!examId || examId.length > 120) {
    throw new Error('Nomor pemeriksaan tidak valid.');
  }

  const safeId = examId.replace(/[^A-Za-z0-9_-]/g, '_');
  const fileName = 'Hasil_Pemeriksaan_' + safeId + '.pdf';
  if (String(data.fileName || '') !== fileName) {
    throw new Error('Nama file PDF tidak sesuai dengan nomor pemeriksaan.');
  }

  const pdfBase64 = String(data.pdfBase64 || '').trim();
  if (!pdfBase64 || pdfBase64.length > 1600000) {
    throw new Error('Data PDF kosong atau melebihi batas ukuran.');
  }

  let bytes;
  try {
    bytes = Utilities.base64Decode(pdfBase64);
  } catch (error) {
    throw new Error('Data PDF tidak dapat dibaca.');
  }
  if (!bytes || bytes.length < 100 || bytes.length > 1200000) {
    throw new Error('Ukuran PDF tidak valid.');
  }

  const signature = String.fromCharCode(
    bytes[0] & 255, bytes[1] & 255, bytes[2] & 255,
    bytes[3] & 255, bytes[4] & 255
  );
  if (signature !== '%PDF-') {
    throw new Error('Berkas yang dikirim bukan PDF yang valid.');
  }

  // Folder ID berasal dari tautan folder yang diberikan pemilik aplikasi.
  // Tidak membuat folder baru dan tidak bergantung pada Script Property.
  const folder = DriveApp.getFolderById('16cAhjCREFndJypd1GqvS79KklfhRhnn9');
  folder.getName(); // Pastikan akun eksekusi Web App dapat mengakses folder.

  const incomingHash = Utilities.base64Encode(
    Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, bytes)
  );
  const existingFiles = folder.getFilesByName(fileName);
  const previousFiles = [];

  while (existingFiles.hasNext()) {
    const oldFile = existingFiles.next();
    previousFiles.push(oldFile);
    const oldHash = Utilities.base64Encode(
      Utilities.computeDigest(
        Utilities.DigestAlgorithm.MD5,
        oldFile.getBlob().getBytes()
      )
    );
    if (oldHash === incomingHash) {
      return olApiJson_({
        ok: true,
        action: 'uploadExaminationPdf',
        examId: examId,
        fileId: oldFile.getId(),
        fileUrl: oldFile.getUrl(),
        processedBy: actor && actor.email ? actor.email : 'Aplikasi'
      });
    }
  }

  const blob = Utilities.newBlob(bytes, 'application/pdf', fileName);
  const file = folder.createFile(blob);
  if (file.getSize() !== bytes.length) {
    file.setTrashed(true);
    throw new Error('PDF gagal diverifikasi setelah diunggah ke Google Drive.');
  }

  // Verifikasi checksum file hasil upload sebelum menghapus salinan lama.
  const savedHash = Utilities.base64Encode(
    Utilities.computeDigest(
      Utilities.DigestAlgorithm.MD5,
      file.getBlob().getBytes()
    )
  );
  if (savedHash !== incomingHash) {
    file.setTrashed(true);
    throw new Error('Isi PDF di Google Drive tidak cocok dengan file sumber.');
  }

  previousFiles.forEach(function(oldFile) {
    oldFile.setTrashed(true);
  });

  return olApiJson_({
    ok: true,
    action: 'uploadExaminationPdf',
    examId: examId,
    fileId: file.getId(),
    fileUrl: file.getUrl(),
    processedBy: actor && actor.email ? actor.email : 'Aplikasi'
  });
}

/*
 * Route yang perlu disisipkan ke doPost(e), setelah requestId lolos validasi:
 *
 * if (action === 'uploadExaminationPdf') {
 *   if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
 *     throw new Error('Data PDF pemeriksaan tidak valid.');
 *   }
 *   const uploadLock = LockService.getScriptLock();
 *   uploadLock.waitLock(30000);
 *   try {
 *     return olApiUploadExaminationPdf_(request.data, requestId, actor);
 *   } finally {
 *     uploadLock.releaseLock();
 *   }
 * }
 *
 * Catatan: jangan menambahkan action ini ke blok whitelist createOrder /
 * createPayment; route khusus di atas harus dijalankan lebih dahulu.
 */
