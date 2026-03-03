# 🏗️ el7erafe Cloud Infrastructure

> Infrastructure as Code (IaC) for the el7erafe platform, provisioned via Terraform.

This repository contains the Terraform configurations used to provision, manage, and securely scale the cloud-native Azure infrastructure for the el7erafe mobile application. By strictly utilizing Infrastructure as Code, this project ensures reliable, repeatable, and version-controlled cloud environments.

## 📐 Architecture Overview
The infrastructure utilizes a modern, serverless, and PaaS-first approach on Azure, cleanly separating the client-side hosting, backend compute, and data layers.

**Core Components Provisioned:**
* **Backend Compute:** Azure App Service hosting the core .NET Core 9 API.
* **Frontend Hosting:** Azure Blob Storage configured with Static Website Hosting to serve the Angular SPA Admin Dashboard with high availability.
* **Relational Database:** Azure SQL Database handling transactional data, user profiles, and application state.
* **Unstructured Storage:** Azure Blob Storage containers handling user-generated content, such as technician ID photos and profile pictures.
* **Microservices:** Azure Container Apps designated for scalable, lightweight microservices (like content moderation).

## 🔒 Security: Zero-Trust & Identity Management
A "Zero Trust" approach is actively enforced across the infrastructure. Hardcoded credentials and connection strings have been eliminated in favor of Azure-native identity management.

* **System-Assigned Managed Identity:** The Azure App Service is assigned a unique identity within Azure Entra ID.
* **Role-Based Access Control (RBAC):** Using Terraform (`roles-assignments.tf`), the App Service identity is securely granted the `SQL DB Contributor` role to access the database and the `Storage Blob Data Contributor` role to manage images.

## 💰 Cost Optimization: Ephemeral Infrastructure
To optimize cloud billing, this project utilizes an "Ephemeral Infrastructure" model for development environments.

* **Automated Tear-Down:** Terraform is used to destroy expensive compute resources (App Service, SQL DB) at the end of the working day.
* **Rapid Re-provisioning:** The exact environment is re-provisioned from these Terraform configurations in minutes at the start of the next working session.

## 🗂️ Repository Structure
The Terraform code is modularized to separate concerns:
* `app-service.tf`: Defines the hosting plans and App Service configurations.
* `database.tf`: Provisions the Azure SQL server and databases.
* `storage.tf`: Configures standard storage accounts and the static website $web container.
* `roles-assignments.tf`: Manages the RBAC permissions and identity access.
* `containerApp.tf`: Provisions the serverless container environment for standalone microservices.

## 💻 Local Development & Usage

### Prerequisites
* Terraform CLI installed locally.
* Azure CLI installed and authenticated (`az login`).
* An active Azure Subscription.
