# MDLBEAST Ticketing Platform -- Summary

**Date:** 2026-03-04

---

## What Is This?

MDLBEAST is a Saudi Arabian entertainment company that produces large-scale music festivals and live events (notably Soundstorm). The **MDLBEAST Ticketing Platform** is their purpose-built, cloud-native event ticketing system that handles the complete ticket lifecycle: event creation, pricing, online sales, payment processing, PDF ticket generation, physical gate scanning, ticket transfers, marketplace resale, loyalty rewards, and reporting.

**Scale:** 34 service directories, 20+ .NET microservices, 3 frontends (web admin, partner portal, mobile scanner), deployed to AWS me-south-1 (Bahrain).

**Architecture:** Polyglot microservices monorepo. Each subdirectory is an independent git repository with its own CI/CD. No root-level build system. Backend services run as AWS Lambda functions behind an API Gateway, connected via EventBridge and SQS queues. Data lives in Aurora PostgreSQL. See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.

**Tech Stack:** .NET 8.0 (backend), Next.js 15 (admin dashboard), Next.js 13 (partner portal), Expo 52/React Native (mobile scanner). See [STACK.md](STACK.md) for full details.

---

## Business Domain Overview

The platform solves the end-to-end problem of selling tickets to live events:

1. **Organizers** create events, define ticket types and pricing, allocate inventory across sales channels
2. **Customers** browse events, purchase tickets (card, BNPL, Apple Pay), receive PDF tickets via email
3. **Gate staff** scan QR codes/NFC tags at venue entry using a dedicated Android scanner app
4. **Partners** receive ticket allocations through distribution portals and manage their attendee lists
5. **Ticket holders** can transfer tickets to others or list them for resale on the marketplace

The platform is **multi-tenant**: all operations are scoped to an Organization, which can have Branches (sub-units) and Channels (sales channels).

---

## Complete Service Catalog

### Business Domain Services (.NET 8.0, AWS Lambda)

| Service | Directory | Purpose |
|---------|-----------|---------|
| **Catalogue** | `ticketing-platform-catalogue/` | Master record for events, ticket types, venues, categories, timeslots, perks, tags |
| **Inventory** | `ticketing-platform-inventory/` | Stock pools, channel allocations, reservations, carts, seating plans (Seats.io) |
| **Pricing** | `ticketing-platform-pricing/` | Price calculations, discounts, coupons for checkout cart flow |
| **Sales** | `ticketing-platform-sales/` | Orders, payments (HyperPay/Tabby/Checkout.com), refunds, customers, affiliates |
| **Access Control** | `ticketing-platform-access-control/` | Scannables (QR/NFC), zones, zone policies, scanner devices, ticket validation |
| **Organizations** | `ticketing-platform-organizations/` | Multi-tenant identity: organizations, branches, channels, users, roles, permissions |
| **Media** | `ticketing-platform-media/` | PDF ticket templates, KYC documents, S3 media uploads, presigned URLs |
| **Transfer** | `ticketing-platform-transfer/` | Ticket transfer lifecycle between attendees (initiate/accept/cancel) |
| **Loyalty** | `ticketing-platform-loyalty/` | Talon.One loyalty engine integration (points, campaigns, rewards) |
| **Marketplace** | `ticketing-platform-marketplace-service/` | Secondary ticket resale (listings, transactions, seller accounts) |
| **Reporting** | `ticketing-platform-reporting-api/` | Aggregated sales/access charts and event-level summary reports |
| **Integration** | `ticketing-platform-integration/` | Outbound emails (SendGrid), webhooks, notification preferences, payment callbacks |
| **Geidea** | `ticketing-platform-geidea/` | Geidea payment gateway integration with its own persistence and polling |
| **Distribution Portal** | `ticketing-platform-distribution-portal/` | Backend API for partner ticket distribution and attendee management |
| **PDF Generator** | `ticketing-platform-pdf-generator/` | Async Lambda consumer for rendering PDF tickets from scannable events |
| **CSV Generator** | `ticketing-platform-csv-generator/` | Async Lambda consumer for generating CSV report exports to S3 |

