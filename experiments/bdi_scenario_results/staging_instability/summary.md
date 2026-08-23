# staging_instability

Capability: Use staging as a production gate and stop release when staging verification fails.

Result: PASS

Success criteria: Jason detects unstable staging and prevents production deployment.

## Expected Beliefs

```text
status(health_check(staging),failed): True
environment(staging,unstable): True
decision(stop_pipeline): True
stop_reason(staging_unstable): True
```

## Agent Mind

```text
Agent mind capture skipped by suite automation. Use 'jason agent mind deployment_agent' while the MAS is running for live belief inspection.
```

## Environment Log Tail

```text
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][script] #2 transferring dockerfile: 231B 0.0s done
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script] #2 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #3 [payment-staging internal] load metadata for docker.io/library/python:3.12-slim
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script] #3 DONE 0.9s
[CicdEnvironment][script] 
[CicdEnvironment][script] #4 [payment-production internal] load .dockerignore
[CicdEnvironment][script] #4 transferring context: 85B done
[CicdEnvironment][script] #4 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #5 [payment-staging internal] load build context
[CicdEnvironment][script] #5 transferring context: 67B done
[CicdEnvironment][script] #5 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #6 [payment-staging 1/5] FROM docker.io/library/python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a
[CicdEnvironment][script] #6 resolve docker.io/library/python:3.12-slim@sha256:2c941e860699f878900b0edc2403613c234d4b32eda3cc9fa7036991a2a63c4a 0.0s done
[CicdEnvironment][script] #6 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #7 [payment-production 3/5] COPY requirements.txt .
[CicdEnvironment][script] #7 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #8 [payment-production 2/5] WORKDIR /service
[CicdEnvironment][script] #8 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #9 [payment-production 4/5] RUN pip install --no-cache-dir -r requirements.txt
[CicdEnvironment][script] #9 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #10 [payment-staging 5/5] COPY service.py .
[CicdEnvironment][script] #10 CACHED
[CicdEnvironment][script] 
[CicdEnvironment][script] #11 [payment-production] exporting to image
[CicdEnvironment][script] #11 exporting layers done
[CicdEnvironment][script] #11 exporting manifest sha256:eb850b27d1ed65ca22d2feb017b8e5801c4fc073a88f511ec99c64702646fc4b done
[CicdEnvironment][script] #11 exporting config sha256:f7c988cf219a654d1d08c9946d155285c08e9f5a863e6b37acf01ef765a3da81 done
[CicdEnvironment][script] #11 exporting attestation manifest sha256:8d4ae99f457056192cd6d484fa2b1c30ea9703ad18efa0a679ccd19dd473ed1d
[CicdEnvironment][script] #11 exporting attestation manifest sha256:8d4ae99f457056192cd6d484fa2b1c30ea9703ad18efa0a679ccd19dd473ed1d 0.1s done
[CicdEnvironment][script] #11 exporting manifest list sha256:99d245c5b097866fa2881179398160c70b3c35534cf6e397d9e8e58f3d547765
[CicdEnvironment][script] #11 exporting manifest list sha256:99d245c5b097866fa2881179398160c70b3c35534cf6e397d9e8e58f3d547765 0.0s done
[CicdEnvironment][script] #11 naming to docker.io/library/260023_bdi_cicd-payment-production:latest done
[CicdEnvironment][script] #11 unpacking to docker.io/library/260023_bdi_cicd-payment-production:latest 0.0s done
[CicdEnvironment][script] #11 DONE 0.3s
[CicdEnvironment][script] 
[CicdEnvironment][script] #12 [payment-staging] exporting to image
[CicdEnvironment][script] #12 exporting layers done
[CicdEnvironment][script] #12 exporting manifest sha256:7bb3fe8eeb56f8fd17d64bdea8669c3ba0e37683af0a0666fd8ca622891ae591 done
[CicdEnvironment][script] #12 exporting config sha256:b73f7a41074835768300df3a4e1f1562f8fa19f8661f2bf84b7d97b05afb97b2 done
[CicdEnvironment][script] #12 exporting attestation manifest sha256:4e2c10d513098b038f3f3d88df01c408261046ea182498f0709a51eace1a94ea 0.1s done
[CicdEnvironment][script] #12 exporting manifest list sha256:9b72e3298dde3da3fef2679c533e50a4959715280df2c58543bcbfe37e87e059 0.0s done
[CicdEnvironment][script] #12 naming to docker.io/library/260023_bdi_cicd-payment-staging:latest done
[CicdEnvironment][script] #12 unpacking to docker.io/library/260023_bdi_cicd-payment-staging:latest 0.0s done
[CicdEnvironment][script] #12 DONE 0.3s
[CicdEnvironment][script] 
[CicdEnvironment][script] #13 [payment-staging] resolving provenance for metadata file
[CicdEnvironment][script] #13 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #14 [payment-production] resolving provenance for metadata file
[CicdEnvironment][script] #14 DONE 0.0s
[CicdEnvironment][script]  260023_bdi_cicd-payment-staging  Built
[CicdEnvironment][script]  260023_bdi_cicd-payment-production  Built
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script] [build] PASS: built payment service image for candidate (docker)
[CicdEnvironment] exit_code=0 script=build.sh
[CicdEnvironment] percept status(build, passed)
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\test.sh candidate
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script] [test] PASS: service tests passed for candidate
[CicdEnvironment] exit_code=0 script=test.sh
[CicdEnvironment] percept status(test, passed)
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\security_scan.sh candidate
[CicdEnvironment][script] [security_scan] PASS: no simple secret patterns found for payment service candidate
[CicdEnvironment] exit_code=0 script=security_scan.sh
[CicdEnvironment] percept status(security_scan, passed)
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] action C:\Program Files\Git\bin\bash.exe C:\NHI\2026_IT-Project\260023_BDI_CICD\cicd\actions\deploy.sh staging candidate
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script] #1 [internal] load local bake definitions
[CicdEnvironment][script] #1 reading from stdin 632B done
[CicdEnvironment][script] #1 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #2 [internal] load build definition from Dockerfile
[CicdEnvironment][script] #2 transferring dockerfile: 231B done
[CicdEnvironment][script] #2 DONE 0.0s
[CicdEnvironment][script] 
[CicdEnvironment][script] #3 [internal] load metadata for docker.io/library/python:3.12-slim
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
[CicdEnvironment][script] #11 exporting manifest sha256:7bb3fe8eeb56f8fd17d64bdea8669c3ba0e37683af0a0666fd8ca622891ae591 done
[CicdEnvironment][script] #11 exporting config sha256:b73f7a41074835768300df3a4e1f1562f8fa19f8661f2bf84b7d97b05afb97b2 done
[CicdEnvironment][script] #11 exporting attestation manifest sha256:e3ab31ffee6be6c070e7c652df827bb3ed8ea66e367d0f2a6da34db600d9fe4a
[CicdEnvironment][script] #11 exporting attestation manifest sha256:e3ab31ffee6be6c070e7c652df827bb3ed8ea66e367d0f2a6da34db600d9fe4a 0.1s done
[CicdEnvironment][script] #11 exporting manifest list sha256:1f7aebe57d7595dd5e59f9a5a89ce9034bdaf52590291f006b45e35999dad1ae 0.0s done
[CicdEnvironment][script] #11 naming to docker.io/library/260023_bdi_cicd-payment-staging:latest done
[CicdEnvironment][script] #11 unpacking to docker.io/library/260023_bdi_cicd-payment-staging:latest 0.0s done
[CicdEnvironment][script] #11 DONE 0.2s
[CicdEnvironment][script] 
[CicdEnvironment][script] #12 resolving provenance for metadata file
[CicdEnvironment][script] #12 DONE 0.0s
[CicdEnvironment][script]  260023_bdi_cicd-payment-staging  Built
[CicdEnvironment][script]  Network 260023_bdi_cicd_default  Creating
[CicdEnvironment][script]  Network 260023_bdi_cicd_default  Created
[CicdEnvironment][script]  Container payment-staging  Creating
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script]  Container payment-staging  Created
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script]  Container payment-staging  Starting
[CicdEnvironment][script]  Container payment-staging  Started
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script]  Container prometheus  Creating
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment] percept telemetry(production, unavailable)
[CicdEnvironment] percept network(production, suspected)
[CicdEnvironment] percept environment(production, unstable)
[CicdEnvironment][telemetry] poll_failed environment=production reason=null
[CicdEnvironment][script]  Container prometheus  Created
[CicdEnvironment][script]  Container prometheus  Starting
[CicdEnvironment][script]  Container prometheus  Started
[CicdEnvironment][script] [deploy] PASS: deployed candidate to staging using payment-staging
[CicdEnvironment] exit_code=0 script=deploy.sh
[CicdEnvironment] percept status(deploy(staging), passed)
[CicdEnvironment] forced_failure stage=health_check_staging env=BDI_FORCE_HEALTH_CHECK_STAGING_FAIL
[CicdEnvironment] percept status(health_check(staging), failed)
[CicdEnvironment] percept environment(staging, unstable)
[CicdEnvironment][decision] stop_pipeline reason=staging_unstable
```
