# Technology Stack Reference

**Last Updated:** 2026-03-04

This is a personal reference for working across all 30+ services in the MDLBEAST Ticketing Platform monorepo.

---

## Overview: Polyglot Monorepo

| Tier | Technology | Services |
|------|-----------|----------|
| Backend | C# / .NET 8.0 / ASP.NET Core | 20+ services |
| Frontend (Admin) | TypeScript / Next.js 15 / React 18 | `ticketing-platform-dashboard` |
| Frontend (Distribution) | TypeScript / Next.js 13 / React 18 | `ticketing-platform-distribution-portal-frontend` |
| Backend (Distribution Portal API) | C# / .NET 8.0 / Docker/Kubernetes | `ticketing-platform-distribution-portal` |
| Mobile | TypeScript / React Native / Expo 52 | `ticketing-platform-mobile-scanner` |
| Mobile Libraries | TypeScript / Expo Modules | `ticketing-platform-mobile-libraries` |
| Infrastructure (CDK) | C# / AWS CDK v2 | per-service + `ticketing-platform-infrastructure` |
| Infrastructure (Terraform) | HCL | `ticketing-platform-terraform-dev/prod` |
| Config / K8s | YAML / Kubernetes ConfigMaps | `ticketing-platform-configmap-*` |

---

## Languages & Runtimes

### C# / .NET
- **Version:** .NET 8.0 (`net8.0` target framework) across all backend services
- **SDK:** .NET 8.0.x (enforced via GitHub Actions `dotnet-version: 8.0.x`)
- **Note:** Some older services have `global.json` pinned to `6.0.0` with `rollForward: latestMajor` (e.g., `ticketing-platform-distribution-portal`, `ticketing-platform-reporting-api`) -- these still build against .NET 8 in practice
- **Entry location:** `src/TP.{Service}.API/LambdaEntry.cs` for Lambda; `Program.cs` for hosted APIs

### TypeScript
- **Dashboard:** TypeScript 5.8.3 (`ticketing-platform-dashboard/package.json`)
- **Distribution Portal Frontend:** TypeScript 5.2.2
- **Mobile Scanner:** TypeScript ~5.3.3
- **Shared Client Lib:** TypeScript (latest 7.x)
- **Strict mode:** enabled in dashboard (`"strict": true` in `tsconfig.json`)
- **Target:** `es2021`, `CommonJS` modules (dashboard)

### Node.js
- **Required:** Node.js 20.x (enforced via GitHub Actions `node-version: [20.x]`)
- **Package manager:** npm for dashboard and mobile scanner; yarn 3.8.0 for mobile libraries
- **Dependabot:** Configured for daily npm and weekly GitHub Actions updates (dashboard)

---

## Backend: .NET Services

### Framework Stack

| Package | Version | Purpose |
|---------|---------|---------|
| `Amazon.Lambda.AspNetCoreServer` | 9.2.0 | ASP.NET Core to Lambda bridge |
| `Microsoft.EntityFrameworkCore` | 9.0.11 (tools), 8.0.x (some older) | ORM |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | 9.0.4 | PostgreSQL EF Core provider |
| `Dapper` | 2.1.66 | Micro-ORM for raw queries |
| `MediatR` | 12.4.1 | CQRS command/query dispatch |
| `FluentValidation` | 12.1.1 | Request validation |
| `FluentValidation.AspNetCore` | 11.3.1 | ASP.NET Core validation pipeline |
| `AutoMapper` | 14.0.0 | Object mapping (sales, gateway) |
| `Mapster` | 7.4.0 | Object mapping (sales infrastructure) |
| `Serilog.AspNetCore` | 8.0.3 | Structured logging |
| `Serilog.Exceptions.EntityFrameworkCore` | 8.4.0 | EF Core exception enrichment |
| `Polly.Core` | 8.6.5 | Resilience and retry |
| `Swashbuckle.AspNetCore` | 7.2.0 / 10.1.0 | OpenAPI/Swagger |
| `Yarp.ReverseProxy` | 2.3.0 | Reverse proxy (gateway only) |
| `StyleCop.Analyzers` | 1.2.0-beta.556 | Code style enforcement |

### Authentication (Backend)
- `Microsoft.AspNetCore.Authentication.JwtBearer` 8.0.22 -- JWT validation against Auth0
- Auth0 domain: `auth.{env}.admin.tickets.mdlbeast.net`
- JWT audience: `https://ticketing-platform-{env}`

### Database
- **Primary DB:** PostgreSQL (Aurora on AWS, accessed via RDS Proxy in prod)
- **ORM:** Entity Framework Core with Npgsql provider
- **Migrations:** Per-service in `src/TP.{Service}.Infrastructure/Migrations/`
- **Run migrations:** Lambda function (`{service}-db-migrator-lambda-{env}`) invoked by CI/CD
- **Raw queries:** Dapper alongside EF Core in `TP.Tools.DataAccessLayer`
- **Caching:** Redis via `StackExchange.Redis` 2.10.1 (in `TP.Tools.DataAccessLayer`)
- **Bulk operations:** `Z.EntityFramework.Extensions.EFCore` / `Z.EntityFramework.Plus.EFCore` (inventory service)
- **Data encryption at rest:** `EntityFrameworkCore.DataEncryption` 6.0.0 (access-control)
- **Dynamic LINQ:** `System.Linq.Dynamic.Core` 1.7.1, `Microsoft.EntityFrameworkCore.DynamicLinq` 8.7.1 (sales)

### Serialization
- **System.Text.Json 10.0.1** -- Primary JSON serializer (modern)
- **Newtonsoft.Json 13.0.4** -- Secondary/legacy JSON serializer
- **Macross.Json.Extensions 3.0.0** -- JSON enum converter extensions (sales)

### Email
- **SendGrid 9.29.3** -- Transactional email (via `TP.Tools.Helpers`)
- **SendGrid.Extensions.DependencyInjection 1.0.1**

### Health Checks
- **AspNetCore.HealthChecks.NpgSql 9.0.0** -- PostgreSQL health checks
- **AspNetCore.HealthChecks.Redis 9.0.0** -- Redis health checks
- **HealthChecks.Extensions 1.0.1**

