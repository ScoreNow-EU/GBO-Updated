# Claude Code Instructions

## General behavior

- Do not read large files unless absolutely necessary.
- Do not inspect generated files, build outputs, lockfiles, or dependencies unless explicitly asked.
- Search first, then open only the relevant files or snippets.
- Before making changes, explain the likely cause of the issue.
- Prefer small, targeted changes over large rewrites.
- Do not refactor unrelated code.
- Do not rename files, functions, variables, or classes unless necessary.
- Do not change formatting-only unless asked.
- Do not introduce new dependencies without asking first.
- Keep answers concise and practical.

## Token discipline

- Avoid loading the entire repository into context.
- Avoid reading full files when a targeted search is enough.
- Ignore these unless explicitly needed:
  - node_modules
  - dist
  - build
  - .next
  - coverage
  - vendor
  - generated files
  - lockfiles
  - large JSON files
  - minified files

## Debugging workflow

When investigating a bug:

1. Search for the relevant symbols, routes, components, or error messages.
2. Identify the smallest set of files involved.
3. Read only the relevant sections.
4. Explain the suspected cause.
5. Propose a minimal fix.
6. Apply the fix only after the cause is clear.
7. Run the smallest relevant test or check.

## Coding style

- Match the existing code style.
- Prefer readable, boring code over clever code.
- Keep functions small where reasonable.
- Do not over-engineer.
- Avoid abstractions unless they remove real duplication.
- Use descriptive names.
- Add comments only when the code is not self-explanatory.

## Safety rules

- Never modify environment files, secrets, credentials, or production config without asking.
- Never delete files without asking.
- Never run destructive commands without asking.
- Never run database migrations against production.
- Never install packages globally.
- Ask before changing public APIs, database schemas, auth logic, payment logic, or deployment config.

## Git behavior

- Do not commit unless explicitly asked.
- Do not push unless explicitly asked.
- Do not rewrite git history.
- Before editing, check what files are already modified.
- Do not overwrite user changes.

## Testing

- Run the smallest relevant test first.
- If tests fail, explain whether the failure seems related to the change.
- Do not spend time fixing unrelated failing tests unless asked.
- If no tests exist, suggest a minimal manual verification step.

## Communication

- Start with the conclusion.
- Mention which files you inspected.
- Mention which files you changed.
- Explain why the change is minimal.
- Do not give huge summaries unless asked.