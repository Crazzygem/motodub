# AGENTS.md — how to work in this repository

> This file defines **how you operate**: the workflow loop every task runs through,
> and the rules you never break. It intentionally contains **no project details**.
> Project facts (identity, accounts, commands, environment) → **PROJECT.md**
> What we build & in what order → **PLAN.md** · contracts → **ARCHITECTURE.md**
> The task list you execute → **IMPLEMENTATION.md**

## 1. Your role

- You execute IMPLEMENTATION.md tasks **one at a time, strictly in order**.
- You do not decide *what* to build — the spec does. You decide *how* to build a task well.
- You are accountable for proof: nothing is "done" until its verification output exists.
- ⏸ **CHECKPOINT** tasks end with a human handoff: do the code part, then STOP and
  report to Seth the exact manual step he must do and what he should see.

## 2. The development workflow loop (run for EVERY task)

Nine stages, in order. Each stage's **gate** must pass before you enter the next.
Never skip a stage, even for "small" tasks — small tasks are where shortcuts hide.

### 1. Orientation
Read the task. Read the spec sections it references (ARCHITECTURE.md / PROJECT.md).
Identify the exact files that will change.
**Gate:** you can state in one sentence: the objective, the files, and the expected
verification output. If you cannot → the task is ambiguous → STOP and ask.

### 2. High-Level Planning
Write down the approach: files to create/modify, new dependencies, order of work,
risks. Check it against the locked decisions and the out-of-scope list.
**Gate:** the approach violates nothing in the spec, and it is written down (short)
before code starts.

### 3. Drafting & Implementation
Write the code. Write tests first where the task specifies behavior (TDD). Match
existing style. Touch only files the task names.
**Gate:** implementation exists, compiles, and a previously-failing test now passes
(where TDD applies).

### 4. Static Verification
Run the static checks (`flutter analyze` for app, `node --check` + lint for server).
Review your own diff (`git diff`): dead code, orphaned files, secrets, unrelated edits.
**Gate:** static checks clean; the diff contains only task-scoped changes.

### 5. Dynamic Execution & Testing
Run the task's Verify commands — the real ones — and capture real output. A green
test suite, a curl JSON body, a DB row: verbatim output is the only acceptable proof.
**Gate:** the task's expected output is observed, verbatim.

### 6. Observation & Logging
Record the evidence: output snapshots, DB rows created, ports, timestamps, any
deviation from the task's steps. This is the material your report is built from.
**Gate:** evidence exists for every Verify bullet in the task.

### 7. Deep Validation
Adversarial pass. What breaks this in a demo? Exercise at least one failure path the
task implies (busy driver, wrong role, invalid input, server unreachable) and re-run
the full suite. Happy-path green is not enough.
**Gate:** ≥1 failure path exercised, full suite still green, no regressions.

### 8. Reflection & Self-Critique
Answer honestly: did I add anything unrequested (YAGNI)? Violate a rule or a locked
decision? Leave dead code or orphans? Is the commit message right? What do I do
better next task? Honesty includes admitting "yes, I did X".
**Gate:** each critique question answered in the report.

### 9. Handoff & Human Gatekeeping
Commit with the task's prescribed message (one commit per task).
- ⏸ CHECKPOINT → STOP here. Report what Seth must do and what he should observe.
- Regular task → report, then proceed to the next task (unless Seth is present and
  wants to review first).
**Gate:** commit exists, working tree clean, handoff delivered.

## 3. Standing rules (apply to every loop, no exceptions)

1. **Commit locally only.** Never `git push` or open remote branches unless Seth explicitly says so.
2. **Evidence over claims.** Never fabricate or assume output. If a Verify command cannot run, that is a BLOCKED report — not a pass.
3. **Clean tree.** No scratch files in the repo (`.pi-*`, `agent-*`, `tmp/`, throwaways). Scratch lives in the OS temp dir.
4. **Spec files are read-only for you.** Never edit PLAN.md / ARCHITECTURE.md / IMPLEMENTATION.md / PROJECT.md unless a task instructs it or Seth says so. If a task contradicts a spec file, the task is the one that's wrong — report it.
5. **YAGNI.** Implement exactly the task. Suspect a wrong or missing task? STOP and ask Seth — never improvise a fix.
6. **Secrets never touch git.** `.env`, `google-services.json`, keys: gitignored, never committed, never printed, never echoed into logs or reports.
7. **Style consistency.** Match existing code style; one concern per commit; commit prefixes `feat:` / `fix:` / `test:` / `chore:` / `docs:`.

## 4. Reporting format (every task)

```
Task <id> — <status>
Evidence: <trimmed verbatim output of each Verify command>
Deviations: <any step done differently, and why>
Self-critique: <the §2.8 answers>
Next: <next task id>, or "⏸ waiting on Seth for: <manual step>"
```

## 5. Definitions

- **Done** = stages 4–7 gates passed + commit + handoff (CHECKPOINT) or next-task (regular).
- **Blocked** = something cannot be verified, the spec is ambiguous, or a rule conflicts with the task. Report blocked immediately — never work around it silently.
- **⏸ CHECKPOINT** = a human-gatekeeping point. Your job ends at the gate; Seth's begins.