### HTTP Clients
- **RestSharp 113.0.0** -- HTTP client for external APIs (media, organizations)
- **RestSharp.Serializers.NewtonsoftJson 113.0.0** -- JSON serialization for RestSharp

### Phone Numbers
- **libphonenumber-csharp 9.0.21** -- Phone number parsing/validation (via `TP.Tools.PhoneNumbers`)

### CSV Processing
- **CsvHelper 33.1.0** -- CSV reading/writing (sales)

### PDF Generation
- **QuestPDF 2024.10.1** -- PDF ticket generation (`ticketing-platform-pdf-generator`)
- **SkiaSharp 2.88.8** -- Graphics rendering for PDFs
- **SkiaSharp.NativeAssets.Linux.NoDependencies 2.88.8** -- Linux native assets for Lambda
- **SkiaSharp.QrCode 0.7.0** -- QR code generation on tickets

### TOTP/Security
- **Otp.NET 1.4.1** -- Time-based one-time password (via `TP.Tools.Helpers`)

### AWS Services Used by .NET Services

| AWS Service | SDK Package | Purpose |
|------------|------------|---------|
| Lambda | `Amazon.Lambda.AspNetCoreServer` 9.2.0 | Hosts all backend APIs |
| SQS | `AWSSDK.SQS` 3.7.502.19 | Event consumers |
| EventBridge | `AWSSDK.EventBridge` 3.7.502.24 | Event bus publishing |
| S3 | `AWSSDK.S3` 3.7.508.4 | Large event payloads, PDF storage, media |
| Secrets Manager | `AWSSDK.SecretsManager` 3.7.504.5 | Runtime secrets |
| SSM Parameter Store | `AWSSDK.SimpleSystemsManagement` 3.7.504.15 | Config parameters |
| DynamoDB | `AWSSDK.DynamoDBv2` 3.7.509.12 | Dedup tables (infra) |
| CloudWatch Logs | `AWSSDK.CloudWatchLogs` 3.7.305.6 | Log monitoring |
| CDK v2 | `Amazon.CDK.Lib` 2.233.0 | Infrastructure as code |
| CDK Scheduler | `Amazon.CDK.AWS.Scheduler.Alpha` 2.141.0-alpha.0 | Serverless scheduled jobs |
| STS | `AWSSDK.SecurityToken` 3.7.504.12 | Cross-account/role assumption |
| X-Ray | `AWSXRayRecorder` 2.16.0 | Distributed tracing |
| X-Ray EF Core | `AWSXRayRecorder.Handlers.EntityFramework` 1.7.0 | EF Core trace integration |
| X-Ray AWS SDK | `AWSXRayRecorder.Handlers.AwsSdk` 2.14.0 | AWS SDK call tracing |
| X-Ray HTTP | `AWSXRayRecorder.Handlers.System.Net` 2.13.0 | HTTP client tracing |
| Lumigo | `Lumigo.DotNET` 1.0.51 | Lambda observability |
| SNS | `Amazon.Lambda.SNSEvents` 2.1.1 | SNS alarm notifications |
| Default Region | `me-south-1` (Bahrain) | All production infrastructure |

### CDK Pattern (per-service)
Each backend service has `src/TP.{Service}.Cdk/` deploying:
- `TP-ServerlessBackendStack-{service}-{env}` -- API Gateway + Lambda
- `TP-ConsumersStack-{service}-{env}` -- SQS consumer Lambda
- `TP-BackgroundJobsStack-{service}-{env}` -- Scheduled Lambda
- `TP-DbMigratorStack-{service}-{env}` -- Migration Lambda

---

## Internal NuGet Packages: TP.Tools.*

Feed: `https://nuget.pkg.github.com/mdlbeasts/index.json`
Current version series: `1.0.1292` / `1.0.1293` (latest as of this document)
Version format: `1.0.{github_run_number}` -- auto-bumped on every push to `master` or `development`

| Package | Purpose | Key Dependencies |
|---------|---------|-----------------|
| `TP.Tools.Libs.Entities` | Base entities and contracts | (none) |
| `TP.Tools.SharedEntities` | Domain entities, contracts, enums, DTOs shared across all services | NodaTime, RestEase, JWT |
| `TP.Tools.PhoneNumbers` | Phone number parsing via libphonenumber-csharp | libphonenumber-csharp 9.0.21 |
| `TP.Tools.DataAccessLayer` | EF Core + Dapper DB access, PostgreSQL + Redis support | Npgsql 9.0.4, Dapper 2.1.66, StackExchange.Redis 2.10.1 |
| `TP.Tools.Helpers` | SendGrid email, health checks, FluentValidation, MediatR, Polly, OTP, DynamoDB | SendGrid 9.29.3, MediatR 12.4.1, Polly 8.6.5, AWSSDK.DynamoDB |
| `TP.Tools.Logger` | Serilog structured logging with custom enrichers | Serilog.AspNetCore 8.0.3, Serilog.Exceptions.EntityFrameworkCore 8.4.0 |
| `TP.Tools.MessageBroker` | SQS/EventBridge/S3 message broker | AWSSDK.SQS, AWSSDK.EventBridge, AWSSDK.S3 |
| `TP.Tools.Infrastructure` | AWS CDK constructs, Lambda utilities, Secrets Manager, SSM Parameter Store | Amazon.CDK.Lib 2.233.0, Lumigo 1.0.51 |
| `TP.Tools.BackgroundJobs` | CDK Scheduler constructs for scheduled Lambdas | Amazon.CDK.AWS.Scheduler.Alpha 2.141.0-alpha.0 |
| `TP.Tools.RestVersioning` | API versioning (Asp.Versioning) | |
| `TP.Tools.Swagger` | Swagger/OpenAPI config | Swashbuckle.AspNetCore 10.1.0 |
| `TP.Tools.Validator` | FluentValidation pipeline integration | FluentValidation.AspNetCore 11.3.1, MediatR 12.4.1 |

