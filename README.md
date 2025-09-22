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

The MediOps project follows a modern **GitOps-inspired CI/CD workflow** with security and zero-downtime built in:  

1. **Code Commit** → Developer pushes changes to **GitHub** (main branch).  
2. **CI Trigger** → A **GitHub Webhook** automatically triggers the **Jenkins pipeline**.  
3. **Pipeline Stages**:  
   - 🏗️ **Infrastructure as Code (Terraform)** → Provisions/updates AWS infra (VPC, EKS, RDS, S3, ALB).  
   - 🐳 **Docker Build & Push** → Builds app image and pushes to **Amazon ECR**.  
   - 🔐 **DevSecOps Checks** → Runs **Trivy (vulnerability scan)**, **Syft (SBOM)**, and **SonarQube (code quality)**.  
   - 🚀 **Continuous Deployment (EKS)** → Applies manifests, updates **Blue/Green pods** to ensure zero downtime.  
4. **Routing & Availability** → **AWS ALB** automatically directs traffic to the healthy version (Blue or Green).  
5. **Observability & Rollback**:  
   - 📊 **Prometheus + Grafana** monitor app metrics & health.  
   - ⚡ On failure, pipeline triggers **rollback** to last stable version and sends **SNS email alerts**.  
 

---

## 📊 Monitoring & Alerts  

- **Prometheus** scrapes pod/app metrics (`/metrics`)  
- **Grafana** dashboards for:  
  - Pod CPU/Memory  
  - App HTTP Requests  
  - DB connection health  
- **SNS Alerts** → email notifications on failures  

---

## 🌍 Disaster Recovery (DR) – Built for Resilience  

In healthcare, downtime or data loss can cost lives. That’s why **MediOps was designed with Disaster Recovery as a first-class citizen**, not an afterthought.  

- 🪣 **Primary S3 Bucket (us-east-1)**  
  - Stores application artifacts, backups, and critical static files.  
  - Versioning enabled → ensures that **every change is preserved** (no accidental overwrites/loss).  

- 🔄 **Cross-Region Replication to Secondary Bucket (us-east-2)**  
  - Configured replication so that **every object/version in the primary bucket is automatically mirrored** in another AWS region.  
  - This ensures business continuity even if **an entire AWS region goes down**.  

- ✅ **Validation Performed**  
  - Uploaded test files into the primary bucket → confirmed replication in the secondary bucket.  
  - Demonstrated screenshots of replication success in GitHub repo.  

- ⚡ **Recruiter Takeaway**  
  - This DR setup shows that I can **design for high availability & regional failure recovery**, a critical skill for cloud/DevOps engineers.  
  - Goes beyond just deploying apps → focuses on **resilience, compliance, and reliability**.  

> *“Infrastructure is not complete until it’s disaster-proof.” – This DR implementation proves MediOps can survive outages without data loss.*
  

---

## 🐞 Issues Faced & Fixes  

| Issue | Root Cause | Solution |
|-------|------------|----------|
| Prometheus pods stuck in `Pending` | PVC/StorageClass misconfigured | Created `gp2-csi` StorageClass, redeployed Prometheus |
| S3 replication failed | Versioning not enabled on destination bucket | Enabled versioning on both buckets, fixed IAM policy |
| `403 AccessDenied` on static site | Missing public bucket policy | Added `s3:GetObject` bucket policy |
| Frontend not connecting to backend | WSL localhost mismatch | Used WSL IP in `.env` for Axios requests |
| SonarQube Jenkins failure | Wrong installation ID | Corrected Jenkins plugin config & credentials |
| **Env Vars Conflict** | Used both `value` and `valueFrom` in K8s env → invalid | Kept only `valueFrom` for secrets, removed duplicate |
| **CrashLoopBackOff (connection refused)** | Flask app crashed on `db.create_all()` since DB wasn’t reachable | Wrapped DB init in try/except, added `/health` with DB query |
| **Pods not reading env vars** | Tested with `docker run` (no env vars passed) instead of K8s pod | Verified env inside running pod → values injected correctly |
| **RDS Security Group mismatch** | RDS SG allowed wrong group (sg-0e93f5…) | Updated Terraform to reference `eks_sg.id` for worker nodes |
| **Database missing** | RDS didn’t have `mediopsdb` | Logged into RDS with `psql` and manually created `mediopsdb` |
| **Health probe failures (500)** | DB not initialized properly | Fixed after DB creation + correct SG → probe returned `200` |


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
# - Rollback Alert: ![Rollback Alert](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/SNS_Email.jpg?raw=true)
# - Static Hosting_S3: ![Static Hosting_S3](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Static_S3.png)
# - Automated Snapsht Backup: ![Automated Snapsht Backup](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/Automated_snapshot_backup.png)
# - Grafana: ![Grafana](https://github.com/Vin22-03/mediops_disaster_recovery_CICD/blob/main/Screenshots/grafana1.png)

---

## 🧑‍💻 Author  

👨‍💻 **Vinay Bhajantri (VinCloudOps)**  
- 🚀 Aspiring **Cloud & DevOps Engineer**  
- 🔗 [LinkedIn](https://www.linkedin.com/in/vinayvbhajantri) | [GitHub](https://github.com/Vin22-03)
- 🔗 [VincloudOps](https://www.vincloudops.tech)

---

⚡ *This project reflects real-world debugging, resilience design, and end-to-end DevOps practices — not just a demo.*  


