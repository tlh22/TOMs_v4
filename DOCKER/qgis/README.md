# TOMs — QGIS in Docker (multi-version)

Run any supported version of QGIS in a Docker container and use it in your browser. The TOMs plugin is loaded automatically and connected to the PostGIS database. No local QGIS installation required.

**User workflow:** edit **`DOCKER/qgis/.env`** for `QGIS_VERSION` and `BASE_IMAGE` (and `USE_VNC` on Windows/Linux), then run `docker compose build` and `docker compose up -d`. The image is built for the exact version in `.env` (e.g. 3.22 installs QGIS 3.22.x). On **Mac**, use **http://localhost:6080/vnc.html** to open QGIS in the browser; on Windows/Linux, set `USE_VNC=0` so QGIS uses the host display without VNC.

---

## Prerequisites

- **Docker Desktop** (Mac / Windows) or **Docker Engine** plus the **Compose** plugin (Linux)
- **Git** (to clone the repository)

No Python, no extra tools. Docker and Git are enough.

---

## First-time setup (do this once)

### Step 1 — Create the shared Docker network

```bash
docker network create toms_net
```

(If you already started the PostGIS stack from `DOCKER/postgis`, this network may already exist.)

### Step 2 — Start the PostGIS database

```bash
cd DOCKER/postgis
docker compose up -d
cd ../..
```

Wait until the database is ready (first run can take a minute while init scripts run).

### Step 3 — Build and start QGIS in Docker

```bash
cd DOCKER/qgis
docker compose build
docker compose up -d
```

### Step 4 — Open QGIS in your browser

Open: **http://localhost:6080/vnc.html**

QGIS will appear in 30–60 seconds. Enable the **TOMs** plugin in QGIS (Plugins → Manage and Install Plugins) if it is not already enabled. The database connection is preconfigured via the TOMs_Test service.

---

## Daily use (database already running)

```bash
cd DOCKER/qgis
docker compose up -d
```

Then open: **http://localhost:6080/vnc.html**

---

## Switching QGIS versions

1. Open **DOCKER/qgis/.env** in a text editor.
2. Change **both** lines to match the version you want. The comment block in `.env` lists all valid combinations.

   Example — switch to QGIS 3.44:

   ```env
   QGIS_VERSION=3.44
   BASE_IMAGE=debian:bookworm-slim
   ```

3. Rebuild and restart:

   ```bash
   docker compose build
   docker compose up -d
   ```

---

## Available versions (Debian only)

| QGIS_VERSION   | Label / notes        | BASE_IMAGE              |
|----------------|----------------------|-------------------------|
| 3.22           | QGIS 3.22 (Debian repo only; no qgis.org) | debian:bookworm-slim  |
| 3.28 / 3.34 / 3.44 | QGIS 3.x from qgis.org | debian:bookworm-slim  |
| 4.0-nightly    | QGIS 4.0 nightly     | debian:trixie-slim      |

**Note:** For **3.22** the image does not contact download.qgis.org (uses only Debian’s repo), so the build works when that host is unreachable or DNS fails.

---

## VNC: Mac only (Windows/Linux without VNC)

- **Mac:** VNC is used so you can use QGIS in the browser. In **`.env`** set **`USE_VNC=1`** (default). Open **http://localhost:6080/vnc.html**.
- **Windows / Linux:** If QGIS works with the host display (no VNC), set **`USE_VNC=0`** in **`.env`**. The container will start QGIS without Xvfb/noVNC and use the host’s DISPLAY.

The image is built for the **exact QGIS version** in `.env` (e.g. `QGIS_VERSION=3.22` installs 3.22.x). Rebuild after changing the version.

---

## What to do for each version (using the `.env` file)

The file **`DOCKER/qgis/.env`** controls which QGIS version runs. You must set **both** `QGIS_VERSION` and `BASE_IMAGE` together. After editing `.env`, run `docker compose build` and `docker compose up -d` from `DOCKER/qgis/`.

### For QGIS version 3 (3.22, 3.28, 3.34, 3.44)

