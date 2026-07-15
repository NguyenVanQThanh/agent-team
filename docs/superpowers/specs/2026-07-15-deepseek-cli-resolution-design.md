# DeepSeek CLI Resolution Design

## Goal

Allow the DeepSeek teammates (dev3, dev4, and dev10) to run on either the
renamed `codewhale` CLI or the legacy `deepseek-tui` CLI, always preferring
`codewhale` when both are installed.

## Scope

- Keep the orchestration CLI label `deepseek` and the `run_deepseek.sh` wrapper
  unchanged so existing task specifications continue to work.
- Let a user explicitly override automatic detection with `DEEPSEEK_BIN`.
- When no override is set, resolve `codewhale` first and `deepseek-tui` second.
- Fail before an agent run begins when neither binary is available, with an
  actionable error message.
- Make `team-doctor.sh` report and probe the same resolved executable, and
  display the matching authentication guidance.

## Resolution Contract

1. If `DEEPSEEK_BIN` is non-empty, use it as the command specification.
2. Otherwise, use `codewhale` if it is on `PATH`.
3. Otherwise, use `deepseek-tui` if it is on `PATH`.
4. Otherwise, return exit code 127 and explain that the user should install
   `codewhale` or `deepseek-tui`, or set `DEEPSEEK_BIN`.

The shared runner will continue to validate the first word of the resolved
command before it launches the agent. The execution metadata will identify the
actual command selected so run logs remain diagnosable.

## Design

`env.sh` defines and exports `DEEPSEEK_BIN` only when the user has not already
provided one. Its default is empty, which requests automatic resolution rather
than choosing a hard-coded command.

`run_deepseek.sh` owns resolution in a small shell function. This confines the
renamed-CLI compatibility rule to the DeepSeek wrapper and passes the resolved
binary specification into `runner_exec`.

`team-doctor.sh` uses the same selection rule via a sourceable helper so its
presence check, version display, live probe, and login hint cannot disagree
with the runner. The report labels the selected implementation as CodeWhale or
DeepSeek TUI where it can determine the name.

## Testing

Add a shell regression test that supplies temporary `PATH` directories with
stub commands. It verifies `codewhale` wins when both stubs exist,
`deepseek-tui` is used when it is the only stub, `DEEPSEEK_BIN` overrides the
automatic order, and an absent CLI emits the documented error and exits 127.

Run the targeted test and syntax-check all modified shell scripts with
`bash -n`.

## Non-goals

- Renaming task specs, team personas, or the public orchestration label from
  `deepseek` to `codewhale`.
- Changing DeepSeek credentials or the invocation flags beyond selecting the
  command to execute.
