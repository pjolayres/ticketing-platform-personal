# Pull Requests — Sandbox Environment

Branch pattern: `hotfix/sandbox-eu-migration` → `sandbox`

> Merge in the order listed below. Wait for each group's CI/CD to complete before merging the next group.
> PRs within the same group can be merged in parallel unless noted otherwise.

---

## Group 1 — Merge FIRST (sequentially, one at a time)

| #   | Repo                                 | PR              | URL                                                                     | Notes                                                                              |
| --- | ------------------------------------ | --------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| 1   | `ticketing-platform-tools`           | N/A             | —                                                                       | Already merged to `master` in P1-T19 (v1.0.1300). No sandbox/dev PR needed.        |
| 2   | `ticketing-platform-infrastructure`  | #324            | https://github.com/mdlbeasts/ticketing-platform-infrastructure/pull/324 | Wait for CI/CD to complete before merging next.                                    |
| 3   | `ticketing-platform-templates-ci-cd` | **NOT CREATED** | —                                                                       | Needs PR: `hotfix/region-migration-eu-central-1` → `master`. No CI/CD auto-deploy. |

## Group 2 — Merge SECOND (Terraform)

| #   | Repo                               | PR              | URL | Notes                                                                                                           |
| --- | ---------------------------------- | --------------- | --- | --------------------------------------------------------------------------------------------------------------- |
| 4   | `ticketing-platform-terraform-dev` | **NOT CREATED** | —   | Needs PR: `hotfix/region-migration-eu-central-1` → `master`. No CI/CD auto-deploy (Terraform applied manually). |

## Group 3 — Merge in PARALLEL (backend services, Tier 1)

| #   | Repo                                         | PR        | URL                                                                              | Notes                                          |
| --- | -------------------------------------------- | --------- | -------------------------------------------------------------------------------- | ---------------------------------------------- |
| 5   | `ticketing-platform-catalogue`               | #895      | https://github.com/mdlbeasts/ticketing-platform-catalogue/pull/895               |                                                |
| 6   | `ticketing-platform-organizations`           | **NO PR** | —                                                                                | No diff between sandbox and production — skip. |
| 7   | `ticketing-platform-loyalty`                 | #151      | https://github.com/mdlbeasts/ticketing-platform-loyalty/pull/151                 |                                                |
| 8   | `ticketing-platform-csv-generator`           | #144      | https://github.com/mdlbeasts/ticketing-platform-csv-generator/pull/144           |                                                |
| 9   | `ticketing-platform-pdf-generator`           | **NO PR** | —                                                                                | No diff between sandbox and production — skip. |
| 10  | `ticketing-platform-automations`             | #41       | https://github.com/mdlbeasts/ticketing-platform-automations/pull/41              |                                                |
| 11  | `ticketing-platform-extension-api`           | #345      | https://github.com/mdlbeasts/ticketing-platform-extension-api/pull/345           |                                                |
| 12  | `ticketing-platform-extension-deployer`      | #165      | https://github.com/mdlbeasts/ticketing-platform-extension-deployer/pull/165      |                                                |
| 13  | `ticketing-platform-extension-executor`      | #147      | https://github.com/mdlbeasts/ticketing-platform-extension-executor/pull/147      |                                                |
| 14  | `ticketing-platform-extension-log-processor` | #107      | https://github.com/mdlbeasts/ticketing-platform-extension-log-processor/pull/107 |                                                |
| 15  | `ticketing-platform-customer-service`        | #157      | https://github.com/mdlbeasts/ticketing-platform-customer-service/pull/157        |                                                |

## Group 4 — Merge in PARALLEL (backend services, Tier 2)

Wait for Group 3 CI/CD to finish before merging.

