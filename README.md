# 🚑 MediOps – Disaster-Resistant Healthcare Platform  
**by VinCloudOps**  

### 🏥 A cloud-native healthcare platform designed with **zero downtime, disaster recovery, and End-to-End DevOps automation**.  
### Built to demonstrate enterprise-grade practices: **EKS Blue-Green Deployments, RDS High Availability, CI/CD with Jenkins, Monitoring with Prometheus/Grafana, and S3 Cross-Region Replication**.  

---

## 📌 Features  
- ✅ **Infrastructure as Code (IaC)** – Automated provisioning with **Terraform**  
- ✅ **CI/CD Pipeline** – GitHub → Jenkins → Docker → ECR → EKS  
- ✅ **Zero Downtime Deployments** – Blue/Green strategy on AWS EKS  
- ✅ **Database** – AWS RDS (PostgreSQL) with secure SG rules  
- ✅ **Monitoring & Alerts** – Prometheus + Grafana dashboards, SNS alerts  
- ✅ **Disaster Recovery** – Cross-region S3 replication (Primary: us-east-1 → DR: us-east-2)  
- ✅ **Static Website Hosting** – S3 static landing page with project logo  

---
## 🏗️ End-to-End Architecture (ASCII View)

```text
   ┌───────────────┐
   │    GitHub     │  (Code Push / Webhook)
   └───────┬───────┘
           │
           v
   ┌───────────────┐
   │   Jenkins     │
   │───────────────│
   │ IaC(Terraform)|  → Provision VPC, EKS, RDS, S3, ALB, SNS
   │ CI (Build)    |  → Trivy/Syft/SonarQube →→ Docker Build →→ Push Image to ECR (Trigger CD) 
   │ CD (Deploy)   |  → Pull Image from ECR + Deploy to EKS
   └───────┬───────┘
           │
           v
   ┌───────────────┐
   │    AWS ECR    │  (Stores Docker Images)
   └───────┬───────┘
           │ Pull image
           v
   ┌───────────────┐
   │     EKS       │
   │  Blue / Green │  (Zero Downtime Deployments)
   └───────┬───────┘
           │
           v
   ┌───────────────┐
   │     ALB       │  (Ingress to App Pods)
   └───────┬───────┘
           │
           v
   ┌───────────────┐
   │ RDS (Postgres)│  (Secure DB connection)
   └───────────────┘

           │
           v
   ┌───────────────┐
   │    End User   │  (Access via ALB DNS )
   └───────────────┘

```


**Flow:**  
- **Users** → ALB → **EKS (Blue/Green Pods)** → RDS (Postgres)  
- **Static Site** served via S3 bucket  
- **CI/CD Pipeline**: GitHub → Jenkins → Terraform + Docker → ECR → EKS  
- **Security**: Trivy, Syft, SonarQube integrated in pipeline  
- **Monitoring**: EKS Pods → Prometheus → Grafana Dashboards  
- **Disaster Recovery**: S3 primary → replicated to S3 DR bucket in another region  

---

## ⚙️ Tech Stack  

- **AWS**: VPC, EKS, RDS, ALB, ECR, S3, SNS  
- **DevOps Tools**: Jenkins, Docker, Terraform, Helm, Prometheus, Grafana  
- **Security**: Trivy, Syft (SBOM), SonarQube  
- **Languages**: Python (Flask App), YAML (K8s manifests), HCL (Terraform)  

---

## 🚀 CI/CD Pipeline  

1. Developer pushes code → GitHub  
2. Jenkins pipeline triggers (webhook)  
3. Stages:  
   - **Terraform** → Infra provisioning  
   - **Docker** → Build & Push image to ECR  
   - **Trivy/Syft/SonarQube** → Security + Quality scans  
   - **Deploy to EKS** → Blue/Green Pods updated  
4. ALB routes traffic → ensures zero downtime  

---

## 📊 Monitoring & Alerts  

