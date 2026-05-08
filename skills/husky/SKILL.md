---
name: husky
description: >
  Husky git hooks setup for NestJS/Node projects — pre-commit lint-staged on staged files, pre-push build and test suite.
  Trigger: When adding husky, git hooks, pre-commit, pre-push, lint-staged, or commit hooks to a project.
license: Apache-2.0
metadata:
  author: sisques-labs
  version: "1.0"
---

## When to Use
- When setting up git hooks for a new project
- When adding pre-commit linting or pre-push validation
- When asked about husky, lint-staged, or commit hooks

## Critical Patterns
- **pre-commit** → `pnpm lint-staged` — only staged files, never the full codebase
- **pre-push** → `pnpm build && pnpm test` — full validation before remote push
- `lint-staged` config lives in `package.json` under `"lint-staged"` key: `{ "**/*.ts": "eslint --fix" }`
- `prepare` script must be `"husky"` so hooks install automatically on `pnpm install`
- Install: `pnpm add -D husky lint-staged` then `pnpm exec husky init`
- After `husky init`, replace the generated `pre-commit` content — it defaults to `pnpm test`, which is wrong
- Never run full build+test in pre-commit — it kills DX. Reserve heavy checks for pre-push
- NestJS v10: `HttpStatus.LOCKED` doesn't exist — use numeric `423` directly

## Setup Commands
```bash
pnpm add -D husky lint-staged
pnpm exec husky init
```

## File Structure
```
.husky/
├── pre-commit    # pnpm lint-staged
└── pre-push      # pnpm build && pnpm test
```

## Code Examples

**.husky/pre-commit**
```sh
pnpm lint-staged
```

**.husky/pre-push**
```sh
pnpm build && pnpm test
```

**package.json additions**
```json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "**/*.ts": "eslint --fix"
  },
  "devDependencies": {
    "husky": "^9.0.0",
    "lint-staged": "^15.0.0"
  }
}
```

## Resources
- **Husky docs**: https://typicode.github.io/husky/
- **lint-staged docs**: https://github.com/lint-staged/lint-staged
