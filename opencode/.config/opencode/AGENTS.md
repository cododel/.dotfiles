# Core Development Standards

## 1. Zen & Naming

- **Semantic naming:** Booleans as questions (`isReady`), functions as verbs (`processData`).
- **Readability:** Code must be self-documenting.
- **Immutability:** Prefer `const`, avoid side effects.
- **Native First:** Minimize dependencies.

## 2. Type Safety & Validation

- **Strict Typing:** Avoid dynamic types and unsafe type assertions/casting where strict typing is available. Do not suppress type checker errors.
- **Boundary Safety:** Enforce strict validation at data boundaries (API, DAL, I/O) to ensure runtime safety.
- **Type Integrity:** Correctly extend or define missing external types; never bypass the type system to fix library issues.

## 3. Workflow & Terminal

- **Safety:** No absolute paths, no `../` navigation outside workspace.
- **Manual Control:** No auto-running of dev/build/git commands.
- **Search:** Prefer `rg` (ripgrep) for fast, exhaustive search that respects .gitignore.
- **File Finding:** Prefer `fd` (if installed) for safe defaults. If using standard `find`, ALWAYS explicitly exclude `node_modules` and `.git`.
- **Destructive Safety:** NEVER use `find . -delete` or generic `rm -rf` blindly. ALWAYS list files (`ls` or `find -print`) before deletion commands to verify targets.

## 4. Git Convention

- **Format:** `<type>(<scope>): <subject>`
- **Subject:** Lowercase, imperative, no period.
- **Staged only:** Commits must reflect only actual staged changes.

## 5. Debugging & Refactoring

- **Root Cause:** Explain "why" it broke before fixing.
- **Exhaustive Updates:** Check the entire codebase for side effects when renaming or migrating.
- **Atomic Changes:** Large tasks must be broken down.

## 6. Testing Strategy

- **Context-Aware:** Adapt testing levels (Unit vs E2E vs Integration) to the specific stack and project phase.
- **Critical Paths:** Core business logic must be verified regardless of architecture.
- **Stability:** Tests must be deterministic (flaky tests are forbidden).

## 7. Tools & MCP

- **Schema First:** Define rigid input/output schemas (e.g., JSON Schema) for all tools to prevent hallucinated parameters.
- **Structured Errors:** Tools must return actionable, structured error messages, never raw stack traces or empty failures.
- **Least Privilege:** Grant agents access only to the specific scopes and resources required for the task.
- **Idempotency:** Design write-operations to be safe for retries where possible, or strictly explicitly confirmable.
