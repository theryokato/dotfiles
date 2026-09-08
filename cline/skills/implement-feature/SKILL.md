---
name: implement-feature
description: Implement new functionality end-to-end while following the existing codebase architecture and conventions. Use when asked to add, implement, build, integrate, extend, or ship a feature, component, endpoint, widget, capability, or integration. Prefer the smallest complete solution, avoid speculative abstractions, and verify the finished implementation.
---

# Feature Implementation

Implement the requested feature as a careful senior engineer would: understand the existing system first, make the smallest complete change, preserve existing behavior, and verify the result.

## Core Principles

- Read before editing.
- Reuse existing code and patterns before creating new ones.
- Make the smallest change that fully satisfies the request.
- Avoid unrelated refactors.
- Avoid speculative abstractions, configuration, wrappers, factories, and extension points.
- Do not sacrifice correctness, security, error handling, accessibility, or data integrity for fewer lines of code.
- Preserve backward compatibility unless the requested feature explicitly changes behavior.
- Never invent project commands, APIs, file locations, or architecture.
- Do not commit, push, publish, or deploy unless the user explicitly requests it.

## 1. Understand the Request

Determine the concrete behavior being requested:

- What should change?
- Where should the behavior appear?
- What existing behavior must remain intact?
- What edge cases are implied by the request?

Do not block implementation over minor details that can safely follow existing project conventions.

Ask a concise clarification only when a missing decision would materially change the architecture, data model, security model, or externally visible behavior.

## 2. Discover the Project

Before modifying code, inspect the relevant project structure and instructions.

Check applicable files when present:

- `AGENTS.md`
- `.clinerules`
- `.clinerules/`
- `.cline/rules/`
- project README/documentation
- package/build manifests
- nearby implementation files
- existing tests

Discover the project's actual commands rather than assuming them.

Examples of files that may reveal commands:

- `package.json`
- `pyproject.toml`
- `Cargo.toml`
- `go.mod`
- `Makefile`
- `justfile`
- build scripts
- CI configuration

Identify the real commands for any applicable:

- tests
- linting
- formatting
- type checking
- building

Never assume npm, bun, pnpm, yarn, pytest, make, or another tool is used without evidence from the project.

## 3. Trace Existing Behavior

Before implementing:

1. Find the entry point for the affected behavior.
2. Trace the relevant flow end-to-end.
3. Search for similar features or components already implemented.
4. Identify shared utilities, styles, types, APIs, and conventions that can be reused.
5. Check callers and consumers that could regress.

Prefer extending an established pattern over introducing a new one.

## 4. Decide the Smallest Correct Design

For every new file, abstraction, dependency, or configuration option, ask:

- Is this required by the current feature?
- Does something equivalent already exist?
- Can the change live cleanly in an existing abstraction?
- Is the new abstraction actually used by multiple concrete cases?

Avoid:

- interfaces with one implementation
- factories for one product
- wrappers that only forward calls
- premature plugin systems
- configuration for hypothetical future requirements
- broad rewrites when a localized change is sufficient

Do not interpret "minimal" as permission to skip validation, error handling, security, accessibility, or important edge cases.

## 5. Respect Cline Plan and Act Modes

Use the current Cline mode correctly.

### In Plan Mode

Cline Plan Mode is for investigation and planning.

- Inspect the repository.
- Trace the relevant architecture.
- Identify affected files and dependencies.
- Determine implementation and verification steps.
- Present a concise implementation plan.
- Do not attempt file edits or command execution that Plan Mode does not permit.
- Do not pretend to switch modes through a tool.

### In Act Mode

Implement the feature.

For straightforward features, proceed directly after sufficient discovery.

For complex features, establish a short implementation plan internally before editing, then execute it unless a genuinely load-bearing requirement is ambiguous.

If the implementation reveals an assumption was wrong, re-read the relevant code and adjust rather than forcing the original approach.

## 6. Use Research Selectively

Use web or documentation research when it materially improves correctness, especially for:

- unfamiliar APIs
- version-sensitive libraries
- security-sensitive integrations
- platform-specific behavior
- deprecated or recently changed APIs

Do not research generic programming concepts unnecessarily.

Prefer authoritative documentation and the versions actually used by the repository.

## 7. Use Subagents Only When They Help

If the current Cline environment exposes subagent or delegation capabilities, use them only when the feature contains genuinely independent workstreams.

Good examples:

- independent frontend and backend investigation
- isolated research into an unfamiliar dependency
- independent verification/review

Do not create subagents merely because the capability exists.

Do not hard-code provider-specific model names.

For ordinary features, work sequentially in the current task.

## 8. Implement

While editing:

- Follow existing naming and formatting conventions.
- Keep changes scoped to the feature.
- Reuse existing utilities and dependencies.
- Avoid duplicating logic.
- Handle realistic failure states.
- Maintain type safety where applicable.
- Keep public interfaces as small as practical.
- Add comments only when they explain non-obvious reasoning.
- Do not leave temporary logging, debugging code, dead code, or commented-out experiments.

When UI is involved:

- Match the project's existing visual language.
- Preserve keyboard and accessibility behavior.
- Handle loading, empty, error, and disabled states when applicable.
- Avoid unnecessary visual redesign outside the requested feature.

## 9. Test the Change

Add or update tests when the project has relevant test infrastructure and the behavior warrants coverage.

Prefer testing externally meaningful behavior rather than implementation details.

Include important:

- happy path
- relevant edge cases
- failure behavior
- regression cases exposed by the change

Do not create an entirely new testing framework just for a small feature unless explicitly requested.

## 10. Verify

Before declaring the feature complete, run the applicable commands discovered from the repository.

Examples include:

- tests
- lint
- formatter/check
- type checker
- build

If a verification command fails because of your changes, investigate and fix the cause.

If a command cannot be run because of an environmental or pre-existing problem, distinguish that clearly from a failure introduced by the feature.

Never claim a test, build, lint check, or command passed unless it was actually run successfully.

## 11. Review the Final Diff

Before finishing, inspect the complete diff.

Check for:

- unintended changes
- regressions
- duplicated logic
- unnecessary complexity
- debug artifacts
- incorrect assumptions
- missing edge cases
- inconsistent naming or formatting
- security/privacy issues
- accidentally modified generated files
- unrelated cleanup

Simplify the implementation if the same behavior can be achieved cleanly with less machinery.

## Completion

Finish with a concise summary containing:

- what was implemented
- important files or components changed
- verification actually performed
- any known limitation that materially matters

Do not fabricate counts, test results, or verification.

Do not suggest unrelated follow-up work simply to expand the scope.