### Extension System (.NET 8.0, AWS Lambda)

| Service | Directory | Purpose |
|---------|-----------|---------|
| **Extension API** | `ticketing-platform-extension-api/` | Extension definitions, flows, execution history, code management |
| **Extension Executor** | `ticketing-platform-extension-executor/` | Executes registered extensions in parallel on platform events via SQS |
| **Extension Deployer** | `ticketing-platform-extension-deployer/` | Provisions Lambda functions for code-based extensions |
| **Extension Log Processor** | `ticketing-platform-extension-log-processor/` | Captures execution logs and duration metrics from SQS |

### User-Facing Applications

| Application | Directory | Tech | Purpose |
|-------------|-----------|------|---------|
| **Admin Dashboard** | `ticketing-platform-dashboard/` | Next.js 15, React 18, MUI 5, TailwindCSS | Full event/sales/access management for organizers |
| **Distribution Portal** | `ticketing-platform-distribution-portal-frontend/` | Next.js 13, MUI 5, i18next | Partner-facing portal for ticket allocation and attendees |
| **Mobile Scanner** | `ticketing-platform-mobile-scanner/` | Expo 52, React Native, Android-only | Gate scanning app with NFC/barcode hardware integration |
| **Mobile Libraries** | `ticketing-platform-mobile-libraries/` | Yarn workspaces, Expo Modules | Native modules: `acs-smc-sdk` (NFC), `expo-serial-usb` (LED) |

### Shared Libraries & Infrastructure

| Service | Directory | Purpose |
|---------|-----------|---------|
| **Tools** | `ticketing-platform-tools/` | NuGet packages (`TP.Tools.*`): shared entities, data access, messaging, logging, CDK constructs |
| **Infrastructure** | `ticketing-platform-infrastructure/` | Shared AWS CDK: EventBridge bus, SQS queues, Slack notifications, monitoring, RDS Proxy |
| **Gateway** | `ticketing-platform-gateway/` | YARP reverse proxy routing API traffic to 14+ backend services |
| **Shared** | `ticketing-platform-shared/` | NPM package: `TicketingClient` TypeScript HTTP client for consuming the platform API |

### Configuration & DevOps

| Service | Directory | Purpose |
|---------|-----------|---------|
| **ConfigMap Dev** | `ticketing-platform-configmap-dev/` | Kubernetes ConfigMaps for dev environment |
| **ConfigMap Sandbox** | `ticketing-platform-configmap-sandbox/` | Kubernetes ConfigMaps for sandbox environment |
| **ConfigMap Prod** | `ticketing-platform-configmap-prod/` | Kubernetes ConfigMaps for production environment |
| **Terraform Dev** | `ticketing-platform-terraform-dev/` | Terraform modules for dev/sandbox AWS infrastructure |
| **Terraform Prod** | `ticketing-platform-terraform-prod/` | Terraform modules for production AWS infrastructure |
| **Work Smart Scripts** | `ticketing-work-smart-scripts/` | Developer utility scripts (branch protection, PR creator) |

---

## Domain Boundaries

Services map to business capabilities as follows:

```
Event & Content          Sales & Payments         Access Control
  Catalogue                Sales                    Access Control
  Inventory                Geidea                   Mobile Scanner
  Pricing                  Integration              Mobile Libraries

Ticket Lifecycle         Organization & Identity  Reporting & Exports
  Media                    Organizations            Reporting API
  PDF Generator                                     CSV Generator
  Transfer               Distribution
  Marketplace              Distribution Portal
                           Distribution Portal FE
Loyalty
  Loyalty (Talon.One)    Extensions
                           Extension API
                           Extension Executor
                           Extension Deployer
                           Extension Log Processor
```

**Catalogue** is the source of truth for events and ticket types. When data changes here, domain events propagate to every other service. **Sales** is the most complex service, handling the full order lifecycle with multiple payment providers. **Access Control** is the real-time gate scanning engine that the mobile scanner communicates with directly.

