# AWS Equipment Loans API (Week 12 — Design & AWS Setup)

Proyek individu **AWS Cloud Computing — Week 12** menggunakan **Track C (Serverless)** untuk use case **Equipment Loans** (Sistem Peminjaman Alat Lab/Kampus).

## Arsitektur Singkat
- **AWS Lambda Function URL**: Endpoint HTTPS publik yang meneruskan request ke Lambda menggunakan payload format v2.0 (digunakan sebagai alternatif API Gateway karena pembatasan `apigateway:POST` pada role sandbox `voclabs`).
- **AWS Lambda (Python 3.12)**: Menjalankan logika bisnis, auto-provisioning tabel DynamoDB jika belum ada, dan routing CRUD untuk entitas `EquipmentLoan`.
- **Amazon DynamoDB**: Menyimpan data peminjaman pada tabel `equipment-loans` (Partition Key: `loan_id`).
- **IAM (`LabRole`) & CloudWatch Logs**: Mengatur izin akses penuh Lambda ke DynamoDB (`us-east-1`) serta pencatatan log eksekusi.

## Struktur Repository
```text
.
├── docs/
│   ├── architecture.md      # Diagram arsitektur, alur data, jaringan, & IAM
│   ├── aws-setup-guide.md   # Panduan setup & verifikasi di AWS Learner Lab
│   └── design-brief.md      # Design brief (1-2 halaman)
├── src/
│   ├── lambda_function.py   # Handler AWS Lambda (Python 3.12)
│   └── local_test.py        # Unit test lokal (tanpa perlu koneksi AWS)
├── .gitignore
├── requirements.txt
└── README.md
```

## Endpoint API
| Method | Path | Operasi | Deskripsi |
|---|---|---|---|
| `GET` | `/health` | Health Check | Cek status Lambda & konektivitas tabel DynamoDB |
| `POST` | `/loans` | Create | Mencatat peminjaman alat baru |
| `GET` | `/loans` | Read (List) | Menampilkan semua data peminjaman |
| `GET` | `/loans/{loan_id}` | Read (Detail) | Menampilkan detail satu peminjaman |
| `PUT` | `/loans/{loan_id}` | Update | Memperbarui status (`RETURNED`) atau `due_date` |
| `DELETE` | `/loans/{loan_id}` | Delete | Menghapus catatan peminjaman |

## Menjalankan Test Lokal
```bash
python -m unittest discover -s src -p "*test*.py" -v
```

## Deployment Plan (AWS Learner Lab / Sandbox)
1. Deploy fungsi AWS Lambda `equipment-loans-api` (runtime Python 3.12) di `us-east-1` dengan execution role **`LabRole`** dan environment variable `TABLE_NAME=equipment-loans`.
2. Aktifkan **Lambda Function URL** (`AuthType: NONE`) atau API Gateway HTTP API (jika diizinkan oleh lab).
3. Panggil `GET /health` agar Lambda (`LabRole`) otomatis memverifikasi/membuat tabel DynamoDB `equipment-loans` (Partition Key `loan_id`, `PAY_PER_REQUEST`).
4. Uji endpoint CRUD (`/loans`) dan simpan bukti eksekusi ke folder `evidence/`.

## Auto-Setup untuk AWS Sandbox (Reset Tiap 3 Jam)
Karena sesi AWS Sandbox / Learner Lab akan ter-reset setelah 3 jam, gunakan script berikut untuk membuat ulang seluruh resource dalam sekali jalan dan menyimpan bukti/backup ke lokal:
- `scripts/setup-aws.ps1` (Windows PowerShell) / `scripts/setup-aws.sh` (CloudShell / Bash) — Membuat tabel DynamoDB, deploy Lambda `equipment-loans-api` dengan `LabRole`, setup API Gateway HTTP API, dan uji `/health`.
- `scripts/save-evidence.ps1` — Menjalankan test CRUD live, menyimpan output ke `evidence/`, dan mem-backup isi tabel DynamoDB ke JSON lokal.

Panduan lengkap langkah demi langkah tersedia di [docs/aws-setup-guide.md](docs/aws-setup-guide.md).