**Dependency graph (simplified):**
```
TP.Tools.Libs.Entities (base entities)
    +-- TP.Tools.SharedEntities
    |       +-- TP.Tools.DataAccessLayer
    |       +-- TP.Tools.MessageBroker
    +-- TP.Tools.Logger
    |       +-- TP.Tools.Helpers
    +-- TP.Tools.Infrastructure
            +-- TP.Tools.BackgroundJobs
```

---

## Architecture Patterns (.NET Services)

### Clean Architecture Project Layout
```
src/
  TP.{Service}.API/           # ASP.NET Core + Lambda entry
    Features/{Feature}/
      Endpoints/
      Validators/
  TP.{Service}.Domain/        # Entities, aggregates, interfaces
  TP.{Service}.Infrastructure/ # EF Core, Dapper, external integrations
    Migrations/
  TP.{Service}.Consumers/     # SQS Lambda handlers (MediatR dispatch)
  TP.{Service}.BackgroundJobs/ # Scheduled Lambda functions
  TP.{Service}.Functions/     # Standalone Lambda functions (some services)
  TP.{Service}.Cdk/           # AWS CDK infrastructure stacks
Tests/
  TP.{Service}.UnitTests/
  TP.{Service}.IntegrationTests/
  TP.{Service}.ConsumerTests/
  TP.{Service}.BackgroundJobsTests/
```

### Feature Pattern (API layer)
- Vertical slice: each feature has its own folder under `Features/`
- Endpoints use Minimal API or controller pattern
- FluentValidation validators co-located with endpoints
- MediatR commands/queries dispatched from endpoints

### Event Pattern
- Publish: `TP.Tools.MessageBroker` publishes events to EventBridge (`Source = "TicketingPlatform"`)
- Subscribe: SQS queue per consumer service, rules defined in `ticketing-platform-infrastructure/TP.Infrastructure.MessageBroker/Consumers/Subscriptions/`
- Large payloads (>256KB): stored in S3 bucket `ticketing-{env}-extended-message`, consumer gets presigned URL
- Add subscription: add `.AddEvent<EventType>()` to `{Service}Subscriptions.cs`

---

## Third-Party NuGet Packages (Notable)

| Package | Version | Used In | Purpose |
|---------|---------|---------|---------|
| `SeatsioDotNet` | 107.3.0 | sales, catalogue, access-control, inventory | Seating charts / venue management |
| `CheckoutSDK` | 4.17.0 | sales | Checkout.com payment processing |
| `CheckoutSDK.Extensions.Microsoft` | 4.17.0 | sales | DI extensions for Checkout.com |
| `TalonOne` | 8.0.0 | loyalty, pricing | Promotions and loyalty engine |
| `QuestPDF` | 2024.10.1 | pdf-generator | PDF ticket generation |
| `SkiaSharp` | 2.88.8 | pdf-generator | Graphics rendering for PDFs |
| `CsvHelper` | 33.1.0 | multiple services | CSV import/export |
| `NanoXLSX` | latest | reporting | Excel generation |
| `RestSharp` | 113.0.0 | media, organizations | HTTP client |
| `BCrypt.Net-Next` | 4.0.3 | organizations | Password hashing |
| `SendGrid` | 9.29.3 | tools/helpers, csv-generator, organizations | Transactional email |
| `Z.EntityFramework.Extensions.EFCore` | 9.105.2 | inventory | Bulk EF Core operations |
| `EntityFrameworkCore.DataEncryption` | 6.0.0 | access-control | Column-level encryption |
| `Otp.NET` | 1.4.1 | tools/helpers | TOTP / 2FA support |
| `NodaTime` | 3.2.3 | shared-entities | Time zone handling |
| `RestEase` | 1.6.4 | shared-entities | REST client generation |
| `Polly` | 8.x | multiple | Resilience policies |
| `Polly.Testing` | 8.6.5 | integration tests | Polly test helpers |
| `libphonenumber-csharp` | 9.0.21 | tools/phone-numbers | Phone parsing |
| `Macross.Json.Extensions` | 3.0.0 | sales | JSON extensions |
| `Microsoft.OpenApi` | 1.6.28 | gateway | OpenAPI spec reading |

---

## Frontend: Dashboard (`ticketing-platform-dashboard`)

### Core Stack
| Package | Version | Purpose |
|---------|---------|---------|
| `next` | ^15.3.6 | React framework (App Router + Pages) |
| `react` | 18.3.1 | UI library |
| `react-dom` | 18.3.1 | DOM rendering |
| `typescript` | 5.8.3 | Type system |

### UI & Styling
| Package | Version | Purpose |
|---------|---------|---------|
| `@mui/material` | ^5.16.7 | Material UI component library |
| `@mui/icons-material` | 5.16.11 | MUI icon set |
| `@mui/lab` | ^5.0.0-alpha.173 | MUI lab components |
| `@mui/x-date-pickers` | ^7.29.4 | MUI date/time pickers |
| `@mui/styled-engine-sc` | 6.1.8 | MUI styled-components engine |
| `@mui/system` | 5.16.7 | MUI system utilities |
| `styled-components` | 6.1.18 | CSS-in-JS (primary) |
| `tailwindcss` | ^4.1.7 | Utility CSS (newer addition alongside MUI) |
| `@tailwindcss/postcss` | ^4.1.7 | Tailwind PostCSS plugin |
| `postcss` | ^8.5.3 | CSS processing |
| `tailwind-merge` | ^3.3.0 | Tailwind class merging |
| `tailwindcss-animate` | ^1.0.7 | Animation utilities |
| `lucide-react` | ^0.511.0 | Icon library |
| `@radix-ui/react-popover` | ^1.1.14 | Headless UI primitives |
| `@radix-ui/react-switch` | ^1.2.5 | Headless switch |
| `clsx` | ^2.1.1 | Conditional class names |
| `notistack` | 3.0.2 | Snackbar/toast notifications |
| `dayjs` | 1.11.13 | Date manipulation |
| `@fontsource/roboto` | ^5.2.5 | Roboto font |
| `nprogress` | ^0.2.0 | Page navigation progress bar |

### Data & State
| Package | Version | Purpose |
|---------|---------|---------|
| `@tanstack/react-query` | 4.36.1 | Server state management |
| `react-hook-form` | 7.53.2 | Form management |
| `orval` | ^7.9.0 | API type generation from OpenAPI |

