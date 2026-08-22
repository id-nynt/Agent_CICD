# Scenario Simulation

Phase 2 provides data-driven CI/CD scenarios for the BDI CI/CD research prototype.

The runner uses the Phase 1 action scripts for stages marked `passed` and records scenario-controlled outcomes for stages marked `failed` or `not_run`. It does not implement real telemetry, Jason reasoning, Prometheus, OpenTelemetry, Kubernetes, GitHub API integration, or ML.

## Run One Scenario

```sh
./simulation/scenario_runner.sh simulation/scenarios/success_stable.yml
```

## Run All Scenarios

```sh
./simulation/scenario_runner.sh --all
```

On Windows PowerShell, use Git Bash if plain `bash` points to WSL:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' simulation/scenario_runner.sh --all
```

## Outputs

Each run writes a JSON event log to:

```text
simulation/event_log/
```

Each log records:

- Scenario name.
- Candidate version.
- Executed or simulated actions.
- Simulated telemetry.
- Context flags.
- Expected traditional decision.
- Expected BDI decision.
- Final simulated decision.
- Final production version.
- Success flag.

These logs are intended as input for later telemetry-to-belief mapping and BDI reasoning phases.

## Error Mechanism

The scenario error mechanism is documented in:

```text
simulation/error_mechanism.md
```
