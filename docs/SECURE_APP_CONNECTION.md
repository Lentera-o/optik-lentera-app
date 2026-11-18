# OPTIK LENTERA — Secure app connection checklist

Dokumen ini mencatat implementasi pada branch `feature/read-only-sheet-sync` dan syarat yang masih harus dipenuhi sebelum transaksi langsung diaktifkan pada deployment produksi.

## Status implementasi pada kode Flutter

- Google Sign-In tetap wajib. Aplikasi meminta Google ID token; pemeriksaan token tidak boleh dihapus.
- Backend mewajibkan allowlist email petugas melalui Script Property `OL_ALLOWED_EMAILS`; akun Google di luar daftar ditolak.
- Layar pesanan dan pembayaran menggunakan `ApiService.createOrder` dan `ApiService.createPayment`; penyimpanan transaksi dirancang melalui Apps Script, bukan pengiriman Google Forms.
- Request transaksi membawa `requestId` stabil untuk membantu mencegah pengiriman ulang sebagai transaksi baru ketika pengguna mencoba ulang.
- Pusat WhatsApp memilih nomor dari invoice/pesanan yang dipilih, dengan normalisasi nomor lokal dan internasional.
- Analyze, tests, validasi konfigurasi Google Sign-In, build release APK, dan upload artefak pada GitHub Actions run `44166793628` telah berhasil.

## Status backend — BELUM AKTIF DI PRODUKSI

File `OptikLenteraApi.gs` di repository adalah modul tambahan. File tersebut bergantung pada project Apps Script lama yang berisi `OPTIK_LENTERA_FINAL_AMAN.gs` dan fungsi pemrosesan invoice/kuitansi yang sudah ada.

Fungsi lama yang harus tetap dipertahankan:
- `olProcessOrder_` dan `olProcessPayment_`
- penomoran invoice/kuitansi dan pencatatan DP/cicilan/pelunasan
- pembuatan serta pembaruan PDF invoice dan kuitansi
- helper pembacaan/penulisan sheet dan verifikasi QR/token
- semua trigger, tab, data historis, Google Forms, dan folder/file Drive

**Jangan mengganti seluruh project Apps Script dengan file API ini.** Tambahkan dan integrasikan modul hanya setelah sumber lengkap project lama diverifikasi. Deployment Web App aktif belum diperbarui dari perubahan GitHub ini. Belum ada transaksi produksi yang dijalankan atau diklaim berhasil.

## Konfigurasi yang diperlukan di Apps Script

Script Properties yang harus diverifikasi pada project yang benar:
- `OL_SPREADSHEET_ID`: ID spreadsheet operasional yang memang digunakan oleh project lama.
- `OL_GOOGLE_WEB_CLIENT_ID`: OAuth Web client ID yang menjadi audience ID token.
- `OL_ALLOWED_EMAILS`: daftar email petugas resmi dipisahkan koma atau titik koma. Wajib diisi; API menolak semua akses jika kosong.

Deployment Web App harus menggunakan identitas pemilik yang tepat. Google ID token diverifikasi issuer, audience, expiry, dan email terverifikasi, lalu email harus cocok dengan `OL_ALLOWED_EMAILS`. Jangan memasukkan OAuth client secret atau private key ke APK/repository. Jangan memasukkan OAuth client secret atau private key ke APK/repository.

## Pemeriksaan sebelum transaksi produksi

- [ ] Cocokkan seluruh sumber Apps Script lama dan pastikan semua fungsi invoice/kuitansi/DP tetap tersedia.
- [ ] Periksa kontrak nama kolom `answers` API terhadap `OL_FIELDS`, `OL_PAY_FIELDS`, dan header sheet yang benar.
- [ ] Verifikasi idempotensi `eventKey` pada kedua processor untuk retry request yang sama.
- [ ] Verifikasi validasi nominal, saldo tagihan, dan pencegahan pembayaran berlebih pada processor lama.
- [ ] Pastikan konfigurasi OAuth Web client ID dan spreadsheet ID berada pada project Apps Script yang benar.
- [ ] Uji dengan spreadsheet dan folder Drive khusus pengujian; jangan membuat transaksi dummy pada data pelanggan produksi.
- [ ] Uji Google Sign-In pada perangkat Android dengan signing key rilis yang benar.
- [ ] Uji createOrder, createPayment, retry request, invoice PDF, kuitansi PDF, dan refresh data end-to-end.
- [ ] Tinjau akses baca Google Sheets. Jangan mengekspos data pelanggan melalui CSV publik; gunakan endpoint terautentikasi atau konfigurasi akses yang secara eksplisit disetujui pemilik.
- [ ] Perbarui deployment Web App hanya setelah seluruh pemeriksaan lulus dan project lama aman.
- [ ] Lakukan uji penerimaan pada perangkat sebelum rilis ke operasional.

## Batas keselamatan perubahan

Jangan menghapus atau mengubah tab/data Sheets, konfigurasi Forms, trigger, folder/file Drive, Firebase, template invoice/kuitansi, maupun modul operasional lain sebagai bagian integrasi ini. Jangan merge atau deploy hanya berdasarkan keberhasilan build Flutter. Build sukses tidak membuktikan koneksi Apps Script atau transaksi Sheets berhasil.