### Auth
| Package | Version | Purpose |
|---------|---------|---------|
| `@auth0/auth0-react` | 2.3.0 | Auth0 SPA authentication |

### Error Tracking
| Package | Version | Purpose |
|---------|---------|---------|
| `@sentry/nextjs` | ^9.22.0 | Sentry error tracking and sourcemaps |

### Charts & Visualization
| Package | Version | Purpose |
|---------|---------|---------|
| `chart.js` | ^4.4.9 | Chart library |
| `react-chartjs-2` | ^5.3.0 | React Chart.js wrapper |
| `@seatsio/seatsio-react` | ^15.10.0 | Seating chart component |
| `react-big-calendar` | ^1.18.0 | Calendar component |
| `react-day-picker` | ^9.7.0 | Date picker component |

### Rich Content / Editors
| Package | Version | Purpose |
|---------|---------|---------|
| `@monaco-editor/react` | ^4.7.0 | Monaco code editor (for extensions) |
| `monaco-editor` | ^0.52.2 | Monaco core |

### Drag & Drop
| Package | Version | Purpose |
|---------|---------|---------|
| `react-beautiful-dnd` | ^13.1.1 | Drag-and-drop interactions |
| `react-beautiful-dnd-grid` | ^0.1.3-alpha | Grid layout DnD |

### UI Components (Additional)
| Package | Version | Purpose |
|---------|---------|---------|
| `react-color` | ^2.19.3 | Color picker |
| `react-highlight-words` | ^0.21.0 | Text highlighting |
| `react-international-phone` | ^4.6.0 | Phone input |
| `mui-tel-input` | ^3.2.2 | MUI telephone input |
| `react-resizable-panels` | ^3.0.2 | Resizable panel layout |
| `react-helmet-async` | ^2.0.5 | Document head management |
| `country-flag-icons` | ^1.5.19 | Flag icons |
| `minidenticons` | ^4.2.1 | Minimal identicons |
| `qrcode.react` | ^4.2.0 | QR code component |
| `react-barcode-reader` | 0.0.2 | Barcode scanner |
| `react-svgmt` | ^3.0.0 | SVG manipulation |
| `react-hook-form` | 7.53.2 | Form state |

### Testing (Dashboard)
| Package | Version | Purpose |
|---------|---------|---------|
| `jest` | ^29.7.0 | Test runner |
| `jest-environment-jsdom` | ^29.7.0 | DOM environment for Jest |
| `@testing-library/react` | ^16.3.0 | React Testing Library |
| `@testing-library/dom` | ^10.4.0 | DOM testing utilities |
| `@testing-library/jest-dom` | ^6.6.3 | DOM matchers |
| `@emotion/jest` | ^11.13.0 | Emotion snapshot serializer |
| `cypress` | 14.4.0 | E2E testing |
| `@cucumber/cucumber` | ^11.3.0 | BDD (Cucumber) |

### Storybook
| Package | Version | Purpose |
|---------|---------|---------|
| `storybook` | ^8.6.14 | Component development environment |
| `@storybook/nextjs` | ^8.6.14 | Next.js Storybook integration |
| `@storybook/react` | ^8.6.14 | React Storybook |
| `@storybook/addon-essentials` | ^8.6.14 | Core addons |
| `@storybook/addon-designs` | ^8.2.1 | Figma/design integration |
| `@storybook/addon-storysource` | ^8.6.14 | Source code display |
| `@storybook/addon-docs` | ^8.6.14 | Documentation addon |
| `@storybook/test` | ^8.6.14 | Storybook test utilities |
| `storybook-addon-pseudo-states` | ^4.0.4 | Pseudo-state testing |
| `storybook-addon-code-editor` | ^4.1.2 | Live code editor |
| `chromatic` | ^12.0.0 | Visual regression testing |
| `@chromatic-com/storybook` | ^3.2.6 | Chromatic Storybook addon |

### Build & Dev Tools (Dashboard)
| Package | Version | Purpose |
|---------|---------|---------|
| `eslint` | ^8.57.1 | Linting |
| `eslint-config-next` | ^14.2.15 | Next.js ESLint config |
| `@typescript-eslint/eslint-plugin` | ^8.33.0 | TypeScript ESLint rules |
| `@typescript-eslint/parser` | ^8.33.0 | TypeScript parser |
| `prettier` | 3.5.3 | Code formatting |
| `@svgr/cli` | ^8.1.0 | SVG to React component generation |
| `@svgr/webpack` | 8.1.0 | Webpack SVG loader |
| `@next/bundle-analyzer` | 15.3.2 | Bundle size analysis |
| `swagger-typescript-api` | ^13.1.3 | Swagger to TypeScript (alternative to Orval) |
| `sharp` | ^0.34.2 | Image optimization |
| `ts-node` | ^10.9.2 | TypeScript execution |

### Path Aliases (Dashboard)
Defined in `ticketing-platform-dashboard/tsconfig.json` (base: `./src`):
```
@assets/*      -> src/assets/*
@components/*  -> src/components/*
@constants/*   -> src/constants/*
@environment/* -> src/environment/*
@hooks/*       -> src/hooks/*
@hue/*         -> src/hue/*
@pages/*       -> src/pages/*
@queries/*     -> src/queries/*
@services/*    -> src/services/*
@styles/*      -> src/styles/*
@theme/*       -> src/theme/*
@sharedtypes/* -> src/types/*
@utils/*       -> src/utils/*
```

### Jest Configuration (Dashboard)
- Config: `ticketing-platform-dashboard/jest.config.ts`
- Uses `next/jest` (`createJestConfig`)
- Environment: `jsdom`
- Coverage provider: `v8`
- Snapshot serializer: `@emotion/jest/serializer`
- Setup file: `jest.setup.ts`
- Clears mocks automatically (`clearMocks: true`)
- Module name mapper mirrors path aliases

