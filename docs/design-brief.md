# Design Brief: Sistem Peminjaman Alat Lab

Mata Kuliah: AWS Cloud Computing Week 12
Track: Track C Serverless dengan Lambda Function URL, AWS Lambda, dan Amazon DynamoDB
Use Case: Equipment Loans

## 1. Latar Belakang
Peminjaman alat laboratorium seperti oscilloscope, multimeter, dan perangkat jaringan sering masih dicatat manual di spreadsheet. Sistem Equipment Loans API menyediakan endpoint HTTP untuk mencatat peminjaman baru, melihat daftar peminjaman, memperbarui status pengembalian, dan menghapus data.

## 2. Alasan Memilih Track C Serverless
1. Setup cepat di AWS Sandbox yang memiliki batas waktu 3 jam karena tidak perlu menunggu provisioning RDS atau konfigurasi VPC dan SSH.
2. Biaya ringan karena Lambda Function URL, Lambda, dan DynamoDB On Demand hanya dihitung saat ada request.
3. Cocok dengan aturan IAM sandbox. Role `voclabs` tidak diizinkan memanggil `apigateway:POST` dan `dynamodb:CreateTable` secara langsung, sedangkan Lambda dengan `LabRole` memiliki akses penuh DynamoDB di `us-east-1` dan dapat diakses melalui Lambda Function URL.

## 3. Data Entity: `EquipmentLoan`
Data disimpan pada tabel DynamoDB `equipment-loans` dengan rincian atribut:

| Atribut | Tipe Data | Keterangan |
|---|---|---|
| `loan_id` | `String` | Partition Key berupa UUID v4 yang dibuat otomatis saat `POST` |
| `borrower_name` | `String` | Nama lengkap peminjam |
| `borrower_id` | `String` | NIM atau ID peminjam |
| `equipment_name` | `String` | Nama alat yang dipinjam |
| `quantity` | `Number` | Jumlah unit minimal 1 |
| `status` | `String` | `BORROWED` saat dibuat atau `RETURNED` saat dikembalikan |
| `borrowed_at` | `String` | Waktu pinjam format ISO 8601 UTC |
| `due_date` | `String` | Batas tanggal kembali format `YYYY-MM-DD` |
| `returned_at` | `String` | Waktu kembali yang terisi otomatis saat status menjadi `RETURNED` |

## 4. Spesifikasi Endpoint CRUD

### 1. Create: `POST /loans`
Mencatat peminjaman alat baru dan mengembalikan status `201`.
```json
{
  "borrower_name": "Budi Santoso",
  "borrower_id": "220123456",
  "equipment_name": "Oscilloscope Rigol DS1054Z",
  "quantity": 1,
  "due_date": "2026-12-03"
}
```

### 2. Read: `GET /loans` dan `GET /loans/{loan_id}`
Mengambil semua data peminjaman atau satu data berdasarkan `loan_id` dengan status `200`.
```json
{
  "count": 1,
  "items": [
    {
      "loan_id": "a1b2c3d4",
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

### 3. Update: `PUT /loans/{loan_id}`
Mengubah `status`, `due_date`, atau `quantity`. Jika `status` diisi `RETURNED`, field `returned_at` terisi otomatis.
```json
{
  "status": "RETURNED"
}
```

### 4. Delete: `DELETE /loans/{loan_id}`
Menghapus data peminjaman berdasarkan `loan_id` dan mengembalikan status `200`.
```json
{
  "message": "Loan deleted",
  "loan_id": "a1b2c3d4"
}
```
