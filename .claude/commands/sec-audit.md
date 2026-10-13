---
description: Full security audit. Assesses target scope, selects and coordinates security specialists, synthesizes findings into a final report with coverage matrix. Argument: module path or component name.
---

# Security Audit

Full security audit for a module, component, or feature. Assesses the target's actual characteristics, selects only the relevant specialists, coordinates their analysis, and produces a final report with findings ranked by severity and a coverage matrix.

## When to use

- Before shipping a security-sensitive feature
- When auditing an unfamiliar module before significant changes
- When investigating a suspected vulnerability with unknown scope
- When a targeted `@security` review needs broader coverage

For a quick targeted check: `@security` directly.
For a pre-commit check that includes security: `/pre-commit-review`.
For one specific dimension: invoke the specialist directly (`@security-auth`, `@security-injection`, etc.).

## Step 1 — Assess the target

Read entry points, data flows, and trust boundaries for the stated scope. Answer:
- What data enters the target? (HTTP params, files, job payloads, messages, env)
- What sensitive operations happen? (DB queries, file writes, external calls, auth checks)
- What auth model is used? (session, JWT, API key, none)
- Is this multi-tenant?
- What is the target's exposure? (public internet, authenticated users, internal only)

## Step 2 — Select specialists

Invoke only the agents that correspond to what you found:

| Condition | Agent |
|-----------|-------|
| Login, registration, password reset, sessions, tokens | `@security-auth` |
| Authorization checks on resources or operations | `@security-auth` |
| SQL/NoSQL queries with user-controlled input | `@security-injection` |
| User values used in commands, templates, file paths, redirects | `@security-injection` |
| HTTP API endpoints, CORS, CSRF protection, response data | `@security-web` |
| File upload, download, or storage operations | `@security-data` |
| Cryptographic operations, secrets in code, sensitive data in logs | `@security-data` |
| Multi-step flows, financial operations, state machines | `@security-logic` |
| Package dependencies with security history | `@security-deps` |

Provide each specialist with the specific path and the aspect you need them to focus on. Run independent specialists in parallel when their scopes do not overlap.

## Step 3 — Compound analysis

After specialists complete:
- Identify compound attack chains: can two or more findings be combined for greater impact?
- Ask `@security-logic` specifically to assess chain potential if multiple findings exist across specialists
- Identify surfaces the specialists did not evaluate (may be N/A or may need a follow-up)

## Step 4 — Final report

**Summary** (3–5 sentences): overall risk level, most critical finding, recommended priority action.

**Findings** (ordered by severity):

| # | Vulnerability | Specialist | File:Line | CWE | Severity | Status | Fix |
|---|--------------|-----------|-----------|-----|----------|--------|-----|

Status values:
- `CONFIRMED` — code path directly traced
- `PROBABLE` — evidence supports risk, one verification step incomplete
- `POTENTIAL` — suspicious pattern, requires further investigation
- `NOT REPRODUCED` — attempted validation, not confirmed
- `NOT VERIFIABLE` — insufficient access or information

**Compound attack vectors** (if applicable):

| Chain | Findings involved | Combined severity | Conditions |
|-------|------------------|------------------|------------|

**Coverage matrix**:

| Surface | Agent | Coverage | Notes |
|---------|-------|---------|-------|
| Authentication | @security-auth | Evaluated / Findings / Partial / N/A / Not evaluated | |
| Authorization / IDOR | @security-auth | | |
| SQL / NoSQL injection | @security-injection | | |
| Command / template injection | @security-injection | | |
| XSS / output encoding | @security-injection | | |
| SSRF / path traversal | @security-injection | | |
| CSRF / CORS / CSP | @security-web | | |
| API response exposure | @security-web | | |
| Rate limiting | @security-web | | |
| File upload/download | @security-data | | |
| Secrets / cryptography | @security-data | | |
| Data in logs/errors | @security-data | | |
| Business logic | @security-logic | | |
| Race conditions | @security-logic | | |
| Dependencies | @security-deps | | |

**Residual risk**: surfaces not evaluated, findings that could not be fully verified, conditions that require dynamic testing.

## What not to do

- Do not invoke all specialists for every target — select based on actual characteristics
- Do not declare a surface secure because no findings were found — report what was examined and by what method
- Do not merge distinct root causes into one finding
- Do not run dynamic tests against production systems without explicit authorization
- Do not report CVE-based dep findings without noting that live verification requires external tooling
