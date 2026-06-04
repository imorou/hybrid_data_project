
# Hybrid Data & Cloud Automation Project

An enterprise-grade Data Engineering and Cloud Infrastructure repository. This project orchestrates a complete cloud data platform, automating the deployment of relational infrastructure on AWS and implementing high-performance ETL staging and data transformation pipelines.

---

##  System Architecture & Component Overview

The platform is engineered into three distinct decoupled layers to guarantee scalability, isolation of environments, and maintenance clear-cut limits:

```text
    +-----------------------------------------------------------------+
    |                     1. Cloud Infrastructure                     |
    |  [ Terraform Global ] -> [ Environments: Dev / Prod ]           |
    |  Provisioning: AWS RDS Instance & Native Network Components     |
    +-----------------------------------------------------------------+
                                    |
                                    v
    +-----------------------------------------------------------------+
    |                  2. Data Schema & Engine Seed                   |
    |  [ Oracle Database Sample Schemas (HR, OE, PM, SH) ]            |
    |  Relational structures, Partitioned Sales Data, XML/LOB Feeds   |
    +-----------------------------------------------------------------+
                                    |
                                    v
    +-----------------------------------------------------------------+
    |                     3. Data Pipeline & ETL                      |
    |  [ sql/create_tables.sql ] -> [ sql/staging_load.sql ]          |
    |  Transformation Layer: [ sql/transformations.sql ]              |
    |  Data Pipeline Logic:  [ etl/src/ ] & Verification [ etl/tests/ ]|
    +-----------------------------------------------------------------+
