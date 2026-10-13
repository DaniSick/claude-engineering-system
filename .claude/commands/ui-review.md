---
description: Structured UI/UX engineering workflow. Inspect the existing interface, identify real problems, implement improvements, validate. Argument: component path or page name.
---

# UI Review

Structured UI/UX workflow: inspect, identify real problems, implement, validate. For pages, components, forms, and dashboards.

## When to use

- Redesigning or improving a page, form, dashboard, or visual component
- Fixing hierarchy, density, clarity, responsiveness, or accessibility issues
- Pre-shipping visual QA on a complex or recently changed screen
- Refactoring a component when visual consistency is part of the goal

Skip this skill for exclusively backend tasks. For a targeted one-component fix, a localized inspection and edit is faster than the full workflow.

## Steps

### 1. Inspect

Read the component/page files, templates, stylesheets, and design tokens for the stated scope. Identify:
- The technology and styling conventions actually used (Tailwind, CSS Modules, styled-components, etc.)
- Existing reusable components, tokens, and utilities in the project
- The current visual system: color roles, spacing scale, typography scale, component variants

Do not assume framework behavior — read the actual implementations.

### 2. Evaluate screen and action hierarchy

Before identifying defects, establish what the screen must accomplish. This determines which defects matter and which are acceptable trade-offs.

**User goal and information priority**
- What is the user's primary task on this screen? What must complete successfully for the visit to succeed?
- What information must be immediately visible to begin the task?
- What is secondary — supportive but not required at first glance?
- What is noise — always visible but rarely or never needed, or needed only in exceptional cases?

**Action hierarchy**
- Identify the primary action (what the user does most or must do to complete the goal)
- Identify secondary actions (supporting operations, lower frequency or lower stakes)
- Identify destructive or exceptional actions (delete, cancel, reset, irreversible operations)
- Determine which actions belong to the same operation and should be spatially grouped
- Determine whether actions at the same visual level actually have the same functional weight

Decide this from the screen's context — functional relationship, frequency, risk, and reversibility. Not every set of buttons needs grouping; not every destructive action needs a modal. Avoid adding visual separation or grouping without a functional reason.

**Relevant states**
Which states apply to this screen: initial/empty, loading, success, error, partial selection, confirmation prompt? Each must be visually distinguishable and give the user enough information to act. Identify which states are missing or indistinguishable.

Use findings from this evaluation to focus step 3 (Identify problems) and step 4 (Implement).

### 3. Identify problems (evidence required)

Evaluate by category. A finding requires evidence (file:line); "it doesn't look right" is not a finding.

**Visual hierarchy**
- Is the primary action or information immediately clear?
- Do multiple elements compete for attention at the same level?
- Is emphasis consistent with importance?

**Information clarity**
- Are labels specific and brief, or vague and long?
- Is any data repeated without a functional reason?
- Are there instructions the interface already makes obvious?

**Color and states**
- Are semantic colors (success, error, warning) consistent across the interface?
- Does text meet contrast requirements against its background?
- Are interactive states (hover, focus, selected, disabled, error) present and distinguishable?

**Spacing and composition**
- Does the spacing follow a consistent scale?
- Do alignment and grouping reflect functional relationships?
- Is the density appropriate for the product and content type?

**Accessibility**
- Do interactive elements have accessible labels?
- Is keyboard navigation functional and focus visible?
- Are error messages specific and actionable?

**Responsive behavior**
- Does the layout work at relevant breakpoints without overflow or cut content?
- Are interactive targets usable on touch screens?

Prioritize findings by: frequency of use × impact on task completion × effort to fix. Do not rewrite a full screen when a localized change solves the problem.

### 4. Implement

- Make changes in the actual component files using the project's conventions
- Reuse existing tokens, utilities, and components — do not introduce a new design system
- Keep visual changes separate from logic changes in the diff
- Do not add decorative elements (gradients, shadows, animations) without a functional purpose
- Preserve all existing functionality: permissions, validation, contracts, data flows

### 5. Validate

- Run the relevant tests (unit, component, a11y if available)
- Run lint and typecheck if the project has them
- Inspect the diff for changes outside the stated scope
- Verify at mobile and desktop breakpoints if the change affects layout
- If visual testing tools exist in the project, use them

Report what was inspected, what was found, what changed, what was validated, and what limitations remain (e.g., "visual result not confirmed — no browser available, compilation passed").

## Effort by scope

| Scope | Approach |
|-------|---------|
| Single component fix | Localized read; skip steps 2–3 if hierarchy is not in question; targeted change; run affected tests |
| Screen refactor | Full steps 1–5: hierarchy evaluation, action priority, states, related components, full validation |
| Cross-cutting redesign | Deeper analysis only when multiple screens or shared components are affected; consider @reviewer on the diff |

In `ferb` mode: short final report (verdict, findings, action). Full implementation and validation still apply; step 2 evaluation is always required before modifying a screen.

## What not to do

- Do not claim to have visually verified a page if you only read its source — state the limitation
- Do not redesign components outside the stated scope
- Do not introduce a new visual language if the project already has one
- Do not add colors, shadows, or motion effects without a concrete function
- Do not report style preferences as usability bugs
- Do not skip validation to save tokens
