# Panduan Setup AWS Sandbox Week 12

Panduan singkat untuk menjalankan proyek pada sesi AWS Sandbox yang reset setiap 3 jam.

## 1. Isi Kredensial di PowerShell
Buka halaman AWS Learner Lab, salin kredensial dari menu AWS Details, lalu jalankan di PowerShell:
```powershell
$env:AWS_ACCESS_KEY_ID="ISI_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY="ISI_SECRET_KEY"
$env:AWS_SESSION_TOKEN="ISI_SESSION_TOKEN"
$env:AWS_DEFAULT_REGION="us-east-1"
```

## 2. Jalankan Auto Setup
```powershell
.\scripts\setup-aws.ps1
```
Script ini akan mengemas `src/lambda_function.py`, membuat atau memperbarui Lambda `equipment-loans-api` dengan role `LabRole`, mengaktifkan Lambda Function URL, lalu memanggil `/health` agar tabel DynamoDB `equipment-loans` aktif.

## 3. Uji Endpoint dan Simpan Bukti
```powershell
.\scripts\save-evidence.ps1
```
Hasil uji `GET /health`, `POST /loans`, `GET /loans`, status tabel DynamoDB, dan backup JSON akan tersimpan otomatis di folder `evidence/`.

## 4. Daftar Screenshot yang Dikumpulkan
1. Tabel DynamoDB `equipment-loans` dengan status `Active` dan isi item pada menu Explore items.
2. Halaman overview Lambda `equipment-loans-api` yang menampilkan Function URL dan execution role `LabRole`.
3. Halaman tab Configuration Permissions pada Lambda dan halaman IAM Role `LabRole`.
4. Hasil Test Event `/health` di konsol Lambda dengan status sukses.
5. Hasil akses endpoint `/loans` di browser serta file log dari folder `evidence/`.
