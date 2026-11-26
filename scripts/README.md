# Scripts

Pengerjaan memakai AWS Learner Lab yang reset sekitar setiap 3 jam, sehingga infrastruktur dibangun ulang lewat script.

| Script | Fungsi |
|---|---|
| `setup-aws.ps1` | PowerShell: buat tabel DynamoDB (atau biarkan Lambda membuatnya), deploy Lambda `equipment-loans-api` dengan `LabRole`, aktifkan Function URL, uji `/health`. |
| `setup-aws.sh` | Versi Bash (CloudShell / Git Bash), perilaku sama. |
| `save-evidence.ps1` | Uji `/health` dan CRUD lengkap (POST, GET list, GET by id, PUT, DELETE) ke endpoint live, lalu simpan output dan backup DynamoDB ke `evidence/`. |

## Prasyarat
- AWS CLI terpasang.
- Kredensial Learner Lab (menu **AWS Details**) sudah diset di terminal:
  `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`.

## Urutan
```powershell
.\scripts\setup-aws.ps1
.\scripts\save-evidence.ps1
```
Script mencoba API Gateway lebih dulu; jika ditolak sandbox (`apigateway:POST`), otomatis memakai Lambda Function URL.