1. Open **`DOCKER/qgis/.env`**.
2. Set `QGIS_VERSION` to the version you want (e.g. 3.22 or 3.44) and `BASE_IMAGE=debian:bookworm-slim`:

   ```env
   QGIS_VERSION=3.22
   BASE_IMAGE=debian:bookworm-slim
   ```

   or for 3.44:

   ```env
   QGIS_VERSION=3.44
   BASE_IMAGE=debian:bookworm-slim
   ```

3. From `DOCKER/qgis/` run:

   ```bash
   docker compose build
   docker compose up -d
   ```

4. Open **http://localhost:6080/vnc.html** in your browser.

Version 3 uses **Debian Bookworm** and the stable QGIS repository.

---

### For QGIS version 4

1. Open **`DOCKER/qgis/.env`**.
2. Set these two lines:

   ```env
   QGIS_VERSION=4.0-nightly
   BASE_IMAGE=debian:trixie-slim
   ```

3. From `DOCKER/qgis/` run:

   ```bash
   docker compose build
   docker compose up -d
   ```

4. Open **http://localhost:6080/vnc.html** in your browser.

Version 4 uses **Debian Trixie** and the QGIS nightly repository.

---

## Stopping and removing

- **Stop and remove the container** (profile data in `qgis_config/` is kept on the host):

  ```bash
  docker compose down
  ```

- **Stop without removing:**

  ```bash
  docker compose stop qgis
  ```

---

## How the database connection works

The QGIS container joins the **toms_net** Docker network, where the PostGIS container runs with hostname **toms_postgis**. The file **DOCKER/pg_service/.pg_service.conf** defines a connection service named **TOMs_Test** pointing to `toms_postgis:5432`. The container sets **PGSERVICEFILE** so QGIS and other tools use this file. No manual connection setup is needed in QGIS — use the **TOMs_Test** service when adding PostGIS layers or in the TOMs plugin.

**TOMs config and form path:** The container sets **TOMs_CONFIG_PATH** so the plugin finds **TOMs.conf**. When that env var is set (Docker), the plugin uses the **form path** `.../TOMs/ui` automatically; you do not need to change **form_path** in **TOMs.conf**. On a local install, **form_path** in **TOMs.conf** is used as before.

---

## Troubleshooting

| Problem | Fix |
|--------|-----|
| **"network toms_net not found"** | Run: `docker network create toms_net` |
| **Browser shows nothing / blank** | Wait up to 60 seconds. Check: `docker logs toms-qgis-4.0-nightly` (use your version from `.env`) |
| **"Cannot connect to database" in QGIS** | Start PostGIS: `cd DOCKER/postgis && docker compose up -d` |
| **Port 6080 already in use** | Stop the other process using 6080, or change the port in `docker-compose.yml` |
| **QGIS crashes immediately** | Check logs: `docker logs toms-qgis-<version>` |
| **"exec format error" or "/bin/bash^M: bad interpreter"** | `start.sh` has Windows (CRLF) line endings. Run: `sed -i 's/\r//' start.sh` (or `dos2unix start.sh`) |
| **TOMs plugin not found in QGIS** | Ensure you started from the TOMs repo root and the volume mount in `docker-compose.yml` is correct (`../..` = repo root). Restart: `docker compose up -d --force-recreate` |
| **Wrong QGIS version after changing .env** | Edit `.env` (both lines), then: `docker compose build --no-cache` and `docker compose up -d` |
| **"Server is already active for display 99" / restart loop** | Fixed in start.sh (cleanup on boot). If it persists: `docker compose down`, then `docker compose up -d` again. |
| **QGIS died on signal 11** | QGIS can crash under virtual display when a VNC client connects. Ensure you use the image’s software GL (`LIBGL_ALWAYS_SOFTWARE=1`). If it keeps crashing, run once without restart: in `docker-compose.yml` comment out `restart: unless-stopped`, then `docker compose up` and check `docker logs` for details. |
| **Direct VNC (localhost:5900) not working** | Ensure the container is up and x11vnc is running. Use **http://localhost:6080/vnc.html** (noVNC) for browser access, or connect a VNC client (e.g. TigerVNC) to **localhost:5900**. |
