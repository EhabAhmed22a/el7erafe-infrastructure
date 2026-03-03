## 📐 Architecture Overview
The infrastructure utilizes a modern, PaaS-first approach on Azure, minimizing network management overhead while maximizing scalability for the el7erafe mobile backend and microservices.

**Core Components Provisioned:**
* **Compute & Microservices:** * **Azure Container Apps:** Serverless container hosting used for lightweight, scalable microservices (like content moderation).
  * **Azure App Service:** Fully managed platform for hosting the core backend application web APIs.
* **Database:** Managed relational database configurations for secure and scalable data storage.
* **Storage:** Azure Storage accounts configured for application assets, file handling, and secure Terraform state management.
* **Identity & Access Management:** Granular access control implemented via Azure Role Assignments (RBAC) to ensure services communicate securely using the principle of least privilege.
