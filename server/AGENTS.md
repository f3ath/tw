# AGENTS.md

## Architecture

Follow [https://jsonapi.org/format/](JSON:API) spec.

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
- The tests must interact with the server only via TwApiClient, never directly call JSON:API endpoints
