# production_high_error_rate

Capability: React to business-endpoint failures that pass /health by rolling back from telemetry.

Result: PASS

Success criteria: Jason rolls back only after telemetry creates production instability.

## Expected Beliefs

```text
metric(production,error_rate,high): True
environment(production,unstable): True
recovery_reason(telemetry_unstable): True
decision(rollback_production): True
status(rollback(production),passed): True
```

## Agent Mind

```text
Agent mind capture skipped by suite automation. Use 'jason agent mind deployment_agent' while the MAS is running for live belief inspection.
```

## Environment Log Tail

```text
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script]  Container prometheus  Creating
[CicdEnvironment][script]  Container prometheus  Created
[CicdEnvironment][script]  Container prometheus  Starting
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script]  Container prometheus  Started
[CicdEnvironment][script] [deploy] PASS: deployed candidate to staging using payment-staging
[CicdEnvironment] exit_code=0 script=deploy.sh
[CicdEnvironment] percept status(deploy(staging), passed)
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\health_check.sh staging
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script] [health_check] PASS: staging is healthy at http://localhost:8001/health
[CicdEnvironment] exit_code=0 script=health_check.sh
[CicdEnvironment] percept status(health_check(staging), passed)
[CicdEnvironment] percept environment(staging, stable)
[CicdEnvironment][telemetry] production grace window seconds=5
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\deploy.sh production candidate
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] skipped production poll during deployment grace window
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script] #1 [internal] load local bake definitions
[CicdEnvironment][script] #1 reading from stdin 644B done
[CicdEnvironment][script] #1 DONE 0.0s
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script] 
[CicdEnvironment][script] #2 [internal] load build definition from Dockerfile
[CicdEnvironment][script] #2 transferring dockerfile: 231B 0.0s done
[CicdEnvironment][script] #2 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #3 [internal] load metadata for docker.io/library/python:3.12-slim
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script] #3 DONE 0.5s
[CicdEnvironment][script] 
[CicdEnvironment][script] #4 [internal] load .dockerignore
[CicdEnvironment][script] #4 transferring context: 85B 0.0s done
[CicdEnvironment][script] #4 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #5 [internal] load build context
[CicdEnvironment][script] #5 transferring context: 67B 0.0s done
[CicdEnvironment][script] #5 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #6 [1/5] FROM docker.io/library/python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a
[CicdEnvironment][script] #6 resolve docker.io/library/python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a 0.1s done
[CicdEnvironment][script] #6 DONE 0.1s
[CicdEnvironment][script] 
[CicdEnvironment][script] #7 [2/5] WORKDIR /service
[CicdEnvironment][script] #7 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #8 [3/5] COPY requirements.txt .
[CicdEnvironment][script] #8 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #9 [4/5] RUN pip install --no-cache-dir -r requirements.txt
[CicdEnvironment][script] #9 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #10 [5/5] COPY service.py .
[CicdEnvironment][script] #10 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #11 exporting to image
[CicdEnvironment][script] #11 exporting layers done
[CicdEnvironment][script] #11 exporting manifest sha256:eb850b27d1ed65ca22d2feb017b8e5801c4fc073a88f511ec99c64702646fc4b done
[CicdEnvironment][script] #11 exporting config sha256:f7c988cf219a654d1d08c9946d155285c08e9f5a863e6b37acf01ef765a3da81 done
[CicdEnvironment][script] #11 exporting attestation manifest sha256:c2de8d31c37858fddcd39296a7328f70191fd3994733c1ae774ed1e560f6432f 0.1s done
[CicdEnvironment][script] #11 exporting manifest list sha256:f3c74be78ed27015714b2aea4935073eb64efbbf54481b491a704e12d096bf7f
[CicdEnvironment][script] #11 exporting manifest list sha256:f3c74be78ed27015714b2aea4935073eb64efbbf54481b491a704e12d096bf7f 0.0s done
[CicdEnvironment][script] #11 naming to docker.io/library/260023_bdi_cicd-payment-production:latest done
[CicdEnvironment][script] #11 unpacking to docker.io/library/260023_bdi_cicd-payment-production:latest 0.0s done
[CicdEnvironment][script] #11 DONE 0.2s
[CicdEnvironment][script] 
[CicdEnvironment][script] #12 resolving provenance for metadata file
[CicdEnvironment][script] #12 DONE 0.0s
[CicdEnvironment][script]  260023_bdi_cicd-payment-production  Built
[CicdEnvironment][script]  Container payment-production  Creating
[CicdEnvironment][script]  Container payment-production  Created
[CicdEnvironment][script]  Container payment-production  Starting
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] skipped production poll during deployment grace window
[CicdEnvironment][script]  Container payment-production  Started
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script]  Container prometheus  Running
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script] [deploy] PASS: deployed candidate to production using payment-production
[CicdEnvironment] exit_code=0 script=deploy.sh
[CicdEnvironment][telemetry] production grace window seconds=5
[CicdEnvironment] percept status(deploy(production), passed)
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\health_check.sh production
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=0.0000(low) environment=unstable
[CicdEnvironment][script] [health_check] PASS: production is healthy at http://localhost:8002/health
[CicdEnvironment] exit_code=0 script=health_check.sh
[CicdEnvironment] percept status(health_check(production), passed)
[CicdEnvironment] percept environment(production, stable)
[CicdEnvironment][decision] release_complete
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] skipped production poll during deployment grace window
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=0.0000(normal) latency_p95_ms=0.00(normal) availability=1.0000(high) environment=stable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][decision] recovery_reason reason=telemetry_unstable
[CicdEnvironment][telemetry] production grace window seconds=5
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\rollback.sh production
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][script] #1 [internal] load local bake definitions
[CicdEnvironment][script] #1 reading from stdin 644B done
[CicdEnvironment][script] #1 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #2 [internal] load build definition from Dockerfile
[CicdEnvironment][script] #2 transferring dockerfile: 231B 0.0s done
[CicdEnvironment][script] #2 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #3 [internal] load metadata for docker.io/library/python:3.12-slim
[CicdEnvironment][script] #3 DONE 0.6s
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][script] 
[CicdEnvironment][script] #4 [internal] load .dockerignore
[CicdEnvironment][script] #4 transferring context: 85B 0.0s done
[CicdEnvironment][script] #4 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #5 [internal] load build context
[CicdEnvironment][script] #5 transferring context: 67B 0.0s done
[CicdEnvironment][script] #5 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #6 [1/5] FROM docker.io/library/python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a
[CicdEnvironment][script] #6 resolve docker.io/library/python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a 0.0s done
[CicdEnvironment][script] #6 DONE 0.1s
[CicdEnvironment][script] 
[CicdEnvironment][script] #7 [2/5] WORKDIR /service
[CicdEnvironment][script] #7 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #8 [3/5] COPY requirements.txt .
[CicdEnvironment][script] #8 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #9 [4/5] RUN pip install --no-cache-dir -r requirements.txt
[CicdEnvironment][script] #9 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #10 [5/5] COPY service.py .
[CicdEnvironment][script] #10 CACHED
[CicdEnvironment][telemetry] skipped production poll during deployment grace window
[CicdEnvironment][script] 
[CicdEnvironment][script] #11 exporting to image
[CicdEnvironment][script] #11 exporting layers done
[CicdEnvironment][script] #11 exporting manifest sha256:eb850b27d1ed65ca22d2feb017b8e5801c4fc073a88f511ec99c64702646fc4b done
[CicdEnvironment][script] #11 exporting config sha256:f7c988cf219a654d1d08c9946d155285c08e9f5a863e6b37acf01ef765a3da81 done
[CicdEnvironment][script] #11 exporting attestation manifest sha256:cbdce4a66e6da1404efb9e1ec24b97b22b54759a6567ea831f6bbd905c402420 0.0s done
[CicdEnvironment][script] #11 exporting manifest list sha256:4f18c586977770c5b7a6d8d67fc4450dd4772acd3363eeb418ddbb8affff356c 0.0s done
[CicdEnvironment][script] #11 naming to docker.io/library/260023_bdi_cicd-payment-production:latest
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][script] #11 naming to docker.io/library/260023_bdi_cicd-payment-production:latest done
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][script] #11 unpacking to docker.io/library/260023_bdi_cicd-payment-production:latest 0.0s done
[CicdEnvironment][script] #11 DONE 0.2s
[CicdEnvironment][script] 
[CicdEnvironment][script] #12 resolving provenance for metadata file
[CicdEnvironment][script] #12 DONE 0.0s
[CicdEnvironment][script]  260023_bdi_cicd-payment-production  Built
[CicdEnvironment][script]  Container payment-production  Recreate
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][script]  Container payment-production  Recreated
[CicdEnvironment][script]  Container payment-production  Starting
[CicdEnvironment][script]  Container payment-production  Started
[CicdEnvironment][script]  Container prometheus  Running
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][script] [rollback] PASS: restored production to stable
[CicdEnvironment] exit_code=0 script=rollback.sh
[CicdEnvironment][telemetry] production grace window seconds=5
[CicdEnvironment] percept status(rollback(production), passed)
[CicdEnvironment] percept environment(production, stable)
[CicdEnvironment][telemetry] skipped production poll during deployment grace window
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][decision] rollback_production
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
[CicdEnvironment][telemetry] production error_rate=1.0000(high) latency_p95_ms=4.75(normal) availability=1.0000(high) environment=unstable
```
