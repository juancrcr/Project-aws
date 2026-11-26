# Design Brief — Sistem Peminjaman Alat Lab (Equipment Loans)

**Mata Kuliah:** AWS Cloud Computing — Individual Project (Week 12)  
**Track Terpilih:** Track C | Serverless (`Amazon API Gateway` + `AWS Lambda` + `Amazon DynamoDB`)  
**Use Case:** Equipment Loans (Manajemen Peminjaman Alat Laboratorium/Kampus)

---

## 1. Latar Belakang & Use Case
Laboratorium kampus atau unit inventaris sering kali masih mencatat peminjaman alat (seperti oscilloscope, multimeter, router, kamera, atau proyektor) secara manual menggunakan spreadsheet atau buku log. Hal ini menyulitkan pelacakan status alat yang sedang dipinjam, siapa peminjamnya, dan kapan alat harus dikembalikan.

Aplikasi **Equipment Loans API** menyediakan backend berbasis REST/HTTP API yang ringan untuk mencatat peminjaman baru, melihat daftar peminjaman aktif, memperbarui status saat alat dikembalikan, serta menghapus data uji/tidak valid.

## 2. Alasan Pemilihan Track C (Serverless)
1. **Efisien untuk AWS Learner Lab:** Tidak memerlukan waktu tunggu provisioning database relasional (RDS) maupun konfigurasi VPC/Security Group/SSH seperti pada Track A/B.
2. **Hemat Kredit & Auto-Scaling:** API Gateway, Lambda, dan DynamoDB (On-Demand) hanya mengenakan biaya saat ada request masuk (*pay-per-use*), sehingga sangat aman terhadap batas kredit AWS Learner Lab.
3. **Kesesuaian IAM Learner Lab:** AWS Lambda dapat langsung menggunakan pre-configured role **`LabRole`** yang sudah memiliki izin akses DynamoDB dan CloudWatch Logs tanpa perlu membuat custom IAM Role baru.

## 3. Data Entity: `EquipmentLoan`
Sistem menggunakan **1 entitas utama** yang disimpan pada tabel Amazon DynamoDB bernama `equipment-loans`.

| Atribut | Tipe Data | Keterangan | Wajib |
|---|---|---|---|
| `loan_id` | `String` | **Partition Key** (UUID v4, di-generate otomatis saat `POST`) | Ya |
| `borrower_name` | `String` | Nama lengkap peminjam | Ya |
| `borrower_id` | `String` | NIM / NIP / ID peminjam | Ya |
| `equipment_name` | `String` | Nama alat yang dipinjam | Ya |
| `quantity` | `Number` | Jumlah unit yang dipinjam (minimal `1`) | Ya |
| `status` | `String` | Status peminjaman: `BORROWED` (default) atau `RETURNED` | Ya |
| `borrowed_at` | `String` | Timestamp waktu pinjam (ISO-8601 UTC) | Ya |
| `due_date` | `String` | Target tanggal pengembalian (`YYYY-MM-DD`) | Ya |
| `returned_at` | `String` | Timestamp pengembalian (diisi otomatis saat status menjadi `RETURNED`) | Tidak |

## 4. Spesifikasi 4 CRUD Endpoints (+ Health Check)

Selain endpoint `GET /health` untuk verifikasi konektivitas awal, sistem menyediakan 4 operasi CRUD utama:

### 1) Create — `POST /loans`
Mencatat transaksi peminjaman alat baru.
- **Request Body:**
```json
{
  "borrower_name": "Budi Santoso",
  "borrower_id": "220123456",
  "equipment_name": "Oscilloscope Rigol DS1054Z",
  "quantity": 1,
  "due_date": "2026-12-03"
}
```
- **Response (`201 Created`):** Mengembalikan objek `EquipmentLoan` lengkap dengan `loan_id`, `status: "BORROWED"`, dan `borrowed_at`.

### 2) Read — `GET /loans` & `GET /loans/{loan_id}`
Mengambil seluruh daftar peminjaman (`GET /loans`) atau detail satu transaksi berdasarkan `loan_id` (`GET /loans/{loan_id}`).
- **Response (`200 OK`):**
```json
{
  "count": 1,
  "items": [
    {
      "loan_id": "a1b2c3d4-...",
      "borrower_name": "Budi Santoso",
      "borrower_id": "220123456",
      "equipment_name": "Oscilloscope Rigol DS1054Z",
      "quantity": 1,
      "status": "BORROWED",
      "borrowed_at": "2026-11-26T04:30:00+00:00",
      "due_date": "2026-12-03"
    }
  ]
}
```

### 3) Update — `PUT /loans/{loan_id}`
Memperbarui status peminjaman (misalnya menandai alat telah dikembalikan) atau mengubah `due_date` / `quantity`. Jika `status` diubah menjadi `"RETURNED"`, server otomatis mengisi `returned_at`.
- **Request Body:**
```json
{
  "status": "RETURNED"
}
```
- **Response (`200 OK`):** Mengembalikan item yang sudah diperbarui.

### 4) Delete — `DELETE /loans/{loan_id}`
Menghapus data peminjaman berdasarkan `loan_id`.
- **Response (`200 OK`):**
```json
{
  "message": "Loan deleted",
  "loan_id": "a1b2c3d4-..."
}
```
