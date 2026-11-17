# Flutter API adapter — OPTIK LENTERA

File `FLUTTER_API_ENDPOINT.gs` adalah adapter tambahan untuk Apps Script yang sudah memuat sistem invoice/kuitansi OPTIK LENTERA.

## Pemasangan aman

1. Buka project Apps Script yang dipakai oleh Web App aktif.
2. Pastikan project itu sudah berisi fungsi lama seperti `olProcessOrder_`, `olProcessPayment_`, `olFindRow_`, `olGetField_`, serta konstanta `OL_FIELDS` dan `OL_PAY_FIELDS`.
3. Salin isi `FLUTTER_API_ENDPOINT.gs` ke file baru di project Apps Script. Jangan mengganti file lama.
4. Di **Project Settings → Script Properties**, tambahkan `OL_API_TOKEN` dengan nilai acak rahasia minimal 32 karakter. Jangan simpan token di GitHub.
5. Deploy → Manage deployments → Edit Web App → pilih **New version** → Deploy. Gunakan URL Web App yang sama.
6. Tes GET URL Web App. Respons yang diharapkan memuat `"status":"ready"`.
7. Build APK Flutter dengan token yang sama: `flutter build apk --release --dart-define=OL_API_TOKEN=TOKEN_RAHASIA`. Jangan commit token atau membagikan APK ke pihak yang tidak berwenang.

## Kontrak endpoint

POST JSON dengan header `Content-Type: application/json`.

Pesanan:
```json
{
  "token": "TOKEN_RAHASIA",
  "action": "createOrder",
  "requestId": "ORDER-UNIK-123456789",
  "order": {
    "name": "Nama pelanggan",
    "phone": "08xxxxxxxxxx",
    "address": "Alamat",
    "doctor": "",
    "odSph": "", "odCyl": "", "odAxis": "", "odAdd": "", "odPd": "",
    "osSph": "", "osCyl": "", "osAxis": "", "osAdd": "", "osPd": "",
    "lensType": "Single Vision",
    "rxNote": "",
    "frameDesc": "Frame",
    "framePrice": 300000,
    "lensDesc": "Lensa",
    "lensPrice": 250000,
    "otherDesc": "",
    "otherPrice": 0,
    "initialPayment": 100000,
    "initialPaymentMethod": "Tunai",
    "note": ""
  }
}
```

Pembayaran:
```json
{
  "token": "TOKEN_RAHASIA",
  "action": "createPayment",
  "requestId": "PAYMENT-UNIK-123456789",
  "payment": {
    "invoiceNumber": "INV-2026-0001",
    "paymentDate": "2026-11-18",
    "amount": 50000,
    "method": "Transfer",
    "category": "Cicilan",
    "note": ""
  }
}
```

Setiap `requestId` harus dipakai ulang saat mengulang request transaksi yang sama. Ini mencegah invoice/kuitansi ganda melalui kolom kunci proses internal yang sudah digunakan backend.

## Catatan keamanan

Web App yang dapat diakses aplikasi memerlukan autentikasi. Token bersama di dalam APK dapat diekstrak dari aplikasi; token ini adalah penghalang dasar untuk tahap integrasi internal, bukan pengganti autentikasi pengguna/server yang kuat. Jangan gunakan endpoint ini untuk data publik atau transaksi tanpa kontrol akses tambahan.