### Next.js Configuration (Dashboard)
- Config: `ticketing-platform-dashboard/next.config.js`
- Sentry integration via `withSentryConfig`
- Bundle analyzer via `@next/bundle-analyzer`
- styled-components compiler enabled
- SVG handling via `@svgr/webpack`
- ESLint ignored during builds (`ignoreDuringBuilds: true`)

### API Proxying (Dashboard)
```
/tp/*         -> $TP_HOST/*          (API Gateway proxy)
/api/media/*  -> $MEDIA_HOST/media/* (Media service proxy)
/npmregistry/* -> registry.npmjs.org  (npm registry proxy)
```

### Orval API Code Generation
- Config: `ticketing-platform-dashboard/orval.config.ts`
- Generates React Query hooks from OpenAPI specs
- Services: sales, catalogue, organizations, access, integrations, inventory, transfers, pricing
- Output: `src/openapi/ticketing-platform/{service}/`
- Base URL: `/tp` (proxied to API Gateway)
- Client: custom `useCustomClient` mutator
- Post-generation: ESLint fix + Prettier

### Deployment
- **Platform:** Vercel (via `ticketing-platform-dashboard/.github/workflows/vercel-deploy.yml`)
- **Branches:** `development` -> dev, `sandbox` -> sandbox, `production` -> prod

---

## Frontend: Distribution Portal (`ticketing-platform-distribution-portal-frontend`)

### Core Stack
| Package | Version | Purpose |
|---------|---------|---------|
| `next` | ^13.4.19 | React framework (Pages Router) |
| `react` | ^18.2.0 | UI library |
| `typescript` | 5.2.2 | Type system |

### UI & Styling
| Package | Version | Purpose |
|---------|---------|---------|
| `@mui/material` | ^5.14.7 | Material UI |
| `@emotion/react` | 11.11.4 | Emotion CSS-in-JS |
| `@emotion/styled` | 11.11.0 | Emotion styled components |
| `styled-components` | 5.3.11 | CSS-in-JS |
| `stylis-plugin-rtl` | ^2.1.1 | RTL support for Arabic |

### i18n
| Package | Version | Purpose |
|---------|---------|---------|
| `i18next` | ^23.5.1 | Internationalization |
| `next-i18next` | ^14.0.3 | Next.js i18n |
| `react-i18next` | ^13.5.0 | React i18n hooks |
| `react-intl` | ^6.6.4 | Internationalization |
| Locales | `ar`, `en` | Arabic and English |

### Auth
- `@auth0/auth0-react` 2.2.4

### Data
- `@tanstack/react-query` 4.33.0
- `react-hook-form` 7.51.1

### Charts
- `recharts` ^2.8.0

### Date/Time
- `dayjs` 1.11.10, `date-fns` 2.30.0, `date-fns-tz` 2.0.1

### Other
- `react-share` ^5.1.0 -- Social sharing
- `react-swipeable` ^7.0.1 -- Touch swipe
- `dompurify` ^3.0.11 -- HTML sanitization
- `file-saver` ^2.0.5 -- File download
- `lodash` 4.17.21 -- Utility functions

### Testing
- `cypress` 13.7.0 -- E2E testing

---

## Backend API: Distribution Portal (`ticketing-platform-distribution-portal`)

Same Clean Architecture as other .NET services but deployed as Docker/Kubernetes (not Lambda):
- Base image: `mcr.microsoft.com/dotnet/aspnet:8.0`
- Listens on port 5000
- Deployed via Helm to Kubernetes cluster (`ticketing-dev` / `ticketing-prod` namespaces)
- Services communicate via internal Kubernetes DNS: `http://{service}.ticketing-{env}.svc.cluster.local:5000`
- Helm chart: `ticketing-platform-distribution-portal/helm/dp/values-{env}.yaml`

---

## Mobile: Scanner App (`ticketing-platform-mobile-scanner`)

### Core Stack
| Package | Version | Purpose |
|---------|---------|---------|
| `expo` | ^52.0.44 | Expo SDK |
| `react-native` | 0.76.9 | React Native framework |
| `react` | 18.3.1 | UI library |
| `expo-router` | ~4.0.20 | File-based routing |
| `typescript` | ~5.3.3 | Type system |

### Platform
- **Android only** (no iOS builds in production; iOS config present but unused)
- EAS Build for cloud builds, `eas build --local` for local builds
- Runtime version: `1.1.3` (OTA updates channel)
- App version: `1.1.26`, versionCode: `160`
- Bundle ID: `com.mdlbeast.ticketingplatformmobilescanner`

### Key Expo Packages
| Package | Version | Purpose |
|---------|---------|---------|
| `expo-camera` | ~16.0.18 | Barcode/QR scanning |
| `expo-sqlite` | ~15.1.4 | Local offline database |
| `expo-updates` | ~0.27.4 | OTA updates |
| `expo-dev-client` | ~5.0.19 | Development builds |
| `expo-av` | ~15.0.2 | Audio/video |
| `expo-image` | ~2.0.7 | Optimized image rendering |
| `expo-keep-awake` | ~14.0.3 | Keep screen awake during scanning |
| `expo-haptics` | ~14.0.1 | Haptic feedback |
| `expo-screen-orientation` | ~8.0.4 | Screen orientation control |
| `expo-splash-screen` | ~0.29.22 | Splash screen |
| `expo-status-bar` | ~2.0.1 | Status bar management |
| `expo-application` | ~6.0.2 | Application info |
| `expo-device` | ~7.0.3 | Device info |
| `expo-constants` | ~17.0.8 | App constants |
| `expo-font` | ~13.0.4 | Custom fonts |
| `expo-asset` | ~11.0.5 | Asset management |
| `expo-linking` | ~7.0.5 | Deep linking |
| `expo-web-browser` | ~14.0.2 | In-app browser |
| `expo-navigation-bar` | ~4.0.9 | Navigation bar |
| `expo-system-ui` | ~4.0.9 | System UI integration |

### State & Data
| Package | Version | Purpose |
|---------|---------|---------|
| `@tanstack/react-query` | ^5.56.2 | Server state (v5 -- newer than dashboard v4) |
| `@tanstack/react-query-persist-client` | ^5.56.2 | Query persistence |
| `@tanstack/query-async-storage-persister` | ^5.56.2 | AsyncStorage persister |
| `@react-native-async-storage/async-storage` | 1.23.1 | Local storage |
| `react-hook-form` | ^7.53.0 | Form management |

