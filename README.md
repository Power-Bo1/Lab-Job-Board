# README.md — DevSecOps Lab: Containerised Job Board Platform

**Author:** Power-Bo1
**Repository:** https://github.com/Power-Bo1/Lab-Job-Board
**Date:** 04/08/2026

> **Note for the lecturer:** on my machine the stack runs on port **8080** (`NGINX_PORT=8080` in `.env`), because host port 80 is intercepted by k3s/Traefik hostPort NAT rules on my VM. This is the remedy listed in the handout's Common Issues table ("Port 80 already in use"). Full analysis in section 0, issue #6. All screenshots therefore show `localhost:8080`.

---

## 0. Starter-code bugs found and fixed during bring-up

| # | Symptom | Root cause | Fix (commit) |
|---|---------|-------------------------------|--------------|
| 1 | **npm ci** fails: "can only install with an existing package-lock.json" | npm ci (Clean Install) strictly requires a package-lock.json file because its entire architecture is built around **enforcing** compliance with that file |I ran (cd applications-service && npm install --package-lock-only && cd .. cd frontend && npm install --package-lock-only && cd ..) and (ls applications-service/package-lock.json frontend/package-lock.json git add applications-service/package-lock.json frontend/package-lock.json git commit -m "fix I added npm lockfiles so npm ci is reproducible") |
| 2 | jobs-service crash-loops, **Restarting(1)** DB and Node service look fine |The primary characters that break SQLAlchemy’s URL parsing are **reserved URL delimiter characters** `%` `@`, `:`, `/`, `?` | Fix the URL-safe password + `docker compose down -v` and I added the `-v` because postgres bakes the password into the volume at first initialization, so the volume had to be destroyed for the new password to take effect. And the asymmetry postgres received the password raw via env var, only the URL-embedded copy broke, and only the Python service noticed at startup because it connects eagerly while Node's pool connects lazily. |
| 3 | frontend crash-loops: Emerg unknown directive "eserver" | nginx validates the whole config at startup and found a typo shipped in the start of the file | The one-character (**e**) before the word (server) in file **frontend/nginx.conf** I removed it and ran again **sudo docker compose up -d --build --no-deps frontend**  |
| 4 | frontend & nginx serve traffic fine but report **unhealthy** | localhost resolves to `::1` first and BusyBox it's wget that tries one address with no fallback, and nginx that listens IPv4-only | I Head to change in **frontend** docker file to `CMD wget -q --spider http://127.0.0.1:80 || exit 1` and in **nginx** Dockerfile `CMD wget -q --spider http://127.0.0.1:80/api/jobs || exit 1` |
| 5 | `curl /api/jobs/` (with slash, as documented) returns **307** UI job list broken | nginx rewrite → `/jobs/` → FastAPI route is `/jobs` → Starlette redirect_slashes **307** → Location goes back through `location /` into the frontend |I added one new rule in **nginx.conf** and to fix the route of `/` and so I add one rule line`rewrite ^/api/jobs/$ /jobs break;|
| 6 | Browser at `localhost` → plain-text `404 page not found`, no `Server:` header | the problem was that nothing else *listened* on `:80` and yet something answered — iptables DNAT intercepts before any socket k3s /Traefik hostPort rules matched IPv4 only, so IPv6 still reached our nginx | So I had to change in file `.env` to `NGINX_PORT=8080`  because port 80 was already occupied by **k3s** in my VM |

---

## Task 1 — Dockerfile Analysis & Hardening

### 1.1 Vulnerability scans (provided images, before hardening)

Evidence: `trivy-jobs-before.txt`, `trivy-apps-before.txt`, `trivy-frontend-before.txt`, `before-sizes.txt`.

| Image | OS-layer findings | App-package findings | CRITICAL |
|---|---|---|---|
| jobboard-jobs-service (debian 13.6) | 171 (4 CRIT, 19 HIGH, 54 MED, 66 LOW, 28 UNK) | 13 python-pkg (0 CRIT, 3 HIGH) | 4 |
| jobboard-applications-service (alpine 3.23.4) | 0 | 25 node-pkg (1 CRIT, 15 HIGH) | 1 |
| jobboard-frontend (alpine 3.21.3) | 0 | 0 | 0 |

**Q1 — How many CRITICAL CVE's in total across all images?**
- In total there were **5** CRITICAL CVE's across the three images (4 + 1 + 0), all four in jobs-service belonging to a single package, perl-base.

**Q2 — Which image has the most vulnerabilities?**
- The image with the most vulnerabilities was **jobs-service** because of the all findings in npm's own bundled dependencies.

**Q3 — One CRITICAL CVE explained: CVE-2026-42496 (perl-Archive-Tar path traversal)**

- **(a) What it is CVE-2026-42496** This is a path traversal vulnerability in the Perl module that have a flaw that allows an attacker to bypass directory restrictions and gain arbitrary file access on the host system by extracting a malicious tar archive.
- **(b) Which package it affects** It's affect the package of perl-base (trixie) 5.40.1-6, and why is a Perl interpreter inside a Python API image at all because Python image inherits from a general-purpose Linux distribution like Debian or Ubuntu, where Perl is deeply embedded as a core dependency for system administration tools, package managers, and build scripts rather than for running Python.
- **(c) Fix / mitigation** In Debian the status is `fix_deferred` / `affected` — no patched package exists yet only version 5.44.0-1 but it's in experimental state, So `apt-get upgrade` cannot remove it, But my idea how I can fix it by test if it first have reachability and what I found that was no Perl code ever executes in this workload and the service never extracts archives, And also the container already runs as a non-root user, which I verified with `whoami` . And I considered switching to Alpine Python base because it removes the Perl layer entirely, **the fix is not always an upgrade**.

### 1.2 Hardening applied

- My approach to how to Harden the Dockerfiles was first to check what is the sha256 images of every  Dockerfiles was pulled with `docker buildx imagetools inspect` and then after I knew what is the image of every Dockerfile I edited the `FROM` lines like it `nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10` like that docker know exactly what image it need to pull.

-   **Tags and Lockfile Versions**
    -   Labels like `latest`, `v1`, or version ranges in a lockfile.
    -   They point to a moving target.
    -   They can change over time to point to new code.

-   **Digests and Integrity Hashes**
    -   Strings like `sha256:...` or package integrity hashes.
    -   They point to fixed content.
    -   If the file changes, the hash changes too. 

-   **Why It Matters**

-   **Safety** Hashes stop hidden changes.

-   **Trust** You run the exact same code every time.

-   **Speed** Systems can skip work if the hash is the same.

**The Changes that was made**

- **Replaced `RUN chown -R` with `COPY --chown=appuser:appgroup`** Using a separate `RUN chown -R` command in a Dockerfile duplicates all modified files into a new layer because Docker's union file system records metadata and permission changes by copying the affected files entirely, effectively bloating your image with duplicate `node_modules` data.
- **Moved OS patching out of the builder stage into the runtime stage:** "patch the stage that ships" — the builder is discarded and identical before/after Debian counts proved about the base already being current.
- **`apk update && apk upgrade --no-cache` → `apk --no-cache upgrade`**.
- **`npm ci --only=production` → `npm ci --omit=dev`** deprecated flag same behaviour, current syntax.
- **Removed the package managers from runtime images** — `pip` from the Python image `npm`, `corepack`, and `yarn` from the Node image the principle and the runtime image has no business installing packages the evidence that justified it (all 25 apps-service findings, including the only CRITICAL — node-tar CVE-2026-59873 — lived inside npm's bundled tree) the honest caveat deleting base-layer files creates whiteouts, which clears scanner findings but does not shrink the image.
- **Targeted dependency bumps** — `fastapi==0.141.1` (pulls patched `starlette 1.3.1`), `python-dotenv==1.2.2`, `uuid ^11.1.1` The minimal targeted bumps instead of `npm audit fix --force` the uuid reachability note — my code only calls `uuidv4()`, the vulnerable v3/v5/v6-with-buffer path was never reachable, But I fixed it anyway.

**Verification evidence:**

- Non-root: `sudo docker run --rm jobboard-jobs-service:latest whoami` → `appuser`.
- Pins complete: `grep -n "^FROM" */Dockerfile` → 7/7 lines contain `@sha256:`.
- `HEALTHCHECK` I had to check in `frontend/Dockerfile` and `nginx/Dockerfile`  and after seeing the logs of those containers I had to change the URL from `localhost` to `127.0.0.1`.
- `.dockerignore` I added `venv/`, `coverage/`and verified it.

**Before / after results:**

| Image | Size before → after | Findings before → after |
|---|---|---|
| jobs-service | 274MB → 288MB | 171 OS + 13 py → 171 OS + **0 py** |
| applications-service | 224MB → 210MB | 25 → **0** |
| frontend | 90MB → 93MB | 0 → 0 |
| nginx (proxy) | 97.7MB → 92.7MB | — |

- The real reductions came where duplication was removed (−14MB apps via `--chown`, −5MB nginx via dropping the apk index) frontend's +3MB is upgrade-layer noise jobs-service grew +14MB because — `docker history` shows the `/install → /usr/local` layer at 80.8MB while the whole apt RUN is 4.67MB, so the growth is the newer, larger wheels of the patched dependency stack, **I accepted +14MB in exchange for zero known Python vulnerabilities**.

---

## Task 2 — Docker Compose Orchestration

### 2.1 Logging configuration
- The json-file driver writes each container's stdout/stderr to `/var/lib/docker/containers/<id>/<id>-json.log`, and these options cap it at 3 rotated files × 10MB = 30MB per container, ever. Without it, one chatty container can eat the disk.

### 2.2 Environment variable isolation
- Strong password confirmed (16+ chars — already done) **removal of the `:-jobboard123` default fallbacks** and replacement with `${POSTGRES_PASSWORD:?}` required-variable syntax the test: remove `.env` → stack refuses to start → restore `git status` proof that `.env` is ignored.  The `.env` file is a security risk because it stores sensitive credentials—such as database passwords, API keys, and private tokens—in plain text. This format lacks encryption, access controls, and auditing, making secrets vulnerable if the file is accidentally exposed, leaked through logs, or read by malicious code. And`.env` traveled inside a zip — gitignore protects commits, (nothing else), and the tools: git-secrets, truffleHog, GitHub secret scanning.

### 2.3 Restart policy and dependency ordering
- The observed startup order (postgres ← jobs, apps ← frontend ← nginx) ASCII dependency graph; `condition: service_healthy` vs `service_started`  a healthcheck only verifies what it actually tests the `docker compose stop postgres`.

---

## Task 3 — Data Persistence & Backup

### 3.1 Persistence across restarts
- The POST → stop → start → GET test. For `docker compose down -v` deliberately in during bug #2 to force re-initialisation of the credentials host into the volume.

### 3.2 Volume inspection
- The`docker volume inspect` output where the data lives on the host named volume mount point is in `/var/lib/docker/volumes/jobboard-postgres-data/_data`, And I want in my development to work with Direct Host-Path Control because it way more simpler to understand and work with, But for production I will work with Persistent Volumes because it let me to scale up and down depending on demand.

### 3.3 Backup and restore
- The pg_dump backup got verification and I did the exact restore commands and also the dump is 134 lines and restores the entire schema plus data — and the `DROP TABLE ... CREATE TABLE ... COPY` sequence visible in the output is exactly the `--clean --if-exists` behavior doing its job over the freshly seeded database.

---

## Task 4 — CI/CD Pipeline

- The finding was that after creating `.github/workflows/ci.yml`and creating `jobs-service/tests/test_main.py`  I did all four tests that was required to do and after checking `test_main.py` it passed all four tests in `pytest`. And in file `ci.yml` before all six steps worked I had to do some test with `ruff check app tests` and `ruff check --fix app tests`and also I was needed to add a file call `ruff.toml` that let `FastAPI's` dependency to injection deliberately puts a call in the argument as default so Depends and friends are declared safe instead of rewriting framework-idiomatic application code. And now you can go and see the all four docker images of this lab in dockerhub under the username `powerboi123`.

