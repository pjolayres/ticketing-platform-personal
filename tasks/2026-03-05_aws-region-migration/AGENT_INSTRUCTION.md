# Migration Agent Instruction

You are executing the AWS region migration plan for the MDLBEAST Ticketing Platform (me-south-1 → eu-central-1).

**Before doing anything, read these two files in full:**

1. `.personal/tasks/2026-03-05_aws-region-migration/plan.md` — the migration plan with all technical details
2. `.personal/tasks/2026-03-05_aws-region-migration/execution.md` — the execution log tracking progress

When reading `execution.md`, pay special attention to:
- The **Deviations Log** table — it summarizes every place where execution has diverged from the plan. Read this before executing your step so you understand how the current state may differ from what `plan.md` assumes.
- The **Shared Outputs Registry** — it holds values (endpoints, IDs, ARNs) produced by earlier steps that your step may need.

**Your job:**

1. Find the first step in `execution.md` with status `PENDING` — that is your next task.
2. Set its status to `IN_PROGRESS` and record the current timestamp.
3. Read the corresponding section of `plan.md` for the detailed instructions, commands, and context for that step. Cross-reference against the Deviations Log — if a prior deviation affects your step, adapt accordingly.
4. Execute the step. For steps that require AWS CLI or infrastructure commands, present the commands and ask me to confirm before running them. For code-only steps (file edits, git operations), proceed directly.
5. After completing the step, update `execution.md`:
   - Set status to `DONE` (or `FAILED`/`SKIPPED` with reason) and record the completion timestamp.
   - Check off substep boxes.
   - Fill in any outputs in both the step's Outputs section and the Shared Outputs Registry table at the top.
   - **If you deviated from the plan in any way** (different command, extra step, skipped substep, different resource name, workaround for an error, etc.), record it in the step's **Deviations** field using this format:
     ```
     **DEVIATION:** <what changed vs. the plan>
     **Reason:** <why — error encountered, missing resource, plan inaccuracy, etc.>
     **Actions taken:** <exactly what was done instead>
     **Downstream impact:** <which future steps/phases are affected and how, or "None" if self-contained>
     ```
     Then add a summary row to the **Deviations Log** table near the top of `execution.md`.
6. If a step fails, record what happened in Notes, set status to `FAILED`, and do not skip ahead — stop and await my input.
7. After updating `execution.md`, **stop and await my confirmation** before moving to the next step.

**Important context:**
- Reference files for secrets reconstruction: `secrets-reconstruction.md`, `ssm-reconstruction.md`
- Secret backups are in `backup-secrets/`, SSM backups in `backup-ssm/`
- Prod AWS account: `660748123249`, profile: `AdministratorAccess-660748123249`
- Dev/sandbox AWS account: `307824719505`, profile: `AdministratorAccess-307824719505`
- All code changes go on branch `hotfix/region-migration-eu-central-1`
- Only `ticketing-platform-tools` merges to master before Phase 3 (for NuGet publish)
