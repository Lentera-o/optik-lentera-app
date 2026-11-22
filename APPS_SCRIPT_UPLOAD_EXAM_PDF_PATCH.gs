/*
 * PATCH TERPISAH: Upload PDF hasil pemeriksaan ke folder Drive OPTIK LENTERA.
 *
 * 1) Di doPost(e), ubah batas raw.length dari 50000 menjadi 2000000.
 * 2) Setelah requestId divalidasi, sebelum pemeriksaan action tidak dikenal,
 *    sisipkan blok route berikut:
 *
 *    if (action === 'uploadExaminationPdf') {
 *      if (!request.data || typeof request.data !== 'object' || Array.isArray(request.data)) {
 *        throw new Error('Data PDF pemeriksaan tidak valid.');
 *      }
 *      const uploadLock = LockService.getScriptLock();
 *      uploadLock.waitLock(30000);
 *      try {
 *        return olApiUploadExaminationPdf_(request.data, requestId, actor);
 *      } finally {
 *        uploadLock.releaseLock();
 *      }
 *    }
 *
 * 3) Tambahkan fungsi di bawah ini sebagai fungsi baru.
 *
 * Tidak mengubah mesin invoice/kuitansi, sheet, trigger, atau folder.
 * Fungsi memakai Script Property OL_FOLDER_ID yang sudah dipakai sistem PDF.
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

  // Reuse the existing official PDF folder. Never create a new folder here.
  const folderId = PropertiesService.getScriptProperties().getProperty('OL_FOLDER_ID');
  if (!folderId) {
    throw new Error('Folder PDF OPTIK LENTERA belum terhubung (OL_FOLDER_ID).');
  }
  const folder = DriveApp.getFolderById(folderId);
  folder.getName(); // Force an access check before reporting success.

  // Idempotent retry: if the same named PDF with the same byte size exists,
  // return it instead of creating duplicate Drive files.
  const existingFiles = folder.getFilesByName(fileName);
  const previousFiles = [];
  while (existingFiles.hasNext()) previousFiles.push(existingFiles.next());

  for (let i = 0; i < previousFiles.length; i++) {
    if (previousFiles[i].getSize() === bytes.length) {
      return olApiJson_({
        ok: true,
        action: 'uploadExaminationPdf',
        examId: examId,
        fileId: previousFiles[i].getId(),
        fileUrl: previousFiles[i].getUrl(),
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

  // Only remove stale same-name copies after the replacement is verified.
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