---

## Key Integrations

| Integration | Service | Purpose |
|-------------|---------|---------|
| **HyperPay** | Sales | Primary payment gateway (credit/debit cards, Apple Pay) |
| **Tabby** | Sales | Buy Now Pay Later (BNPL) payments |
| **Checkout.com** | Sales | Alternative payment processing |
| **Geidea** | Geidea (dedicated service) | Saudi payment gateway with its own session management |
| **Talon.One** | Loyalty | Loyalty campaigns, points, rewards engine |
| **SendGrid** | Integration | Transactional emails (order confirmation, ticket delivery, refunds) |
| **Auth0** | Dashboard, Distribution Portal | Authentication and identity for web applications |
| **Seats.io** | Inventory (via Dashboard) | Interactive seating chart rendering and seat selection |
| **Sentry** | Dashboard, Mobile Scanner | Frontend error tracking |
| **AWS EventBridge** | All backend services | Inter-service event bus (`Source: "TicketingPlatform"`) |
| **AWS SQS** | All backend consumers | Per-service message queues with DLQs |
| **Aurora PostgreSQL** | All backend services | Primary database via RDS Proxy |
| **Elasticsearch/Kibana** | Infrastructure | Centralized log aggregation and search |
| **Slack** | Infrastructure | Error alerts (3 channels: errors, operational, suspicious orders) |

See [STACK.md](STACK.md) for technology versions and [DEPLOYMENT.md](DEPLOYMENT.md) for infrastructure details.

---

## Admin Dashboard Capabilities

The admin dashboard (`ticketing-platform-dashboard/`) is the primary management interface. All routes are scoped under `/:organizationId`:

| Section | Route | What It Does |
|---------|-------|-------------|
| Events | `/events` | Create/edit events, ticket types, categories, timeslots, perks, discounts, seating plans, venues |
| Sales | `/sales/:branchId` | View orders, customers, refunds, affiliate partners and sales |
| Access Control | `/access-control/events` | Gate scanning management, scannable status, zone configuration |
| Reporting | `/reporting/:branchId` | Sales charts, access reports, data exports |
| Reservations | `/reservations` | Create and manage ticket reservations |
| Access Management | `/access-management` | Users, roles/permissions, branches, channels |
| Extension Flows | `/extension-flows` | Configure webhook/extension flows for platform events |

---

## Key Business Workflows

### Purchase Flow

Catalogue (event/ticket definition) --> Inventory (stock reservation) --> Pricing (price calculation) --> Sales (order + payment) --> Access Control (scannable generation) --> Media/PDF Generator (PDF ticket) --> Integration (email delivery) --> Loyalty (reward points)

### Gate Scanning

Mobile Scanner --> Access Control API (validate ticket, check zone policy, update scannable state)

### Ticket Transfer

Transfer service (initiate/accept) --> Access Control (reassign scannable) --> Integration (notification)

### Marketplace Resale

Marketplace (listing) --> Sales (purchase) --> Transfer (ownership change) --> Access Control (new scannable)

See the existing SUMMARY.md workflows section or [ARCHITECTURE.md](ARCHITECTURE.md) for detailed step-by-step flows.

---

## Event Bus (Inter-Service Communication)

All services communicate asynchronously via **AWS EventBridge --> SQS**:

- 18 consumer services, each with its own SQS queue + DLQ
- All events use `Source = "TicketingPlatform"`
- Subscription definitions: `ticketing-platform-infrastructure/TP.Infrastructure.MessageBroker/Consumers/Subscriptions/`
- Event type definitions: `ticketing-platform-tools/TP.Tools.MessageBroker/Entities/Events/`

**Top event publishers:** Catalogue (event/ticket CRUD), Sales (order lifecycle), Access Control (scannable state), Transfer (ownership changes), Organizations (tenant changes)

**Heaviest consumers:** Sales (~30+ event types), Access Control (~25+), Integration (~15+)

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full event flow diagram and consumer subscription details.

---

## Environments

