# AGENTS.md

## Scope

This file applies to the `server` package.

## Project

- Dart package: `server`
- Source: `lib/src`
- Entrypoint: `bin/server.dart`
- Tests: `test`

## Commands

- Format: `dart format .`
- Analyze: `dart analyze`
- Test: `dart test`

## Style

- Follow `analysis_options.yaml`.
- Prefer primary constructors and declaring parameters.
- Use ALL_CAPS for SQL keywords.
- Always write SQL as multiline text blocks.
- Split SQL across lines by clause: verb, tables, `WHERE`, and `RETURNING`.
- Keep changes small and local to the requested behavior.
- Do not rewrite unrelated dirty files.
- Follow TDD principles: write a failing test, implement the feature, and refactor.
