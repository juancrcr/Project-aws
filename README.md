# AWS Equipment Loans API (Week 12 — Design & AWS Setup)

Proyek individu **AWS Cloud Computing — Week 12** menggunakan **Track C (Serverless)** untuk use case **Equipment Loans** (Sistem Peminjaman Alat Lab/Kampus).

## Arsitektur Singkat
- **Amazon API Gateway (HTTP API)**: Menerima request HTTP/HTTPS dari client dan meneruskannya ke Lambda.
- **AWS Lambda (Python 3.12)**: Menjalankan logika bisnis & routing CRUD untuk entitas `EquipmentLoan`.
- **Amazon DynamoDB**: Menyimpan data peminjaman pada tabel `equipment-loans` (Partition Key: `loan_id`).
- **IAM (`LabRole`) & CloudWatch Logs**: Mengatur izin akses Lambda ke DynamoDB serta pencatatan log eksekusi di AWS Learner Lab.

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

## Deployment Plan (AWS Learner Lab)
1. Buat tabel DynamoDB bernama `equipment-loans` dengan Partition Key `loan_id` (`String`).
2. Buat fungsi AWS Lambda (runtime Python 3.12) dengan execution role **`LabRole`**.
3. Set environment variable `TABLE_NAME=equipment-loans` pada konfigurasi Lambda.
4. Upload kode `src/lambda_function.py` ke Lambda.
5. Buat **API Gateway (HTTP API)** dengan rute `/health`, `/loans`, dan `/loans/{loan_id}` yang terintegrasi ke Lambda.
6. Verifikasi konektivitas menggunakan Lambda Test Event dan `curl` ke Invoke URL API Gateway.

Panduan lengkap langkah demi langkah tersedia di [docs/aws-setup-guide.md](docs/aws-setup-guide.md).