| Environment | Branch | Domain | Notes |
|-------------|--------|--------|-------|
| dev | `development` | `dev.tickets.mdlbeast.net` | Shared VPC with sandbox |
| sandbox | `sandbox` | `sandbox.tickets.mdlbeast.net` | Shared VPC with dev |
| demo | `demo` | (demo) | Demo environment |
| prod | `master` | `tickets.mdlbeast.net` | Full HA, WAF, Redis, OpenSearch |

See [DEPLOYMENT.md](DEPLOYMENT.md) for CI/CD pipelines, CDK stacks, and operational runbooks.

---

## Quick Reference: Which Service Owns What?

| I need to... | Go to |
|--------------|-------|
| Create/edit events or ticket types | `ticketing-platform-catalogue` |
| Manage ticket stock, reservations, seating | `ticketing-platform-inventory` |
| Configure prices, discounts, coupons | `ticketing-platform-pricing` |
| Process orders or payments | `ticketing-platform-sales` |
| Scan tickets at the gate | `ticketing-platform-access-control` |
| Generate PDF tickets | `ticketing-platform-pdf-generator` or `ticketing-platform-media` |
| Send confirmation/notification emails | `ticketing-platform-integration` |
| Transfer tickets between people | `ticketing-platform-transfer` |
| List tickets for resale | `ticketing-platform-marketplace-service` |
| Manage organizations, users, roles | `ticketing-platform-organizations` |
| Loyalty rewards / Talon.One | `ticketing-platform-loyalty` |
| Export sales data as CSV | `ticketing-platform-csv-generator` |
| View charts/reports | `ticketing-platform-reporting-api` |
| Register webhooks/extensions | `ticketing-platform-extension-api` |
| Route API traffic | `ticketing-platform-gateway` |
| Manage event bus, SQS queues | `ticketing-platform-infrastructure` |
| Manage AWS networking (VPC, RDS) | `ticketing-platform-terraform-{env}` |
| Edit admin UI | `ticketing-platform-dashboard` |
| Edit partner portal UI | `ticketing-platform-distribution-portal-frontend` |
| Build gate scanner app | `ticketing-platform-mobile-scanner` |
| Add/modify shared .NET libraries | `ticketing-platform-tools` |

---

## Complete Repository Inventory

### Backend Domain Services (.NET 8.0, AWS Lambda + CDK)

