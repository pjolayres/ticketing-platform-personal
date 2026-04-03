# Pull Requests — Dev Environment

Branch pattern: `hotfix/dev-eu-migration` → `development`

> Merge in the order listed below. Wait for each group's CI/CD to complete before merging the next group.
> PRs within the same group can be merged in parallel unless noted otherwise.

---

## Group 1 — Merge FIRST (sequentially, one at a time)

| #   | Repo                                 | PR              | URL                                                                     | Notes                                                                              |
| --- | ------------------------------------ | --------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| 1   | `ticketing-platform-tools`           | N/A             | —                                                                       | Already merged to `master` in P1-T19 (v1.0.1300). No dev PR needed.                |
| 2   | `ticketing-platform-infrastructure`  | #325            | https://github.com/mdlbeasts/ticketing-platform-infrastructure/pull/325 | Wait for CI/CD to complete before merging next.                                    |
| 3   | `ticketing-platform-templates-ci-cd` | **NOT CREATED** | —                                                                       | Needs PR: `hotfix/region-migration-eu-central-1` → `master`. No CI/CD auto-deploy. |

## Group 2 — Merge SECOND (Terraform)

| #   | Repo                               | PR              | URL | Notes                                                                                                           |
| --- | ---------------------------------- | --------------- | --- | --------------------------------------------------------------------------------------------------------------- |
| 4   | `ticketing-platform-terraform-dev` | **NOT CREATED** | —   | Needs PR: `hotfix/region-migration-eu-central-1` → `master`. No CI/CD auto-deploy (Terraform applied manually). |

## Group 3 — Merge in PARALLEL (backend services, Tier 1)

| #   | Repo                                         | PR    | URL                                                                              | Notes |
| --- | -------------------------------------------- | ----- | -------------------------------------------------------------------------------- | ----- |
| 5   | `ticketing-platform-catalogue`               | #896  | https://github.com/mdlbeasts/ticketing-platform-catalogue/pull/896               |       |
| 6   | `ticketing-platform-organizations`           | #1090 | https://github.com/mdlbeasts/ticketing-platform-organizations/pull/1090          |       |
| 7   | `ticketing-platform-loyalty`                 | #152  | https://github.com/mdlbeasts/ticketing-platform-loyalty/pull/152                 |       |
| 8   | `ticketing-platform-csv-generator`           | #145  | https://github.com/mdlbeasts/ticketing-platform-csv-generator/pull/145           |       |
| 9   | `ticketing-platform-pdf-generator`           | #213  | https://github.com/mdlbeasts/ticketing-platform-pdf-generator/pull/213           |       |
| 10  | `ticketing-platform-automations`             | #42   | https://github.com/mdlbeasts/ticketing-platform-automations/pull/42              |       |
| 11  | `ticketing-platform-extension-api`           | #346  | https://github.com/mdlbeasts/ticketing-platform-extension-api/pull/346           |       |
| 12  | `ticketing-platform-extension-deployer`      | #166  | https://github.com/mdlbeasts/ticketing-platform-extension-deployer/pull/166      |       |
| 13  | `ticketing-platform-extension-executor`      | #148  | https://github.com/mdlbeasts/ticketing-platform-extension-executor/pull/148      |       |
| 14  | `ticketing-platform-extension-log-processor` | #108  | https://github.com/mdlbeasts/ticketing-platform-extension-log-processor/pull/108 |       |
| 15  | `ticketing-platform-customer-service`        | #158  | https://github.com/mdlbeasts/ticketing-platform-customer-service/pull/158        |       |

## Group 4 — Merge in PARALLEL (backend services, Tier 2)

Wait for Group 3 CI/CD to finish before merging.

| #   | Repo                                     | PR    | URL                                                                          | Notes |
| --- | ---------------------------------------- | ----- | ---------------------------------------------------------------------------- | ----- |
| 16  | `ticketing-platform-inventory`           | #1061 | https://github.com/mdlbeasts/ticketing-platform-inventory/pull/1061          |       |
| 17  | `ticketing-platform-pricing`             | #642  | https://github.com/mdlbeasts/ticketing-platform-pricing/pull/642             |       |
| 18  | `ticketing-platform-media`               | #773  | https://github.com/mdlbeasts/ticketing-platform-media/pull/773               |       |
| 19  | `ticketing-platform-reporting-api`       | #215  | https://github.com/mdlbeasts/ticketing-platform-reporting-api/pull/215       |       |
| 20  | `ticketing-platform-marketplace-service` | #101  | https://github.com/mdlbeasts/ticketing-platform-marketplace-service/pull/101 |       |
| 21  | `ticketing-platform-integration`         | #601  | https://github.com/mdlbeasts/ticketing-platform-integration/pull/601         |       |
| 22  | `ticketing-platform-distribution-portal` | #255  | https://github.com/mdlbeasts/ticketing-platform-distribution-portal/pull/255 |       |

