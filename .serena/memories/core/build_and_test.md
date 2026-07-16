# Build and Test

This repository uses shell-based smoke tests and does not have a compiled
application build.

Run the focused hybrid configuration check from the repository root:

```bash
"$BASH" tests/test_serena_hybrid_config.sh
```

Run the existing memory and Serena integration checks as well:

```bash
"$BASH" tests/test_memory_tools.sh
```

On Windows, use Git Bash when WSL does not provide a distribution. Do not read
or print forbidden `.env*` files while diagnosing setup failures.
