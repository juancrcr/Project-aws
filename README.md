# AWS Equipment Loans API

Proyek individu AWS Cloud Computing Week 12 dengan Track C Serverless untuk kasus peminjaman alat laboratorium.

## Komponen Utama
1. AWS Lambda Function URL sebagai endpoint HTTPS publik yang meneruskan request ke Lambda dengan payload format v2.0. Dipakai sebagai pengganti API Gateway karena role sandbox `voclabs` membatasi `apigateway:POST`.
2. AWS Lambda Python 3.12 dengan nama fungsi `equipment-loans-api` untuk menjalankan logika CRUD entitas `EquipmentLoan` dan membuat tabel DynamoDB otomatis bila belum ada.
3. Amazon DynamoDB dengan tabel `equipment-loans` dan partition key `loan_id`.
4. IAM `LabRole` sebagai execution role Lambda agar dapat mengakses DynamoDB dan CloudWatch Logs di `us-east-1`.

## Struktur Repository
```text
.
├── docs/
│   ├── Lporan Tugas .pdf
│   ├── arsitektur-equipment-loans.drawio.png
├── evidence/
├── scripts/
│   ├── save-evidence.ps1
│   ├── setup-aws.ps1
│   └── setup-aws.sh
├── src/
│   ├── lambda_function.py
│   └── local_test.py
├── .gitignore
└── README.md
```

## Endpoint API
| Method | Path | Operasi | Keterangan |
|---|---|---|---|
| `GET` | `/health` | Health Check | Cek status Lambda dan koneksi DynamoDB |
| `POST` | `/loans` | Create | Catat peminjaman alat baru |
| `GET` | `/loans` | Read List | Ambil semua data peminjaman |
| `GET` | `/loans/{loan_id}` | Read Detail | Ambil satu data berdasarkan `loan_id` |
| `PUT` | `/loans/{loan_id}` | Update | Ubah status atau `due_date` |
| `DELETE` | `/loans/{loan_id}` | Delete | Hapus data peminjaman |

## Uji Lokal
```bash
python -m unittest discover -s src -p "*test*.py" -v
```

## Deploy di AWS Sandbox
Sesi AWS Sandbox akan reset setiap 3 jam. Jalankan script di bawah setelah mengisi kredensial AWS di PowerShell untuk membangun ulang infrastruktur dan menyimpan bukti ke folder `evidence`:
1. `.\scripts\setup-aws.ps1` untuk membuat tabel DynamoDB, deploy Lambda `equipment-loans-api` dengan `LabRole`, mengaktifkan Function URL, dan menguji `/health`.
2. `.\scripts\save-evidence.ps1` untuk menguji endpoint live dan menyimpan backup DynamoDB ke JSON lokal.