## Group 5 — Merge in PARALLEL (backend services, Tier 3)

| #   | Repo                                | PR    | URL                                                                      | Notes |
| --- | ----------------------------------- | ----- | ------------------------------------------------------------------------ | ----- |
| 23  | `ticketing-platform-sales`          | #2206 | https://github.com/mdlbeasts/ticketing-platform-sales/pull/2206          |       |
| 24  | `ticketing-platform-access-control` | #1911 | https://github.com/mdlbeasts/ticketing-platform-access-control/pull/1911 |       |
| 25  | `ticketing-platform-transfer`       | #319  | https://github.com/mdlbeasts/ticketing-platform-transfer/pull/319        |       |
| 26  | `ticketing-platform-geidea`         | #82   | https://github.com/mdlbeasts/ticketing-platform-geidea/pull/82           |       |
| 27  | `ecwid-integration`                 | #174  | https://github.com/mdlbeasts/ecwid-integration/pull/174                  |       |

## Group 6 — Merge LAST (gateway + frontends)

| #   | Repo                                              | PR              | URL                                                              | Notes                                                                                   |
| --- | ------------------------------------------------- | --------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| 28  | `ticketing-platform-gateway`                      | #869            | https://github.com/mdlbeasts/ticketing-platform-gateway/pull/869 | Must be after all backend services.                                                     |
| 29  | `ticketing-platform-dashboard`                    | **NOT CREATED** | —                                                                | Needs PR: `hotfix/dev-eu-migration` → `development`. Merge triggers Vercel deploy.      |
| 30  | `ticketing-platform-distribution-portal-frontend` | **NOT CREATED** | —                                                                | Needs PR if development branch exists. Vercel deploy.                                   |
| 31  | `ticketing-platform-mobile-scanner`               | **NOT CREATED** | —                                                                | Needs PR: `hotfix/dev-eu-migration` → `development`. Trigger release build after merge. |

## Merge Anytime (no CDK, no deployment order dependency)

| Repo                                   | PR              | URL | Notes                                                                                   |
| -------------------------------------- | --------------- | --- | --------------------------------------------------------------------------------------- |
| `ticketing-platform-configmap-dev`     | **NOT CREATED** | —   | Archival (EKS deprecated). Needs PR: `hotfix/region-migration-eu-central-1` → `master`. |
| `ticketing-platform-configmap-sandbox` | **NOT CREATED** | —   | Archival. Needs PR: `hotfix/region-migration-eu-central-1` → `master`.                  |
| `ticketing-platform-configmap-prod`    | **NOT CREATED** | —   | Archival. Needs PR: `hotfix/region-migration-eu-central-1` → `master` (or `disaster`).  |

---

## Summary

- **Existing PRs:** 24 (all `hotfix/dev-eu-migration` → `development`)
- **Missing PRs (need creation):** 7 (templates-ci-cd, terraform-dev, dashboard, distribution-portal-frontend, mobile-scanner, 3x configmaps)
- **Already merged:** 1 (tools — merged to master in Phase 1)

## Also Open (deprecated services — Phase 1 production PRs)

These are `hotfix/region-migration-eu-central-1` → `master` PRs from Phase 1. Excluded from migration but PRs remain open:

| Repo                                         | PR  | URL                                                                             |
| -------------------------------------------- | --- | ------------------------------------------------------------------------------- |
| `ticketing-platform-xp-badges`               | #4  | https://github.com/mdlbeasts/ticketing-platform-xp-badges/pull/4                |
| `ticketing-platform-marketing-feeds`         | #26 | https://github.com/mdlbeasts/ticketing-platform-marketing-feeds/pull/26         |
| `ticketing-platform-bandsintown-integration` | #12 | https://github.com/mdlbeasts/ticketing-platform-bandsintown-integration/pull/12 |
