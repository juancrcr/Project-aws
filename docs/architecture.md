# Architecture Diagram dan Keamanan

Dokumen ini menjelaskan rancangan arsitektur Equipment Loans API pada Track C Serverless di AWS Sandbox.

## 1. Diagram Arsitektur

```mermaid
flowchart LR
    subgraph Client_Zone["Client"]
        Client["Browser / curl / PowerShell"]
    end

    subgraph AWS_Cloud["AWS Cloud us-east-1"]
        subgraph Managed_API["Public HTTPS Endpoint"]
            FURL["AWS Lambda Function URL\nPayload v2.0\nRoutes: /health, /loans, /loans/{loan_id}"]
        end

        subgraph Compute_Layer["Serverless Compute"]
            Lambda["AWS Lambda Python 3.12\nequipment-loans-api"]
        end

        subgraph Storage_Observability["Storage dan Logging"]
            DDB[("Amazon DynamoDB\nTable: equipment-loans\nPK: loan_id")]
            CW["Amazon CloudWatch Logs\n/aws/lambda/equipment-loans-api"]
        end

        subgraph Security_IAM["IAM"]
            Role["IAM Role: LabRole\nAkses penuh DynamoDB dan CloudWatch Logs"]
        end
    end

    Client -->|"1. HTTPS Request"| FURL
    FURL -->|"2. Event v2.0"| Lambda
    Role -.->|"3. Execution Role"| Lambda
    Lambda -->|"4. boto3 TLS"| DDB
    Lambda -->|"5. Logs"| CW
    DDB -->|"6. Result"| Lambda
    Lambda -->|"7. JSON Response"| FURL
    FURL -->|"8. HTTPS Response"| Client
```

## 2. Alur Data dan Keamanan
1. Client mengirim request HTTPS ke Lambda Function URL. Function URL dipilih sebagai endpoint publik karena akun sandbox `voclabs` membatasi pembuatan API Gateway.
2. Lambda `equipment-loans-api` menerima event format v2.0 lalu mengarahkan request ke `/health` atau operasi CRUD `/loans`.
3. Lambda berjalan memakai `LabRole` yang sudah memiliki izin `dynamodb:*` di `us-east-1`. Saat `/health` pertama kali dipanggil, Lambda otomatis membuat tabel `equipment-loans` jika belum tersedia.
4. Seluruh komponen berada di jaringan terkelola AWS sehingga komunikasi antar layanan sudah terenkripsi TLS tanpa perlu membuat VPC atau Security Group secara manual.
5. Setiap log eksekusi dikirim ke CloudWatch Logs di grup `/aws/lambda/equipment-loans-api`.
