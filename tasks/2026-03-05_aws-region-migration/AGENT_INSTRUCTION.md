# Migration Agent Instruction

You are executing the AWS region migration plan for the MDLBEAST Ticketing Platform (me-south-1 → eu-central-1).

## Required Reading

**Before doing anything, read these files:**

1. `.personal/tasks/2026-03-05_aws-region-migration/plan.md` — the migration plan with all technical details
2. `.personal/tasks/2026-03-05_aws-region-migration/execution.md` — the execution log tracking progress
3. **For Phase 5 (dev+sandbox) steps:** `.personal/tasks/2026-03-05_aws-region-migration/plan-phase-5.md` — the detailed Phase 5 plan with full CLI commands, lessons from production, and branching strategy. `plan.md` Phase 5 section is a summary that points here.

When reading `execution.md`, pay special attention to:
- The **Deviations Log** table — it summarizes every place where execution has diverged from the plan. Read this before executing your step so you understand how the current state may differ from what `plan.md` assumes.
- The **Shared Outputs Registry** — it holds values (endpoints, IDs, ARNs) produced by earlier steps that your step may need.

**For Phase 5 specifically:** The detailed plan incorporates 22 lessons learned from the production migration (Phases 2-4). Each lesson is mapped to the step that addresses it. Read the "Lessons Incorporated" table to understand what pitfalls to avoid.

## Your Job

1. Find the first step in `execution.md` with status `PENDING` — that is your next task.
2. Set its status to `IN_PROGRESS` and record the current timestamp.
3. Read the corresponding section for detailed instructions:
   - **Phases 1-4:** Read the matching section in `plan.md`.
   - **Phase 5 (P5-S1 through P5-S13):** Read the matching section in `.personal/tasks/2026-03-05_aws-region-migration/plan-phase-5.md`.
   - Cross-reference against the Deviations Log — if a prior deviation affects your step, adapt accordingly.
4. Execute the step. For steps that require AWS CLI or infrastructure commands, present the commands and ask me to confirm before running them. For code-only steps (file edits), proceed directly.
5. **After completing file changes, do NOT commit automatically.** Instead:
   - Present a summary of all affected repos and the changes made.
   - Propose the commit message. **Always suffix the commit message with the step ID in parentheses**, e.g. `chore: update test files region from me-south-1 to eu-central-1 (P1-T7)`.
   - **Wait for explicit approval** before running `git add` / `git commit` in any repo.
   - Only after approval, commit to all affected repos using the approved message.
   - **Do NOT add `Co-Authored-By` trailers** or any other trailers to commit messages.
6. After completing the step, update `execution.md`:
   - Set status to `DONE` (or `FAILED`/`SKIPPED` with reason) and record the completion timestamp.
   - Check off substep boxes.
   - **Record which repos were affected** in a `**Repos (N):**` field on the step.
   - Fill in any outputs in both the step's Outputs section and the Shared Outputs Registry table at the top.
   - **If you deviated from the plan in any way** (different command, extra step, skipped substep, different resource name, workaround for an error, etc.), record it in the step's **Deviations** field using this format:
     ```
     **DEVIATION:** <what changed vs. the plan>
     **Reason:** <why — error encountered, missing resource, plan inaccuracy, etc.>
     **Actions taken:** <exactly what was done instead>
     **Downstream impact:** <which future steps/phases are affected and how, or "None" if self-contained>
     ```
     Then add a summary row to the **Deviations Log** table near the top of `execution.md`.
7. If a step fails, record what happened in Notes, set status to `FAILED`, and do not skip ahead — stop and await my input.
8. After updating `execution.md`, **stop and await my confirmation** before moving to the next step.

## Important Context

**Reference files:**
- Secrets reconstruction: `secrets-reconstruction.md`, `ssm-reconstruction.md`
- Diagnostics from production migration: `diagnostics.md` (DIAG-001 through DIAG-005 — lessons already baked into Phase 5 plan)

**AWS accounts and profiles:**
- Prod account: `660748123249`, profile: `AdministratorAccess-660748123249`
- Dev/sandbox account: `307824719505`, profile: `AdministratorAccess-307824719505`

**Backup directories:**
- Prod secrets: `backup-secrets/`, SSM: `backup-ssm/`
- Dev secrets: `backup-secrets-dev/`, SSM: `backup-ssm-dev/`
- Sandbox secrets: `backup-secrets-sandbox/`, SSM: `backup-ssm-sandbox/`
- IAM policy backups from prod: `backup-iam-policies/`
- **Backups are last resort.** For Phase 5, prefer live replication from me-south-1 over backup files.

**Branching rules:**
- **Phases 1-4 (production):** All code changes on `hotfix/region-migration-eu-central-1`. Only `ticketing-platform-tools` merges to master before Phase 3 (for NuGet publish).
- **Phase 5 (dev+sandbox):** Code changes already exist on `production`/`master` (merged in Phase 4). For each repo with CDK:
  - **Sandbox:** Pull latest `origin/sandbox` (or `origin/release/sandbox`) first, then create `hotfix/sandbox-eu-migration` from it, merge `production`/`master` into it, create PR to `sandbox` (don't merge yet), do manual CDK deployment, then user merges PR.
  - **Dev:** Pull latest `origin/development` (or `origin/release/development`) first, then create `hotfix/dev-eu-migration` from it, merge `sandbox` into it, create PR to `development` (don't merge yet), do manual CDK deployment, then user merges PR.
  - Some repos may use `release/sandbox` or `release/development` instead — check branch names before creating hotfix branches.

**CI/CD standard deployment sequence** (for reference when doing manual deployments):
1. Clean publish directories: `find . -path "*/bin/Release/net8.0/publish" -type d -exec rm -rf {} +`
2. `dotnet restore && dotnet build --no-restore`
3. `dotnet lambda package -c Release` from each Lambda project directory (**NOT** `dotnet publish` — see DIAG-001/002)
4. `cdk synth`
5. `cdk import` (for IAM roles — required on first deploy, see lesson #5 in Phase 5 plan)
6. `cdk deploy TP-{Stack}-{env} --require-approval never`

**Critical Phase 5 reminders** (most common production failures):
- Always use `dotnet lambda package`, never `dotnet publish` for class library projects (DIAG-001/002)
- Pre-create ALL log groups before CDK deploy: serverless + consumers + background-jobs (lesson #8)
- extension-deployer: Docker image Lambda, deploy via `dotnet lambda deploy-function --docker-build-options "--platform linux/amd64"` (DIAG-003)
- pdf-generator: Clean CDK DLLs + non-linux runtimes from publish dir after packaging (lesson #9)
- media: Import `imgix-*` IAM user in addition to roles (lesson #14)
- SSM subnet params: Store suffix-only values, not full IDs (lesson #4)
