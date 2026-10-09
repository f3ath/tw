# AGENTS.md

## Scope

This file applies to the `server` package.

## Project

- Dart package: `tw_server`
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
- Keep changes small and local to the requested behavior.
- Do not rewrite unrelated dirty files.
- Follow TDD principles: write a failing test, implement the feature, and refactor.
