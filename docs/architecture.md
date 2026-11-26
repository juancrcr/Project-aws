# Architecture Diagram & Security Design

Dokumen ini menjelaskan arsitektur solusi **Equipment Loans API** menggunakan **Track C (Serverless)** pada AWS Learner Lab.

## 1. Diagram Arsitektur (Request/Data Flow, Network, & IAM)

```mermaid
flowchart LR
    subgraph Client_Zone["External / Client"]
        Client["Client App\n(curl / Postman / Browser)"]
    end

    subgraph AWS_Cloud["AWS Cloud (Region: us-east-1 — AWS Learner Lab)"]
        subgraph Managed_API["Public Managed Endpoint"]
            APIGW["Amazon API Gateway\n(HTTP API)\nRoutes: /health, /loans, /loans/{loan_id}"]
        end

        subgraph Compute_Layer["Serverless Compute (AWS Managed VPC)"]
            Lambda["AWS Lambda\nRuntime: Python 3.12\nFunction: equipment-loans-api"]
        end

        subgraph Storage_Observability["Managed Storage & Logging"]
            DDB[("Amazon DynamoDB\nTable: equipment-loans\nPK: loan_id (String)")]
            CW["Amazon CloudWatch Logs\nLog Group: /aws/lambda/equipment-loans-api"]
        end

        subgraph Security_IAM["IAM & Access Control"]
            Role["IAM Execution Role: LabRole\n- dynamodb:PutItem, GetItem, Scan, UpdateItem, DeleteItem, DescribeTable\n- logs:CreateLogGroup, CreateLogStream, PutLogEvents"]
        end
    end

    Client -->|"1. HTTPS Request (JSON)"| APIGW
    APIGW -->|"2. Lambda Proxy Event (v2.0)"| Lambda
    Role -.->|"3. Assumed Execution Role"| Lambda
    Lambda -->|"4. boto3 API Call (TLS)"| DDB
    Lambda -->|"5. Write Execution Logs"| CW
    DDB -->|"6. JSON Item / Result"| Lambda
    Lambda -->|"7. HTTP Status + JSON"| APIGW
    APIGW -->|"8. HTTPS Response"| Client
```

## 2. Penjelasan Komponen & Alur Data

1. **Client -> Amazon API Gateway (HTTP API):**
   Client mengirim request HTTPS ke Invoke URL API Gateway. API Gateway menangani terminasi TLS dan validasi rute (`/health`, `/loans`, `/loans/{loan_id}`).
2. **API Gateway -> AWS Lambda:**
   API Gateway meneruskan request menggunakan **Lambda Proxy Integration (Payload Format v2.0)** ke fungsi `equipment-loans-api`.
3. **IAM & Security (`LabRole`):**
   Di lingkungan **AWS Learner Lab**, pembuatan IAM Role baru dibatasi. Oleh karena itu, Lambda menggunakan `LabRole` sebagai execution role. `LabRole` memberikan prinsip akses yang dibutuhkan Lambda untuk membaca/menulis ke DynamoDB serta mengirim log ke CloudWatch tanpa menyimpan credential statis (access key) di dalam kode.
4. **Network Boundary:**
   Seluruh komponen (`API Gateway`, `Lambda`, `DynamoDB`) berjalan di atas infrastruktur **AWS Managed Network** sehingga komunikasi antar-layanan berlangsung melalui jaringan internal AWS yang terenkripsi TLS, tanpa perlu mengelola Subnet, NAT Gateway, atau Security Group secara manual.
5. **Observability (`CloudWatch Logs`):**
   Setiap eksekusi Lambda dan error otomatis tercatat di CloudWatch Logs (`/aws/lambda/equipment-loans-api`) untuk memudahkan debugging dan sebagai bukti (*AWS evidence*).