### Auth
- `react-native-auth0` ^3.2.1 -- Auth0 native SDK
- Auth0 domain varies by environment (set via `EXPO_PUBLIC_AUTH0_DOMAIN`)

### Hardware Integration (Custom Libraries)
| Package | Version | Purpose |
|---------|---------|---------|
| `@mdlbeasts/acs-smc-sdk` | ^1.1.0 | Access control / SMC hardware SDK |
| `@mdlbeasts/expo-serial-usb` | ^1.1.0 | USB serial communication |
| `@mdlbeasts/react-native-honeywell-scanner` | ^1.1.9 | Honeywell barcode scanner hardware |
| `react-native-nfc-manager` | ^3.16.0 | NFC scanning |
| `react-native-background-timer-android` | ^1.0.4 | Background timer |

### UI
| Package | Version | Purpose |
|---------|---------|---------|
| `react-native-paper` | ^5.12.5 | Material Design components |
| `styled-components` | ^6.1.13 | CSS-in-JS |
| `lottie-react-native` | 7.1.0 | Animation |
| `react-native-reanimated` | ~3.16.1 | Animation library |
| `react-native-gesture-handler` | ~2.20.2 | Gesture handling |
| `react-native-svg` | 15.8.0 | SVG rendering |
| `react-native-screens` | ~4.4.0 | Screen optimization |
| `react-native-safe-area-context` | 4.12.0 | Safe area insets |
| `react-native-drawer-layout` | ^3.3.2 | Drawer navigation |
| `@expo/vector-icons` | ^14.0.2 | Icon set |
| `@react-native-clipboard/clipboard` | ^1.14.2 | Clipboard access |

### Networking & Utils
| Package | Version | Purpose |
|---------|---------|---------|
| `@react-native-community/netinfo` | 11.4.1 | Network status |
| `@react-native-community/hooks` | ^3.0.0 | Community hooks |
| `react-native-logs` | ^5.1.0 | Logging library |
| `jwt-decode` | ^4.0.0 | JWT token parsing |
| `lodash` | ^4.17.21 | Utility functions |
| `moment` | ^2.30.1 | Date manipulation |
| `moment-timezone` | ^0.5.45 | Timezone handling |
| `base-64` | ^1.0.0 | Base64 encoding |
| `p-limit` | ^6.1.0 | Concurrency control |
| `build-url-ts` | ^6.1.8 | URL builder |
| `email-validator` | ^2.0.4 | Email validation |
| `react-native-uuid` | ^2.0.2 | UUID generation |

### Error Tracking
- `@sentry/react-native` ~6.3.0

### Testing (Mobile Scanner)
| Package | Version | Purpose |
|---------|---------|---------|
| `jest` | ~29.7.0 | Test runner |
| `jest-expo` | ~52.0.6 | Expo Jest preset |
| `@testing-library/react-native` | ^12.7.2 | React Native Testing Library |
| `jest-styled-components` | ^7.2.0 | Styled-components snapshot testing |

### Build Tools (Mobile Scanner)
| Package | Version | Purpose |
|---------|---------|---------|
| `eslint` | ^8.57.0 | Linting |
| `eslint-config-expo` | ~8.0.1 | Expo ESLint config |
| `prettier` | ^3.3.3 | Code formatting |
| `@svgr/cli` | (via npx) | SVG to React Native component |
| `@babel/core` | ^7.20.0 | Babel compiler |

---

## Mobile Libraries (`ticketing-platform-mobile-libraries`)

### Structure
Yarn workspaces (yarn 3.8.0) with two published packages:

| Package | Version | Purpose |
|---------|---------|---------|
| `@mdlbeasts/acs-smc-sdk` | 1.1.0 | Native module wrapping ACS SMC access control hardware |
| `@mdlbeasts/expo-serial-usb` | 1.1.0 | Native module for USB serial port communication |

- Built with `expo-module-scripts` 3.5.2 (Expo Module API)
- Targets Android (iOS structure present but not actively built)
- Published to GitHub Packages (`npm`)
- Demo app in `apps/access-terminal-demo`

---

## Shared Client Library (`ticketing-platform-shared`)

- Package: `@mdlbeasts/ticketing-client` 1.0.21
- npm workspaces monorepo
- TypeScript, published to GitHub Packages
- Shared API client type library consumed by frontend apps

---

## Infrastructure: AWS CDK (`ticketing-platform-infrastructure`)

### CDK Stacks (shared infrastructure)
11 CloudFormation stacks:

| Stack | Key Resources |
|-------|--------------|
| EventBusStack | EventBridge bus `event-bus-{env}` |
| MonitoringStack | CloudWatch Log Group, EventBridge all-events rule, X-Ray Insights |
| ConsumersSqsStack | SQS queue + DLQ for 18 consumer services |
| ConsumerSubscriptionStack | EventBridge routing rules (events -> SQS) |
| ExtendedMessageS3BucketStack | S3 for large event payloads `ticketing-{env}-extended-message` |
| InternalHostedZoneStack | Route53 private hosted zone |
| InternalCertificateStack | ACM wildcard certificate |
| SlackNotificationStack | CloudWatch Logs -> Slack Lambda |
| XRayInsightNotificationStack | X-Ray insights -> Slack + DynamoDB dedup |
| ApiGatewayVpcEndpointStack | VPC endpoint for API Gateway |
| RdsProxyStack | RDS Proxy for Aurora PostgreSQL |

### Queue Visibility Timeouts
- Most services: 120s visibility timeout, 1 DLQ retry
- PdfGenerator: 900s (15m), 5 retries
- CsvGenerator: 300s (5m), 1 retry
- Sales: 300s (5m), 1 retry

### CDK Package Versions
- `Amazon.CDK.Lib` 2.233.0
- `Constructs` 10.4.4
- `Amazon.CDK.AWS.Scheduler.Alpha` 2.141.0-alpha.0

---

## Infrastructure: Terraform (`ticketing-platform-terraform-dev/prod`)