| #   | Repo                                     | PR    | URL                                                                          | Notes |
| --- | ---------------------------------------- | ----- | ---------------------------------------------------------------------------- | ----- |
| 16  | `ticketing-platform-inventory`           | #1060 | https://github.com/mdlbeasts/ticketing-platform-inventory/pull/1060          |       |
| 17  | `ticketing-platform-pricing`             | #641  | https://github.com/mdlbeasts/ticketing-platform-pricing/pull/641             |       |
| 18  | `ticketing-platform-media`               | #772  | https://github.com/mdlbeasts/ticketing-platform-media/pull/772               |       |
| 19  | `ticketing-platform-reporting-api`       | #214  | https://github.com/mdlbeasts/ticketing-platform-reporting-api/pull/214       |       |
| 20  | `ticketing-platform-marketplace-service` | #100  | https://github.com/mdlbeasts/ticketing-platform-marketplace-service/pull/100 |       |
| 21  | `ticketing-platform-integration`         | #600  | https://github.com/mdlbeasts/ticketing-platform-integration/pull/600         |       |
| 22  | `ticketing-platform-distribution-portal` | #254  | https://github.com/mdlbeasts/ticketing-platform-distribution-portal/pull/254 |       |

## Group 5 — Merge in PARALLEL (backend services, Tier 3)

| #   | Repo                                | PR    | URL                                                                      | Notes |
| --- | ----------------------------------- | ----- | ------------------------------------------------------------------------ | ----- |
| 23  | `ticketing-platform-sales`          | #2205 | https://github.com/mdlbeasts/ticketing-platform-sales/pull/2205          |       |
| 24  | `ticketing-platform-access-control` | #1910 | https://github.com/mdlbeasts/ticketing-platform-access-control/pull/1910 |       |
| 25  | `ticketing-platform-transfer`       | #318  | https://github.com/mdlbeasts/ticketing-platform-transfer/pull/318        |       |
| 26  | `ticketing-platform-geidea`         | #81   | https://github.com/mdlbeasts/ticketing-platform-geidea/pull/81           |       |
| 27  | `ecwid-integration`                 | #173  | https://github.com/mdlbeasts/ecwid-integration/pull/173                  |       |

## Group 6 — Merge LAST (gateway + frontends)

| #   | Repo                                              | PR              | URL                                                              | Notes                                                                                   |
| --- | ------------------------------------------------- | --------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| 28  | `ticketing-platform-gateway`                      | #868            | https://github.com/mdlbeasts/ticketing-platform-gateway/pull/868 | Must be after all backend services.                                                     |
| 29  | `ticketing-platform-dashboard`                    | **NOT CREATED** | —                                                                | Needs PR: `hotfix/sandbox-eu-migration` → `sandbox`. Merge triggers Vercel deploy.      |
| 30  | `ticketing-platform-distribution-portal-frontend` | **NOT CREATED** | —                                                                | Needs PR if sandbox branch exists. Vercel deploy.                                       |
| 31  | `ticketing-platform-mobile-scanner`               | **NOT CREATED** | —                                                                | Needs PR: `hotfix/sandbox-eu-migration` → `sandbox`. Trigger release build after merge. |

## Merge Anytime (no CDK, no deployment order dependency)

| Repo                                   | PR              | URL | Notes                                                                                   |
| -------------------------------------- | --------------- | --- | --------------------------------------------------------------------------------------- |
| `ticketing-platform-configmap-dev`     | **NOT CREATED** | —   | Archival (EKS deprecated). Needs PR: `hotfix/region-migration-eu-central-1` → `master`. |
| `ticketing-platform-configmap-sandbox` | **NOT CREATED** | —   | Archival. Needs PR: `hotfix/region-migration-eu-central-1` → `master`.                  |
| `ticketing-platform-configmap-prod`    | **NOT CREATED** | —   | Archival. Needs PR: `hotfix/region-migration-eu-central-1` → `master` (or `disaster`).  |

---

## Summary

- **Existing PRs:** 22 (all `hotfix/sandbox-eu-migration` → `sandbox`)
- **Missing PRs (need creation):** 7 (templates-ci-cd, terraform-dev, dashboard, distribution-portal-frontend, mobile-scanner, 3x configmaps)
- **Skipped (no diff):** 2 (organizations, pdf-generator)
- **Already merged:** 1 (tools — merged to master in Phase 1)
