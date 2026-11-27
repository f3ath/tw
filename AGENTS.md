# AGENTS.md

These instructions apply throughout the repository.

## Clarification and scope

- If any requirement or expected behavior is ambiguous, stop and ask the user for clarification before proceeding.
- Test and implement only what is necessary for the requested behavior.

## Test-first development

- Tests are mandatory for core domain logic. However, keep the tests precisely focused, make sure tests are not fragile. Avoid asserting implementation details.
- If a new test requires changing the existing testing harness or exposure of implementation details, stop and confirm with the user.
- Make sure each test actually fails before implementing the logic, compilation failure counts. 
- Run 2-3 refactoring cycles after the tests are green.

## Readability and duplication

- Use `package:` imports in Dart where possible.
- Optimize for human readability. Keep classes and functions small, preferably under 50 lines each.
- If a class or function you are changing would exceed 80 lines, stop and propose a refactoring. Wait for the user's decision before proceeding. Exceed the limit only with the user's explicit approval.
- Refactor aggressively. Keep each piece of domain logic in one place. Refactor supporting logic, including tests and helpers, when the same logic occurs in three or more places.