- **Prometheus** scrapes pod/app metrics (`/metrics`)  
- **Grafana** dashboards for:  
  - Pod CPU/Memory  
  - App HTTP Requests  
  - DB connection health  
- **SNS Alerts** → email notifications on failures  

---

## 🌍 Disaster Recovery  

- Primary S3 bucket (us-east-1) with **versioning enabled**  
- Cross-region replication to secondary S3 bucket (us-east-2)  
- Validated by uploading test files → replicated successfully  

---

## 🐞 Issues Faced & Solutions  

| Issue | Root Cause | Solution |
|-------|------------|----------|
| **Prometheus pods stuck in Pending** | PVC/StorageClass misconfigured | Created `gp2-csi` storage class, redeployed |
| **S3 Replication failed** | Versioning not enabled on destination bucket | Enabled versioning on both buckets + added IAM role/policy |
| **AccessDenied on S3 static site** | Missing bucket policy | Added public bucket policy for `GetObject` |
| **Frontend not connecting to backend** | Wrong localhost resolution inside WSL | Used WSL IP in `.env` for Axios requests |
| **SonarQube Jenkins error** | Wrong installation ID | Corrected Jenkins plugin config + creds |


---

## 📸 Screenshots to Showcase  

# - Home Page: ![Home Page](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/final_k8s.png?raw=true)
# - Dashboard: ![Dashboard](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Dashboard_latest.png)
# - Patients: ![Patients](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/patients.png) 
# - Appointments: ![Appointments](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Appointments.png)
# - Patient_Outcomes: ![Patient Outcomes](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/k8s_dashboard2.png)
# - MediOps-CICD: ![MediOps_Jenkins](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Jenkins_Mediops.png)
# - Health: ![Health](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Health_ok.png)
# - IaC Pipeline: ![IaC Pipeline](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Jenkins_Infra_parameter.png)
# - IaC Success: ![IaC Success](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Infra_Pipeline_success.png)
# - MediOps-CI: ![MediOps-CI](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/MediOps-CI_Jenkins.png)
# - MediOps-CD: ![MediOps-CD](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/MediOps-CD_Jenkins.png)
# - CI → Trigger → CD: ![CI → Trigger → CD](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/CI_Pipeline_Success_TriggerCD.png)
# - CICD_Success: ![CICD_Success](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/CD_Pipeline_success.png?raw=true)
# - kubectl ingress url: ![kubectl ingress url](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Ingress_URL.png)
# - EKS Nodes: ![EKS Nodes](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/EKS_nodes.png)
# - SonarQube: ![SonarQube](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Sonarqube.png?raw=true)
# - Software Bill of Materials(syft): ![Software Bill of Materials(syft)](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Syft_Report.png)
# - Rollingback_Green_ZeroDowntime: ![Rollingback_Green_ZeroDowntime](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Rollingback_Green_ZeroDowntime.png?raw=true)
# - Version_Green: ![Version_Green](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Version_44_green.png)
# - Version_Blue: ![Version_Blue](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Version_Blue.png)
# - S3_Buckets: ![S3_Buckets](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/S3_Buckets.png)
# - Primary Bucket: ![Primary Bucket](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Primary_bucket.png)
# - Secondary Bucket_Replication: ![Secondary Bucket_Replication](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Backup_replicated_Bucket.png)
# - SNS Email Confirm: ![SNS Email Confirm](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/SNS_EMail_confirm.png)
# - Rollback Alert: <img src="https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/SNS_Email.jpg?raw=true" width="400" alt="Rollback Alert SNS Email" />
# - : ![]()
# - : ![]()

---

## 🧑‍💻 Author  

👨‍💻 **Vinay Bhajantri (VinCloudOps)**  
- 🚀 Aspiring **Cloud & DevOps Engineer**  
- 🔗 [LinkedIn](https://www.linkedin.com/in/vinayvbhajantri) | [GitHub](https://github.com/Vin22-03)  

---

⚡ *This project reflects real-world debugging, resilience design, and end-to-end DevOps practices — not just a demo.*  