---

## Task 5 — Networking & Service Communication

### 5.1 Understand the Docker network
- The containers that list inside the network with their IP addresses are `nginx-proxy` with IP `172.18.0.3/16`, And `jobboard-db` with IP `172.18.0.5/16`, And `job-service` with IP `172.18.0.2/16`, And `jobboard-frontend` with IP `172.18.0.6/16`, And `applications-service` with IP `172.18.0.4/16`. 
- Docker runs an embedded DNS resolver at `127.0.0.11` inside every container on a user-defined network, resolving service names to current container IPs.
- And if I try to reach `jobs-service:8000`from my browser I get Unable to connect because the name only exists inside the Docker network's DNS, and port 8000 is never published to the host. My `ps` output shows only nginx with a host binding (`0.0.0.0:8080->80`) every other service shows a bare container port. That's the single-entry-point design the whole architecture is built on.
### 5.2 Inter-service communication test
- After I exec the script in container `jobs-service` I managed to reach to the database (`postgres jobboard`).
### 5.3 Nginx routing analysis
- browser resolves localhost → hits nginx-proxy (the only published port) → nginx matches `location /api/applications/` → the rewrite strips the prefix to `/applications/` → proxy_pass sends it to `http://applications-service:3001` (name resolved via 127.0.0.11) → Express routes to the applications router, which inserts using `uuidv4()` And writes to postgres:5432 → 201 + JSON back up the same path, with nginx adding its response headers.

---