| # | Repository | CDK Project | Cloned | Purpose |
|---|---|---|---|---|
| 1 | `ticketing-platform-access-control` | `TP.AccessControl.Cdk` | Yes | Scannables (QR/NFC), zones, zone policies, scanner devices, ticket validation |
| 2 | `ticketing-platform-automations` | `TP.Automations.Cdk` | Yes | Scheduled automation jobs: ticket senders, data exporters, finance reports, WhatsApp reminders |
| 3 | `ticketing-platform-bandsintown-integration` | `TP.Bandsintown.Integration.Cdk` | Yes | Product feed generator for Bandsintown platform (Lambda + API Gateway) |
| 4 | `ticketing-platform-catalogue` | `TP.Catalogue.Cdk` | Yes | Master record for events, ticket types, venues, categories, timeslots, perks, tags |
| 5 | `ticketing-platform-csv-generator` | `TP.CSVGenerator.Cdk` | Yes | Async Lambda consumer for generating CSV report exports to S3 |
| 6 | `ticketing-platform-customer-service` | `TP.Customers.Cdk` | Yes | Customer management, background jobs, SQS consumers |
| 7 | `ticketing-platform-distribution-portal` | `TP.DistributionPortal.Cdk` | Yes | Backend API for partner ticket distribution and attendee management |
| 8 | `ticketing-platform-extension-api` | `TP.Extensions.Cdk` | Yes | Extension definitions, flows, execution history, code management |
| 9 | `ticketing-platform-extension-deployer` | `TP.Extensions.Deployer.Cdk` | Yes | Provisions Lambda functions for code-based extensions |
| 10 | `ticketing-platform-extension-executor` | `TP.Extensions.Executor.Cdk` | Yes | Executes registered extensions in parallel on platform events via SQS |
| 11 | `ticketing-platform-extension-log-processor` | `TP.Extensions.LogsProcessor.Cdk` | Yes | Captures execution logs and duration metrics from SQS |
| 12 | `ticketing-platform-geidea` | `TP.Geidea.Cdk` | Yes | Geidea payment gateway integration with own persistence and polling |
| 13 | `ticketing-platform-integration` | `TP.Integration.Cdk` | Yes | Outbound emails (SendGrid), webhooks, notification preferences, payment callbacks |
| 14 | `ticketing-platform-inventory` | `TP.Inventory.Cdk` | Yes | Stock pools, channel allocations, reservations, carts, seating plans (Seats.io) |
| 15 | `ticketing-platform-loyalty` | `TP.Loyalty.Cdk` | Yes | Talon.One loyalty engine integration (points, campaigns, rewards) |
| 16 | `ticketing-platform-marketing-feeds` | `TP.Marketing.Feeds.Cdk` | Yes | Marketing product feeds for Google, Snapchat, Meta (Lambda + API Gateway) |
| 17 | `ticketing-platform-marketplace-service` | `TP.Marketplace.Cdk` | Yes | Secondary ticket resale (listings, transactions, seller accounts) |
| 18 | `ticketing-platform-media` | `TP.Media.Cdk` | Yes | PDF ticket templates, KYC documents, S3 media uploads, presigned URLs |
| 19 | `ticketing-platform-organizations` | `TP.Organizations.Cdk` | Yes | Multi-tenant identity: organizations, branches, channels, users, roles, permissions |
| 20 | `ticketing-platform-pdf-generator` | `TP.PdfGenerator.Cdk` | Yes | Async Lambda consumer for rendering PDF tickets from scannable events |
| 21 | `ticketing-platform-pricing` | `TP.Pricing.Cdk` | Yes | Price calculations, discounts, coupons for checkout cart flow |
| 22 | `ticketing-platform-reporting-api` | `TP.ReportingService.Cdk` | Yes | Aggregated sales/access charts and event-level summary reports |
| 23 | `ticketing-platform-sales` | `TP.Sales.Cdk` | Yes | Orders, payments (HyperPay/Tabby/Checkout.com), refunds, customers, affiliates |
| 24 | `ticketing-platform-transfer` | `TP.Transfer.Cdk` | Yes | Ticket transfer lifecycle between attendees (initiate/accept/cancel) |
| 25 | `ticketing-platform-xp-badges` | `TP.XpBadges.Cdk` | Yes | XP badge search Lambda — looks up scannables, customers, Google Sheets survey data |

### Shared Libraries & Platform Infrastructure

| # | Repository | CDK Project | Cloned | Purpose |
|---|---|---|---|---|
| 26 | `ticketing-platform-tools` | `Debug.Cdk` | Yes | NuGet packages (`TP.Tools.*`): shared entities, data access, messaging, logging, CDK constructs |
| 27 | `ticketing-platform-infrastructure` | `TP.Infrastructure.Cdk` | Yes | Shared AWS CDK: EventBridge bus, SQS queues, Slack notifications, monitoring, RDS Proxy |
| 28 | `ticketing-platform-gateway` | `Gateway.Cdk` | Yes | YARP reverse proxy routing API traffic to 14+ backend services |
| 29 | `ticketing-platform-shared` | — | Yes | NPM package: `TicketingClient` TypeScript HTTP client for consuming the platform API |

### User-Facing Applications

| # | Repository | Tech | Cloned | Purpose |
|---|---|---|---|---|
| 30 | `ticketing-platform-dashboard` | Next.js 15, React 18, MUI 5 | Yes | Full event/sales/access management admin UI for organizers |
| 31 | `ticketing-platform-distribution-portal-frontend` | Next.js 13, MUI 5, i18next | Yes | Partner-facing portal for ticket allocation and attendees |
| 32 | `ticketing-platform-mobile-scanner` | Expo 52, React Native | Yes | Gate scanning app with NFC/barcode hardware integration (Android-only) |
| 33 | `ticketing-platform-mobile-libraries` | Yarn workspaces, Expo Modules | Yes | Native modules: `acs-smc-sdk` (NFC), `expo-serial-usb` (LED) |

