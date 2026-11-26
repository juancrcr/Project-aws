# Panduan Setup & Verifikasi AWS Learner Lab (Week 12)

Ikuti langkah-langkah berikut saat sesi **AWS Learner Lab** Anda aktif (`Lab status: green`) untuk menyiapkan infrastruktur awal dan mengumpulkan **Deliverable 4 (AWS Evidence)**.

---

## Langkah 1 — Buat Tabel Amazon DynamoDB
1. Buka **AWS Console** -> cari layanan **DynamoDB** -> klik **Create table**.
2. Isi konfigurasi:
   - **Table name:** `equipment-loans`
   - **Partition key:** `loan_id` (tipe `String`)
   - **Table settings:** Default settings (atau On-demand capacity).
3. Klik **Create table** dan tunggu hingga status berubah menjadi **Active**.
4. *(Evidence)* Ambil screenshot halaman tabel DynamoDB yang berstatus **Active**.

---

## Langkah 2 — Buat Fungsi AWS Lambda
1. Buka **AWS Console** -> **Lambda** -> klik **Create function**.
2. Pilih **Author from scratch**:
   - **Function name:** `equipment-loans-api`
   - **Runtime:** `Python 3.12`
   - **Architecture:** `x86_64`
3. Buka bagian **Change default execution role**:
   - Pilih **Use an existing role**.
   - Pilih **`LabRole`** (wajib di AWS Learner Lab karena tidak diizinkan membuat role baru).
4. Klik **Create function**.
5. Di tab **Code**, salin seluruh isi file `src/lambda_function.py` ke `lambda_function.py`, lalu klik **Deploy**.
6. Di tab **Configuration** -> **Environment variables** -> **Edit**:
   - Tambahkan key `TABLE_NAME` dengan value `equipment-loans`, lalu klik **Save**.

---

## Langkah 3 — Uji Konektivitas Awal di Lambda (Test Event)
1. Di halaman Lambda `equipment-loans-api`, buka tab **Test**.
2. Buat Test Event baru bernama `health-check` dengan JSON berikut:
   ```json
   {
     "rawPath": "/health",
     "requestContext": {
       "http": {
         "method": "GET"
       }
     }
   }
   ```
3. Klik **Test**. Pastikan output mengembalikan `statusCode: 200` dan `"table_status": "ACTIVE"`.
4. *(Evidence)* Ambil screenshot hasil **Execution result: succeeded** di tab Test Lambda.

---

## Langkah 4 — Hubungkan Amazon API Gateway (HTTP API)
1. Buka **AWS Console** -> **API Gateway** -> klik **Create API**.
2. Pada bagian **HTTP API**, klik **Build**.
3. Klik **Add integration** -> pilih **Lambda** -> pilih function `equipment-loans-api`, beri **API name:** `equipment-loans-http-api`, lalu klik **Next**.
4. Pada **Configure routes**, tambahkan rute berikut (semua mengarah ke `equipment-loans-api`):
   - `GET` `/health`
   - `POST` `/loans`
   - `GET` `/loans`
   - `GET` `/loans/{loan_id}`
   - `PUT` `/loans/{loan_id}`
   - `DELETE` `/loans/{loan_id}`
5. Klik **Next** -> biarkan stage `$default` dengan **Auto-deploy** aktif -> klik **Create**.
6. Salin **Invoke URL** (misalnya: `https://abc123xyz.execute-api.us-east-1.amazonaws.com`).

---

## Langkah 5 — Uji Konektivitas End-to-End (`curl`)
Jalankan perintah berikut di terminal (ganti `<INVOKE_URL>` dengan Invoke URL milik Anda):

```bash
# 1. Cek konektivitas Lambda + DynamoDB
curl -i <INVOKE_URL>/health

# 2. Create peminjaman baru
curl -i -X POST <INVOKE_URL>/loans \
  -H "Content-Type: application/json" \
  -d "{\"borrower_name\":\"Budi Santoso\",\"borrower_id\":\"220123456\",\"equipment_name\":\"Oscilloscope Rigol DS1054Z\",\"quantity\":1,\"due_date\":\"2026-12-03\"}"

# 3. Read semua peminjaman
curl -i <INVOKE_URL>/loans
```

*(Evidence)* Simpan screenshot / copy-paste output terminal dari perintah `curl` di atas beserta screenshot item yang masuk di **DynamoDB -> Explore items**.

---

## Checklist Pengumpulan Week 12
- [x] **Architecture diagram** (`docs/architecture.md` — Mermaid diagram dengan Lambda Function URL, Lambda `LabRole`, DynamoDB, CloudWatch Logs)
- [x] **Design brief (1–2 halaman)** (`docs/design-brief.md`)
- [x] **Git repository** (repo ini dengan progressive commits)
- [ ] **AWS evidence:**
  - [ ] Screenshot Lambda `equipment-loans-api` (Overview dengan **Function URL**, serta tab **Configuration -> Permissions** terlihat `LabRole`)
  - [ ] Screenshot hasil Lambda **Test Event** `/health` (`Execution result: succeeded`, `table_status: ACTIVE`)
  - [ ] Screenshot tabel DynamoDB `equipment-loans` (status **Active** & **Explore items**)
  - [ ] Screenshot browser/terminal saat mengakses `<FUNCTION_URL>/loans` (atau lampirkan file output di folder `evidence/`)
