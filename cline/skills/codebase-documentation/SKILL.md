---
name: codebase-documentation
description: Create, update, repair, or review documentation for an existing codebase. Use when asked to document code, update docs after code changes, create or improve README files, architecture docs, onboarding guides, API docs, module docs, configuration docs, docstrings, or JSDoc.
---

# Codebase Documentation

Create and maintain documentation that accurately reflects the current repository.

## Core principles

- Read the implementation before documenting it.
- Treat the current codebase as the source of truth.
- Update existing documentation instead of creating duplicates when practical.
- Never invent APIs, commands, environment variables, architecture, or behavior.
- Explain important behavior, architecture, contracts, constraints, and rationale.
- Avoid simply translating obvious code into prose.
- Do not modify application behavior during documentation-only work.

## Workflow

1. Inspect project instructions and existing documentation.
2. Inspect the code relevant to the documentation request.
3. Search for existing documentation covering the same area.
4. Identify stale, missing, inaccurate, or duplicated information.
5. Update the canonical documentation location.
6. Verify documented commands, paths, APIs, configuration, and examples.
7. Review the final documentation diff for accuracy and unnecessary duplication.

## Project discovery

Check relevant files when present:

- AGENTS.md
- .clinerules
- .clinerules/
- .cline/rules/
- README.md
- CONTRIBUTING.md
- docs/
- module README files
- package/build manifests
- CI configuration
- tests

Never assume project commands or architecture without repository evidence.

## README documentation

Use README files primarily for:

- project purpose
- quick start
- installation
- common commands
- basic configuration
- links to deeper documentation

Keep the root README concise.

## Architecture documentation

Document supported facts such as:

- entry points
- major components
- dependencies
- data flow
- external services
- storage
- configuration
- architectural boundaries

Do not invent design rationale.

If rationale cannot be established from the repository, describe the implementation without pretending to know why it was designed that way.

## API documentation

Verify API documentation against implementation, schemas, tests, or generated specifications.

Where applicable document:

- interface or endpoint
- inputs
- required and optional parameters
- authentication
- response behavior
- errors
- side effects
- examples

Never invent response fields or behavior.

## Development and setup documentation

Discover actual commands from files such as:

- package.json
- pyproject.toml
- Cargo.toml
- go.mod
- Makefile
- justfile
- Docker files
- CI workflows
- scripts

Do not guess whether the project uses npm, pnpm, bun, yarn, uv, pip, pytest, make, or another tool.

When practical, execute safe documented commands to verify them.

Never claim a command was verified unless it was actually run successfully.

## Environment variables

Document environment variables only when they are actually referenced by the repository.

Never put real credentials or secrets into documentation.

Use placeholders such as:

SUPABASE_URL=<your-project-url>
SUPABASE_ANON_KEY=<your-anon-key>

## Documentation after code changes

When invoked after a feature, fix, refactor, API change, or configuration change:

1. Inspect the final code diff.
2. Determine what externally meaningful behavior changed.
3. Search existing documentation for references to that behavior.
4. Update impacted documentation.
5. Remove obsolete information.
6. Ensure examples reflect the final implementation.

Do not create documentation churn for purely internal changes.

## Documentation drift

Check for:

- commands that no longer exist
- renamed files or directories
- outdated configuration
- removed APIs
- stale examples
- outdated setup steps
- inaccurate architecture descriptions
- broken or outdated documentation links
- conflicting instructions
- deprecated interfaces

Fix high-confidence drift when the user requested documentation updates.

## Comments and docstrings

Use docstrings or JSDoc for public or non-obvious contracts.

Document:

- purpose
- important inputs
- return behavior
- meaningful errors
- side effects
- constraints

Use inline comments primarily to explain WHY something exists.

Avoid comments that merely restate the code.

## Keep documentation DRY

Prefer one canonical explanation and link to it from elsewhere.

Avoid maintaining multiple copies of:

- setup instructions
- architectural explanations
- API behavior
- configuration reference

## Verification

Before finishing:

- reread all changed documentation
- verify referenced paths
- verify command names
- verify API and configuration names against code
- check for secrets
- inspect the final diff

Run documentation linting, link checking, or builds when the repository already provides them.

## Interaction with feature implementation

If feature implementation is also being performed:

- inspect the final implementation first
- document only behavior that actually exists
- do not document planned but unfinished behavior
- update only documentation materially affected by the change

## Completion

Report:

- documentation created or updated
- important files changed
- obsolete documentation removed
- validation actually performed
- meaningful unresolved documentation gaps

Never claim documentation is fully accurate unless the relevant implementation was inspected.
