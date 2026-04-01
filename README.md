# Serverless IoT Telemetry Data Pipeline (AWS & Terraform)

This project demonstrates a fully serverless IoT telemetry data pipeline built on AWS and provisioned using Terraform. 

## 🏗️ Architecture
The infrastructure is fully automated and consists of the following AWS services:
- **Amazon API Gateway:** Provides RESTful HTTP endpoints for devices to send and retrieve data.
- **AWS Lambda (Producer):** Receives incoming `POST` requests, validates the payload, and sends it to an SQS queue.
- **Amazon SQS:** Acts as a buffer to handle high-throughput bursts of telemetry data. Includes a Dead-Letter Queue (DLQ) for failed message processing.
- **AWS Lambda (Consumer):** Triggered by SQS (Event Source Mapping). It processes batches of messages, calculates average temperatures per minute, and stores the aggregated data.
- **Amazon DynamoDB:** A NoSQL database used to store the aggregated IoT telemetry data with `device_id` as the partition key and `window_start` as the sort key.
- **AWS Lambda (Getter):** Handles `GET` requests to retrieve the latest aggregated data for a specific device from DynamoDB.

## 🛠️ Tech Stack
- **Infrastructure as Code (IaC):** Terraform (HCL)
- **Cloud Provider:** Amazon Web Services (AWS)
- **Runtime:** Python 3.12 (Boto3)

## 🚀 How to Deploy
1. Ensure AWS CLI is configured with appropriate credentials.
2. Initialize Terraform and apply the configuration:
   ```bash
   cd envs/dev
   terraform init
   terraform apply -auto-approve