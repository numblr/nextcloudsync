---
name: build-and-test
description: Build the nextcloudsync Docker image and verify nextcloudcmd is available inside it. Use this after any Dockerfile change to confirm the image builds and the sync tooling is present.
---

Run the following steps in order:

1. Build the Docker image:
   ```
   docker build -t nextcloudsync .
   ```
   Report any build errors clearly.

2. Smoke-test that `nextcloudcmd` is available inside the built image:
   ```
   docker run --rm nextcloudsync nextcloudcmd --version
   ```
   If the command is not found, report which layer in the Dockerfile is missing the installation and suggest a fix.

3. Check that the entrypoint is correctly set:
   ```
   docker inspect nextcloudsync --format '{{.Config.Entrypoint}}'
   ```
   Confirm it points to the sync script, not a shell.

Report a short pass/fail summary for each step.