- **Version:** `>= 0.13.1`
- **Provider:** AWS (`me-south-1` region)
- **State:** S3 backend (`ticketing-terraform-dev` / `ticketing-terraform-prod`)
- **Resources managed:**
  - VPC, subnets, security groups, NAT gateway
  - Route53 hosted zones
  - ECR repositories (`ticketing-platform-ecr`, `helm-chart`)
  - S3 buckets (PDF tickets, CSV reports, terraform state)
  - CloudFront distributions
  - EventBridge
  - MSK subnets (Managed Streaming for Apache Kafka)
  - Management EC2 instance
  - OpenVPN
  - KMS encryption keys
  - WAF (Web Application Firewall)
  - IAM users, roles, policies
  - S3 lifecycle rules (Standard -> Standard-IA 30d -> Glacier 60d)

---

## Kubernetes / Helm (`ticketing-platform-configmap-*`)

Services running in Kubernetes (not Lambda):

| Service | K8s name | Notes |
|---------|---------|-------|
| gateway | `gateway` | YARP reverse proxy |
| catalogue | `catalogue` | |
| sales | `sales` | |
| inventory | `inventory` | |
| pricing | `pricing` | |
| integration | `integration` | |
| access-control | `access-control` | |
| media | `media` | |
| extensions | `extensions` | |
| reporting | `reporting` | |
| distribution-portal | `dp` | |
| transfer | `transfer` | |
| organizations | `organizations` | |

**Namespace:** `ticketing-{env}` (e.g. `ticketing-dev`)
**DNS pattern:** `http://{service}.ticketing-{env}.svc.cluster.local:5000`
**Secret management:** External Secrets Operator (`SecretStore` + `ExternalSecret`) syncing from AWS Secrets Manager
**Config delivery:** Kubernetes ConfigMaps per service per environment in `ticketing-platform-configmap-{env}/manifests/`
**Helm:** Per-service charts (e.g., `ticketing-platform-distribution-portal/helm/dp/values-{env}.yaml`)
**ECR:** Docker images pushed to `ticketing-platform-ecr`

---

## API Gateway (`ticketing-platform-gateway`)

- `Yarp.ReverseProxy` 2.3.0 -- YARP-based reverse proxy
- Deployed as Lambda (CDK) and/or K8s
- Routes requests to downstream services via internal Kubernetes DNS
- JWT auth validation: `Microsoft.AspNetCore.Authentication.JwtBearer` 8.0.22
- OpenAPI aggregation: `Microsoft.OpenApi` 1.6.28, `Microsoft.OpenApi.Readers` 1.6.28
- Dockerfile: multi-stage build from `mcr.microsoft.com/dotnet/aspnet:8.0`

---

## CI/CD

### GitHub Actions
- Per-service `.github/workflows/ci-cd.yml` triggered on push to `development`, `sandbox`, `demo`, `production`
- Reusable workflows from `mdlbeasts/ticketing-platform-templates-ci-cd` repository
- Standard pipeline stages (example from sales):
  1. Run tests (xUnit) -- on PRs to `development`
  2. Package Lambda(s): `dotnet lambda package`
  3. CDK deploy DB migrator stack
  4. Run migration Lambda (`aws lambda invoke`)
  5. Create CloudWatch Log Groups
  6. CDK deploy all service stacks
  7. BlazeMeter load tests (development branch only)

### NuGet Publishing (`ticketing-platform-tools`)
- Workflow: `ticketing-platform-tools/.github/workflows/nuget.yml`
- Triggers: push to `master` or `development`
- Version: auto-incremented using `github.run_number` (format `1.0.{N}`)
- Publishes to: `https://nuget.pkg.github.com/mdlbeasts/index.json`
- Authentication: `PAT_USERNAME` / `PAT_TOKEN` GitHub secrets

### Dashboard CI/CD
- `vercel-deploy.yml` -- Deploy to Vercel (dev, sandbox, production)
- `unit-tests.yml` -- Jest unit tests on PRs to development (Node.js 20.x)
- `tests.yml` -- Cypress E2E tests
- `linter.yml` -- ESLint
- `chromatic.yml` -- Chromatic visual regression testing (on PRs to development)
- `storybook-deploy.yml` -- Storybook deployment
- `create-release.yml` -- Release management
- `pr-title-checker.yml` -- PR title format validation
- `dependabot.yml` -- Daily npm and weekly GitHub Actions updates

### Mobile Scanner Deployment
- Platform: **Expo EAS** (Expo Application Services)
- EAS CLI version: `>= 4.1.2`
- Profiles: `debugging`, `testing`, `development`, `sandbox`, `production`
- OTA updates: `eas update --branch {env} --non-interactive --auto`
- Local builds: `eas build --local --platform android --profile {env}`

---

## Observability

| Tool | Used In | Purpose |
|------|---------|---------|
| AWS X-Ray | All Lambda services | Distributed tracing |
| Lumigo | PDF generator, CSV generator, others | Lambda performance monitoring |
| Sentry | Dashboard (`@sentry/nextjs` ^9.22.0), mobile scanner (`@sentry/react-native` ~6.3.0) | Frontend error tracking |
| Serilog | All .NET services | Structured logging -> CloudWatch |
| Slack | Infrastructure repo | Error and alarm notifications |
| CloudWatch Logs | All Lambda services | Log aggregation |
| Elasticsearch | K8s services (Catalogue, Sales, Gateway) | Log indexing |
| BlazeMeter | Sales (dev branch CI) | Load testing |
| Chromatic | Dashboard Storybook | Visual regression testing |

---

## Payments & Commerce Integrations

| Integration | Package/Method | Used In | Notes |
|------------|---------------|---------|-------|
| Checkout.com | `CheckoutSDK` 4.17.0 | `ticketing-platform-sales` | Card payments |
| Apple Pay | Certificate-based (`.pfx` files) | `ticketing-platform-sales` | `sandbox.pfx` / `prod.pfx` |
| Tabby (BNPL) | HTTP/REST (no SDK) | `ticketing-platform-sales` | Buy Now Pay Later, KSA market |
| Geidea | Custom Lambda service | `ticketing-platform-geidea` | Local payment provider |
| TalonOne (Loyalty/Promo) | `TalonOne` 8.0.0 SDK | `ticketing-platform-loyalty`, `ticketing-platform-pricing` | Promotions and campaign engine |
| Seatsio (Venue Maps) | `SeatsioDotNet` 107.3.0 | sales, catalogue, access-control, inventory | Venue seating charts |

