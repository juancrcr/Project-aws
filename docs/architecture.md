# Architecture Diagram & Security Design

Dokumen ini menjelaskan arsitektur solusi **Equipment Loans API** menggunakan **Track C (Serverless)** pada AWS Learner Lab.

## 1. Diagram Arsitektur (Request/Data Flow, Network, & IAM)

```mermaid
flowchart LR
    subgraph Client_Zone["External / Client"]
        Client["Client App\n(curl / Postman / Browser)"]
    end

    subgraph AWS_Cloud["AWS Cloud (Region: us-east-1 — AWS Learner Lab / Sandbox)"]
        subgraph Managed_API["Public HTTPS Endpoint"]
            FURL["AWS Lambda Function URL\n(HTTPS Endpoint — Payload v2.0)\nRoutes: /health, /loans, /loans/{loan_id}\n(Fallback dari API Gateway karena pembatasan voclabs)"]
        end

        subgraph Compute_Layer["Serverless Compute (AWS Managed VPC)"]
            Lambda["AWS Lambda\nRuntime: Python 3.12\nFunction: equipment-loans-api"]
        end

        subgraph Storage_Observability["Managed Storage & Logging"]
            DDB[("Amazon DynamoDB\nTable: equipment-loans\nPK: loan_id (String)")]
            CW["Amazon CloudWatch Logs\nLog Group: /aws/lambda/equipment-loans-api"]
        end

        subgraph Security_IAM["IAM & Access Control"]
            Role["IAM Execution Role: LabRole\n- dynamodb:* (CreateTable, PutItem, GetItem, Scan, UpdateItem, DeleteItem)\n- logs:CreateLogGroup, CreateLogStream, PutLogEvents"]
        end
    end

    Client -->|"1. HTTPS Request (JSON)"| FURL
    FURL -->|"2. Lambda Event (v2.0)"| Lambda
    Role -.->|"3. Assumed Execution Role"| Lambda
    Lambda -->|"4. boto3 API Call (TLS)"| DDB
    Lambda -->|"5. Write Execution Logs"| CW
    DDB -->|"6. JSON Item / Result"| Lambda
    Lambda -->|"7. HTTP Status + JSON"| FURL
    FURL -->|"8. HTTPS Response"| Client
```

## 2. Penjelasan Komponen & Alur Data

1. **Client -> AWS Lambda Function URL:**
   Client mengirim request HTTPS ke Lambda Function URL (`https://<id>.lambda-url.us-east-1.on.aws`). Function URL menangani terminasi TLS dan meneruskan payload format HTTP v2.0 ke fungsi Lambda. *(Catatan: Di sandbox `voclabs`, `apigateway:POST` dibatasi oleh policy lab, sehingga Lambda Function URL digunakan sebagai HTTPS endpoint publik; pada lingkungan produksi, layer ini dapat diganti dengan Amazon API Gateway HTTP API tanpa mengubah kode Lambda).*
2. **AWS Lambda (`equipment-loans-api`):**
   Fungsi Lambda Python 3.12 mem-parsing `rawPath` dan HTTP `method` untuk merutekan request ke `/health` maupun 4 operasi CRUD `/loans`.
3. **IAM & Security (`LabRole`):**
   Di lingkungan **AWS Learner Lab / Sandbox**, role user `voclabs` dibatasi (tidak memiliki `dynamodb:CreateTable` maupun pembuatan IAM Role baru). Oleh karena itu, Lambda dijalankan menggunakan **`LabRole`** yang memiliki izin `dynamodb:*` di `us-east-1`. Saat `/health` dipanggil pertama kali, Lambda (`LabRole`) otomatis membuat tabel `equipment-loans` jika belum tersedia.
4. **Network Boundary:**
   Seluruh komponen (`Lambda Function URL`, `Lambda`, `DynamoDB`) berjalan di atas infrastruktur **AWS Managed Network** sehingga komunikasi antar-layanan berlangsung melalui jaringan internal AWS yang terenkripsi TLS, tanpa perlu mengelola Subnet, NAT Gateway, atau Security Group secara manual.
5. **Observability (`CloudWatch Logs`):**
   Setiap eksekusi Lambda dan error otomatis tercatat di CloudWatch Logs (`/aws/lambda/equipment-loans-api`) untuk memudahkan debugging dan sebagai bukti (*AWS evidence*).
