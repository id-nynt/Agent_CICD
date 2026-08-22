# First BDI CI/CD Agent

Phase 4 adds a first Jason/AgentSpeak model for CI/CD release reasoning.

Files:

```text
bdi/cicd_agent.asl
bdi/project.mas2j
bdi/run_agent_for_scenario.sh
```

Generate beliefs first:

```sh
./telemetry/belief_mapper.sh
```

Prepare and run one scenario:

```sh
./bdi/run_agent_for_scenario.sh success_stable
```

By default, the runner prints a deterministic BDI reasoning trace from the generated beliefs. This keeps the prototype easy to demonstrate while still producing Jason files.

To also try the installed Jason CLI:

```sh
./bdi/run_agent_for_scenario.sh success_stable --jason
```

The runner creates scenario-specific files under:

```text
bdi/generated/
```

You can run the generated `.mas2j` file manually in a Jason environment if needed.

Expected decisions are documented in:

```text
docs/bdi_goal_model.md
```
