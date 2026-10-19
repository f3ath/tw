# TW

Run these commands from the repository root with Make, Dart, Flutter, and Docker
installed:

```sh
make db-start      # Start PostgreSQL and wait until healthy
make test          # Run all tests
make analyze       # Run dart analyze in all packages
make format        # Format all packages
make format-check  # Check formatting without changing files
make db-stop       # Stop and remove the database containers
```

Use `-app`, `-shared`, or `-server` to select a package, for example
`make test-app`, `make analyze-shared`, or `make format-check-server`.
The shared test target skips testing until a `shared/test` directory exists.

Server tests require the database. Its storage uses tmpfs, so stopping it discards
its data. See [server setup](server/README.md) for credentials and initialization.

Run `make help` for the target list. Override executables if needed, for example
`make analyze DART=/path/to/dart`.