### Configuration & Terraform

| # | Repository | Cloned | Purpose |
|---|---|---|---|
| 34 | `ticketing-platform-configmap-dev` | Yes | Kubernetes ConfigMaps for dev environment |
| 35 | `ticketing-platform-configmap-sandbox` | Yes | Kubernetes ConfigMaps for sandbox environment |
| 36 | `ticketing-platform-configmap-prod` | Yes | Kubernetes ConfigMaps for production environment |
| 37 | `ticketing-platform-configmap-demo` | No | Kubernetes ConfigMaps + ingress for demo environment |
| 38 | `ticketing-platform-terraform-dev` | Yes | Terraform modules for dev/sandbox AWS infrastructure |
| 39 | `ticketing-platform-terraform-prod` | Yes | Terraform modules for production AWS infrastructure |
| 40 | `ticketing-platform-terraform-demo` | No | Terraform modules for demo environment |

### DevOps, CI/CD & Observability (not cloned)

| # | Repository | Cloned | Purpose |
|---|---|---|---|
| 41 | `ticketing-platform-devops` | No | Docker images, service account configs (S3/SQS) |
| 42 | `ticketing-platform-templates-ci-cd` | No | Shared GitHub Actions workflow templates and Helm charts |
| 43 | `ticketing-platform-ingress` | No | Docker + Kubernetes ingress manifests |
| 44 | `ticketing-platform-prometheus` | No | Prometheus/Grafana monitoring stack (Helm, scrape configs, dashboards) |

### Legacy / Inactive (not cloned)

| # | Repository | Cloned | Purpose |
|---|---|---|---|
| 45 | `ticketing-platform-emails` | No | MJML email templates (legacy, likely superseded by Integration service) |
| 46 | `ticketing-platform-express` | No | Legacy Node.js/Express API (Bitbucket-era, pre-.NET migration) |
| 47 | `ticketing-platform-react` | No | Legacy React frontend (Bitbucket-era, pre-Next.js migration) |
| 48 | `ticketing-platform-web-scanner` | No | Next.js web-based scanner (likely superseded by mobile scanner app) |
| 49 | `ticketing-platform-extension-remover` | No | Empty repository |

### Utility

| # | Repository | Cloned | Purpose |
|---|---|---|---|
| 50 | `ticketing-work-smart-scripts` | Yes | Developer utility scripts (branch protection, PR creator) |

**Totals:** 50 repositories (38 cloned, 12 remote-only). 28 with CDK projects, 25 backend domain services.

---

## Related Documents

| Document | What It Covers |
|----------|---------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | .NET service structure, Clean Architecture pattern, event bus details, service inventory with project breakdowns |
| [STACK.md](STACK.md) | Technology versions, frameworks, key dependencies, language/runtime details |
| [DEPLOYMENT.md](DEPLOYMENT.md) | CI/CD pipelines, CDK stacks, Lambda packaging, EKS deployment, secrets management, monitoring, operational runbooks |
| `CLAUDE.md` (repo root) | Build commands, architecture overview, code style rules -- guidance for Claude Code |

---

## Backups

### Copy Aurora RDS snapshot from me-south-1 to eu-central-1

```sh
aws rds copy-db-cluster-snapshot \
--source-db-cluster-snapshot-identifier "arn:aws:rds:me-south-1:660748123249:cluster-snapshot:rds:ticketing-2026-03-08-07-13" \
--target-db-cluster-snapshot-identifier "ticketing-2026-03-08-07-13" \
--kms-key-id "arn:aws:kms:eu-central-1:660748123249:key/mrk-fa75a489427742b38516cebf97f47a95" \
--source-region me-south-1 \
--region eu-central-1 \
--profile AdministratorAccess-660748123249
```

*Last updated: 2026-03-04*