---

## Auth: Auth0

- All services validate Auth0 JWTs
- Auth0 domains:
  - dev: `auth.dev.admin.tickets.mdlbeast.net`
  - sandbox: `auth.sandbox.admin.tickets.mdlbeast.net`
  - prod: `auth.admin.tickets.mdlbeast.net`
- Dashboard: `@auth0/auth0-react` 2.3.0
- Distribution portal frontend: `@auth0/auth0-react` 2.2.4
- Mobile scanner: `react-native-auth0` ^3.2.1
- Backend: `Microsoft.AspNetCore.Authentication.JwtBearer` 8.0.22

---

## Design System: Hue

- Location: `ticketing-platform-dashboard/src/hue/`
- Custom design system with dedicated linting (`npm run lint:hue`)
- Icons: `src/hue/assets/icons/svgs/` -> generated via `@svgr/cli`
- Storybook integration: `@storybook/nextjs` ^8.6.14
- Visual regression: Chromatic (scoped to `src/hue/**/*.stories.@(js|jsx|ts|tsx|mdx)`)
- Storybook config: `ticketing-platform-dashboard/.storybook/` (main.ts, preview.ts, preview-head.html)

---

## Environment Branches

| Branch | Environment | AWS Credentials |
|--------|-------------|----------------|
| `development` | `dev` | `AWS_ACCESS_KEY_ID` |
| `sandbox` | `sandbox` | `AWS_ACCESS_KEY_ID` |
| `demo` | `demo` | `AWS_ACCESS_KEY_ID_DEMO` |
| `production` | `prod` | `AWS_ACCESS_KEY_ID_PROD` |

Secrets path: `/{env}/{service}` (AWS Secrets Manager)
Parameter path: `/{env}/tp/{resource}/{param}` (AWS SSM Parameter Store)

---

## Testing: .NET Services

| Package | Version | Purpose |
|---------|---------|---------|
| `xunit` | 2.9.3 | Test framework |
| `xunit.runner.visualstudio` | 3.1.5 | VS test runner integration |
| `Microsoft.NET.Test.Sdk` | 18.0.1 | Test platform |
| `Moq` | 4.20.72 | Mocking |
| `NSubstitute` | 5.3.0 | Mocking (alternative to Moq) |
| `Autofac.Extras.Moq` | 7.0.0 | Autofac + Moq integration |
| `Microsoft.AspNetCore.Mvc.Testing` | 8.0.10 | Integration test web factory |
| `Polly.Testing` | 8.6.5 | Polly policy testing helpers |
| `coverlet.collector` | 6.0.4 | Code coverage |
| `NUnit` | latest | Used in some services (media unit tests) |
| `Amazon.Lambda.TestUtilities` | latest | Lambda context mock for infrastructure tests |

Run command: `dotnet test`
Filter: `dotnet test --filter "FullyQualifiedName~{TestName}"`

---

## Code Style Enforcement

### .NET Services
- **Analyzer:** StyleCop.Analyzers 1.2.0-beta.556
- **Config:** `.editorconfig` in each service root
- `TreatWarningsAsErrors=true` -- build fails on any warning
- `EnforceCodeStyleInBuild=true`
- `CheckForOverflowUnderflow=true`
- Block-scoped namespaces required
- `var` preferred for all types
- 4-space indentation, LF line endings
- `Nullable=disable` (most services)
- PascalCase for types/members, `I` prefix for interfaces
- Using directives outside namespace, system usings sorted first
- Braces required (`csharp_prefer_braces = true:warning`)

### TypeScript/React
- **Linter:** ESLint 8.x with `eslint-config-next` and custom plugins
- **Formatter:** Prettier 3.5.3 (dashboard) / 3.3.3 (mobile scanner)
- **Prettier settings:** printWidth 80, semi true, singleQuote false, tabWidth 2, trailingComma "es5"
- Notable ESLint plugins:
  - `eslint-plugin-deprecation` -- flag deprecated API usage
  - `eslint-plugin-import` -- import ordering (alphabetical, groups: builtin, external, internal, parent, sibling, index)
  - `eslint-plugin-no-secrets` -- prevent secrets in code
  - `eslint-plugin-styled-components-varname` -- styled-component naming (suffix: "Styled")
  - `eslint-plugin-mui-path-imports` -- enforce tree-shakeable MUI imports
  - `eslint-plugin-etc` -- no-commented-out-code
  - `eslint-plugin-moment-timezone` -- enforce moment-timezone usage
- Key ESLint rules: no-console (error), no-magic-numbers, import/order, quotes: double
- TypeScript strict mode enabled (dashboard)

---

## Service Count Reference

| Category | Services |
|----------|---------|
| .NET Lambda (business domain) | access-control, catalogue, sales, inventory, reporting-api, media, pricing, transfer, loyalty, marketplace-service, organizations, geidea, csv-generator, integration (14) |
| .NET Lambda (extension system) | extension-api, extension-executor, extension-deployer, extension-log-processor (4) |
| .NET Lambda (pdf) | pdf-generator (1) |
| .NET K8s (containerized) | distribution-portal API (1) |
| .NET CDK (infra only) | infrastructure, gateway (2) |
| .NET Shared Libraries | tools (1 repo, ~12 NuGet packages) |
| Next.js Frontend | dashboard, distribution-portal-frontend (2) |
| React Native | mobile-scanner (1) |
| Native Modules | mobile-libraries (1 repo, 2 packages) |
| Shared TS Client | shared (1) |
| Config | configmap-dev, configmap-sandbox, configmap-prod (3) |
| Terraform | terraform-dev, terraform-prod (2) |
| Scripts | work-smart-scripts (1) |
| **Total repositories** | ~33 |

---

*Stack analysis: 2026-03-04*
