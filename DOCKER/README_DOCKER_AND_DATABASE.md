# TOMs: Docker and database guide

This document is the **single reference** for Docker in the TOMs project: every component (PostGIS, QGIS desktop in Docker, QGIS Server, QWC2, etc.), how the database works, how to run and connect each part, and **how to integrate QGIS Server or any other service** with the TOMs database and shared network. Use it for first-time setup, daily use, and when you add or change Docker services (including QGIS Server) in the future.

---

## Table of contents

1. [Docker components in this project](#1-docker-components-in-this-project)
2. [Ports and services at a glance](#2-ports-and-services-at-a-glance)
3. [What is Docker and why does TOMs use it?](#3-what-is-docker-and-why-does-toms-use-it)
4. [Shared network: toms_net](#4-shared-network-toms_net)
5. [The database (PostGIS)](#5-the-database-postgis)
6. [How you access the database](#6-how-you-access-the-database)
7. [The connection file: pg_service.conf](#7-the-connection-file-pg_serviceconf)
8. [First-time setup](#8-first-time-setup)
9. [Daily use](#9-daily-use)
10. [Integrating QGIS Server (or another service) with the TOMs database](#10-integrating-qgis-server-or-another-service-with-the-toms-database)
11. [Folder structure](#11-folder-structure)
12. [Adding or changing Docker services](#12-adding-or-changing-docker-services)
13. [Troubleshooting](#13-troubleshooting)
14. [Summary diagram](#14-summary-diagram)
15. [Quick reference](#15-quick-reference)

---

## 1. Docker components in this project

All Docker-related code lives under **`TOMs/DOCKER/`**. Each subfolder is one **component** (one or more services). You do not need to run all of them.

| Component | Path | Purpose | Depends on | Network |
|-----------|------|---------|------------|---------|
| **PostGIS database** | `DOCKER/postgis/` | PostgreSQL + PostGIS; creates **TOMs_Test** database. **Core** for development and testing. | — | **toms_net** (creates it) |
| **pg_service** | `DOCKER/pg_service/` | Connection file **`.pg_service.conf`**: host, port, dbname, user for **TOMs_Test**. Used by QGIS (host or container), QGIS Server, and other tools. Not a container; just a file. | — | — |
| **QGIS in Docker** | `DOCKER/qgis/` | Run QGIS (3.22, 3.44, or 4.x) in a container; TOMs plugin loaded; use in browser (VNC) or host display. | PostGIS running | **toms_net** |
| **QGIS Server (Camptocamp)** | `DOCKER/qgis_server_camptocamp/` | QGIS Server (Camptocamp image) for OGC/WMS/WFS etc. **Already configured** to use **toms_net** and **pg_service** from the repo. | PostGIS running | **toms_net** |
| **QGIS Server (oq)** | `DOCKER/qgis_server_oq/` | QGIS Server (OpenQuake image) behind nginx. **Uses a different network** (`qgis-net`) and host paths; see [Section 10](#10-integrating-qgis-server-or-another-service-with-the-toms-database) to adapt for TOMs. | — | qgis-net (default) |
| **QWC2** | `DOCKER/qwc2/` | Web client (QGIS Web Client 2); nginx serving front-end. | Optional (can talk to QGIS Server) | **toms_net** |
| **Let’s Encrypt** | `DOCKER/lets_encrypt/` | SSL certificates for production (e.g. for QGIS Server domain). | — | As in compose |

- **Run only the database:** use **postgis**. Use **pg_service** on the host if you connect from QGIS or other tools on your machine.
- **Run QGIS desktop in Docker:** start **postgis** first, then **qgis**; see [DOCKER/qgis/README.md](qgis/README.md).
- **Run QGIS Server with TOMs database:** start **postgis** first, then use **qgis_server_camptocamp** (already on toms_net) or adapt **qgis_server_oq**; see [Section 10](#10-integrating-qgis-server-or-another-service-with-the-toms-database).
- **Add a completely new service:** see [Section 12](#12-adding-or-changing-docker-services).

---

## 2. Ports and services at a glance

| Service / component | Host port(s) | Purpose |
|---------------------|--------------|---------|
| **postgis** | **5435** → 5432 | Database (TOMs_Test). Connect from host to `localhost:5435`. |
| **qgis** (desktop in Docker) | **6080** (noVNC), **5900** (VNC) | Browser: http://localhost:6080/vnc.html |
| **qgis_server_camptocamp** | **8381** → 80 | QGIS Server (WMS/WFS etc.). e.g. http://localhost:8381 |
| **qgis_server_oq** (nginx) | **8010** → 80 | QGIS Server behind nginx (if using qgis-net). |
| **qwc2** (nginx) | **8012** → 80 | Web client. http://localhost:8012 |

When you add a new service, avoid using these host ports (5435, 5900, 6080, 8010, 8012, 8381) unless you intend to replace an existing one.

---

## 3. What is Docker and why does TOMs use it?

### Docker in simple terms

- **Your computer** (Mac, Windows, Linux) runs **Docker**. Docker runs isolated “boxes” called **containers**.
- Each **container** runs one main thing (e.g. a database). It has its own files and settings inside the box but uses your computer’s CPU and memory.
- **Why TOMs uses it:** TOMs needs a **PostgreSQL + PostGIS** database. Running it in a container gives you:
  - A clean, predictable setup that matches what developers use.
  - Start/stop/remove without affecting the rest of your system.
  - The same steps on Mac, Windows, and Linux.

### Terms you’ll see

| Term | Meaning |
|------|--------|
| **Image** | A read-only template (e.g. “PostgreSQL + PostGIS”). You don’t edit it. |
| **Container** | A running instance of an image. This is what you start and stop. |
| **docker compose** | Starts one or more containers from a config file (`docker-compose.yml`). |
| **Network** | A private “LAN” between containers so they can talk by name (e.g. **toms_postgis**). |
| **Port** | A “door” number. Your machine can expose a port (e.g. **5435**) so apps on your computer connect to the database in the container. |

---

## 4. Shared network: toms_net

Several TOMs Docker setups use a **shared network** so containers can reach the database by name.

- **Network name:** `toms_net`
- **Create it once (if needed):**  
  `docker network create toms_net`  
  (Often it is created automatically when you start the PostGIS compose.)
- **Database hostname on this network:** **toms_postgis** (port **5432**).

Containers that need the database (e.g. QGIS in Docker, QGIS Server) should join **toms_net** and connect to **toms_postgis:5432**. From your **Mac/PC**, you connect to **localhost:5435** (see [Section 6](#6-how-you-access-the-database)).

When you add a new Docker service that must use the TOMs database, attach it to **toms_net** and use host **toms_postgis**, port **5432**.

---

## 5. The database (PostGIS)

### Where the configuration lives

Everything for the **PostGIS database** is under:

```text
TOMs/DOCKER/postgis/
```

The main file is **`DOCKER/postgis/docker-compose.yml`**. It defines:

- **Image:** Built from **dockerfile-toms-test-postgis** (based on **postgis/postgis**).
- **Container name / hostname:** **toms_postgis** on the Docker network.
- **Ports:** Database listens on **5432** inside the container; Docker maps **5435** on your computer → 5432 in the container. So from your Mac you use **localhost:5435**.
- **Volumes (mounts):**
  - **DATAMODEL** – SQL that defines the schema (tables, roles, etc.).
  - **test/data** – Test data and extra SQL for **TOMs_Test**.
  - **config/** – PostgreSQL config files (e.g. postgresql.conf, pg_hba.conf).
  - **toms_test_db_init_scripts/** – Scripts that run **only on first start** and create the **TOMs_Test** database and users.

On first run, the container runs the init scripts and creates a ready-to-use **TOMs_Test** database. On later starts, the data is already there (stored in the container’s volume).

---

## 6. How you access the database

### From your computer (QGIS, pgAdmin, psql, etc.)

- **Host:** `localhost` (or `127.0.0.1`)
- **Port:** **5435**
- **Database:** **TOMs_Test**
- User/password: as in the init scripts or **pg_service.conf** (e.g. `toms.operator` / `password` for the test user).

You do **not** use port 5432 when connecting from your Mac; 5432 is only inside the Docker network.

### From another Docker container (e.g. QGIS in Docker, QGIS Server)

- **Host:** **toms_postgis**
- **Port:** **5432**
- **Database:** **TOMs_Test**
- The container must be on the **toms_net** network.

So: **from host** → localhost:5435; **from container** → toms_postgis:5432.

---

## 7. The connection file: pg_service.conf

- **Location:** `TOMs/DOCKER/pg_service/.pg_service.conf`
- **Purpose:** Defines a **service name** (e.g. **TOMs_Test**) with host, port, dbname, user, and password so you don’t type them every time.
- **Used by:** QGIS, `psql`, and other tools that read `pg_service.conf` (often via **PGSERVICEFILE** or **PGSERVICE**).
- **From your Mac:** The file should use **host=localhost** and **port=5435** for the TOMs_Test service when connecting from the host.
- **From a container:** The same file can be mounted into the container with **host=toms_postgis** and **port=5432** (the QGIS Docker setup does this).

- **For containers (QGIS in Docker, QGIS Server):** The file at **DOCKER/pg_service/.pg_service.conf** uses **host=toms_postgis** and **port=5432**. Mount this file into the container and set **PGSERVICEFILE** to the path where it appears in the container (e.g. `/home/qgisuser/.pg_service.conf` or `/io/pg_service/.pg_service.conf`). Set **PGSERVICE=TOMs_Test** if the app uses it.
- **For your computer (host):** The same file points at toms_postgis:5432, which is only reachable from inside Docker. To connect from the host you either:
  - Override when connecting: use **host=localhost**, **port=5435**, dbname=TOMs_Test, user/password as in the file; or
  - Add a second service in **pg_service.conf** (e.g. `[TOMs_Test_host]` with host=localhost, port=5435) and use that service name when connecting from the host.

So **pg_service.conf** is the shared “address book.” Any new Docker service that needs the TOMs database should mount this file and set **PGSERVICEFILE** (and **PGSERVICE=TOMs_Test** if needed).

---

## 8. First-time setup

You need **Docker** installed (Docker Desktop on Mac/Windows, or Docker Engine + Compose on Linux).

1. **Open a terminal.**

2. **Go to the PostGIS folder:**
   ```bash
   cd path/to/TOMs/DOCKER/postgis
   ```
   (Replace `path/to/TOMs` with your actual TOMs plugin path.)

3. **Start the database:**
   ```bash
   docker compose up -d
   ```
   Or, if the compose file defines several services and you only want the DB:
   ```bash
   docker compose up -d postgis
   ```

4. **Wait 1–2 minutes** the first time. Docker will pull/build the image, create the container, and run the init scripts to create **TOMs_Test**.

5. **Check that it’s running:**
   ```bash
   docker compose ps
   ```
   You should see the **postgis** service with state “Up”.

6. **Connect from your computer:**  
   In QGIS (or any PostgreSQL client), use **localhost**, port **5435**, database **TOMs_Test**, and the user/password from the init scripts or **pg_service.conf**. Or set **PGSERVICEFILE** to **DOCKER/pg_service/.pg_service.conf** and use the **TOMs_Test** service name.

**Optional – run QGIS in Docker:** See **[DOCKER/qgis/README.md](qgis/README.md)**. Start PostGIS first, then start the QGIS container; it will use **toms_net** and **toms_postgis:5432**.

**Optional – run QGIS Server:** See [Section 10](#10-integrating-qgis-server-or-another-service-with-the-toms-database). Start PostGIS first, then start **qgis_server_camptocamp** (or adapt **qgis_server_oq**).

---

## 9. Daily use

- **Start the database (when stopped):**
  ```bash
  cd path/to/TOMs/DOCKER/postgis
  docker compose up -d
  ```

- **Stop the database:**
  ```bash
  docker compose stop
  ```
  (or `docker compose stop postgis` if you have multiple services.)

- **See if it’s running:**
  ```bash
  docker compose ps
  ```

- **View logs:**
  ```bash
  docker compose logs postgis
  ```

While the container is up, the database stays available at **localhost:5435** (from your computer) and at **toms_postgis:5432** (from other containers on **toms_net**).

---

## 10. Integrating QGIS Server (or another service) with the TOMs database

This section is for when you want to **run QGIS Server** (or a similar service) so it uses the **same TOMs_Test database** and **toms_net** as the rest of the project. Follow the same pattern for any other service that must connect to the database.

### Prerequisites

1. **toms_net** must exist. It is created when you start the PostGIS stack:
   ```bash
   cd DOCKER/postgis
   docker compose up -d
   ```
   Or create it manually: `docker network create toms_net`

2. **PostGIS (toms_postgis)** must be running so the database **TOMs_Test** is available at **toms_postgis:5432** on **toms_net**.

3. **pg_service.conf** must define the TOMs_Test connection for **container** use: **host=toms_postgis**, **port=5432**. The file at **DOCKER/pg_service/.pg_service.conf** already does this with the **[TOMs_Test]** service.

### Option A: Use the existing QGIS Server (Camptocamp) – already integrated

**DOCKER/qgis_server_camptocamp/** is already set up to use **toms_net** and the repo’s **pg_service** and project data.

1. Start PostGIS (see [Section 8](#8-first-time-setup)).
2. Start QGIS Server:
   ```bash
   cd DOCKER/qgis_server_camptocamp
   docker compose up -d
   ```
3. QGIS Server will be reachable at **http://localhost:8381** (or your host’s IP). It uses **PGSERVICEFILE=/io/pg_service/.pg_service.conf** and **QGIS_PROJECT_FILE=/io/data/project.qgs**. Projects and **pg_service** are mounted from the repo (e.g. **../pg_service**, **../../QGIS/qgis_server**). Adjust paths in the compose file if your layout differs.

### Option B: Integrate QGIS Server (oq) or another image with TOMs

**DOCKER/qgis_server_oq/** currently uses the network **qgis-net** and host paths like **/home/QGIS/pg_service**. To make it use the TOMs database:

1. **Use the same network as PostGIS:** In the service’s **docker-compose.yml**, attach the service to **toms_net** (external):
   ```yaml
   networks:
     default:
       name: toms_net
       external: true
   ```
   Remove or change any reference to **qgis-net** so the server container is on **toms_net**.

2. **Mount the TOMs pg_service file:** So the server can resolve **TOMs_Test** to toms_postgis:5432. For example:
   ```yaml
   volumes:
     - ../pg_service/.pg_service.conf:/path/inside/container/.pg_service.conf:ro
   environment:
     - PGSERVICEFILE=/path/inside/container/.pg_service.conf
     - PGSERVICE=TOMs_Test
   ```
   Replace `/path/inside/container` with the path your image expects (e.g. **qgis_server_oq** uses **/io/pg_service**; mount the **file** or the **pg_service** directory accordingly).

3. **Mount projects and plugins if needed:** Point the server at your QGIS project(s) and TOMs plugin if required. Use paths relative to the repo, e.g. **../../projects** and **../..** for the plugin, and set **QGIS_PROJECT_FILE** (or equivalent) in the environment.

4. **Start order:** Start **postgis** first, then start the QGIS Server stack. The server will connect to **toms_postgis:5432** via the **TOMs_Test** service.

### Checklist for any new service that uses the TOMs database

- [ ] **toms_net** exists; PostGIS (toms_postgis) is running.
- [ ] Service’s **docker-compose.yml** uses **network: toms_net** (external).
- [ ] **pg_service.conf** is mounted and **PGSERVICEFILE** (and **PGSERVICE=TOMs_Test** if needed) is set.
- [ ] **pg_service.conf** contains **[TOMs_Test]** with **host=toms_postgis**, **port=5432** (for container use).
- [ ] No port conflict with existing services (see [Section 2](#2-ports-and-services-at-a-glance)).
- [ ] Document the component in the [components table](#1-docker-components-in-this-project) and, if useful, add a **README.md** in the component folder.

---

## 11. Folder structure

All paths below are relative to the **TOMs plugin root** (the folder that contains `TOMsPlugin.py`, `README.md`, and the `DOCKER` folder).

### High-level Docker layout

```text
TOMs/
├── DATAMODEL/                    # SQL for database schema (used by postgis)
├── test/data/                    # Test data SQL (used by postgis)
└── DOCKER/
    ├── README_DOCKER_AND_DATABASE.md   # This document
    ├── pg_service/
    │   └── .pg_service.conf      # DB connection “address book”
    ├── postgis/                  # PostGIS database (core)
    │   ├── docker-compose.yml
    │   ├── dockerfile-toms-test-postgis
    │   ├── config/               # PostgreSQL config
    │   └── toms_test_db_init_scripts/
    ├── qgis/                     # QGIS desktop in Docker (multi-version)
    │   ├── README.md             # Full setup and usage
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   └── .env                  # QGIS_VERSION, BASE_IMAGE, USE_VNC
    ├── qgis_server_oq/          # QGIS Server (OpenQuake) + nginx; uses qgis-net by default (see Section 10 to use toms_net)
    │   ├── docker-compose.yml   # nginx:8010, qgis_server; volumes point at /home/QGIS/... (adapt for repo)
    │   └── nginx/
    ├── qgis_server_camptocamp/  # QGIS Server (Camptocamp) already on toms_net; port 8381
    │   ├── docker-compose.yml   # mounts ../pg_service, ../../QGIS/qgis_server
    │   └── dockerfile-toms-test-qgis-server-camptocamp
    ├── qwc2/                    # Web client (QWC2); nginx on 8012; uses toms_net
    │   ├── docker-compose.yml
    │   └── docker-compose-prod.yml
    └── lets_encrypt/            # SSL for production (e.g. QGIS Server domain)
        └── docker-compose*.yml
```

### PostGIS-specific structure (required for the database)

The **postgis** container expects these to exist:

| Path | Purpose |
|------|--------|
| **DATAMODEL/** | Schema SQL. Mounted as `/io/DATAMODEL` in the container. |
| **test/data/** | Test data SQL. Mounted as `/io/test/data`. |
| **DOCKER/postgis/docker-compose.yml** | Defines the postgis service, ports, volumes, network. |
| **DOCKER/postgis/dockerfile-toms-test-postgis** | Image definition (PostgreSQL + PostGIS). |
| **DOCKER/postgis/config/** | postgresql.conf, pg_hba.conf. Mounted as `/io/pg_config`. |
| **DOCKER/postgis/toms_test_db_init_scripts/** | First-run scripts; create TOMs_Test and run SQL. |

Mount mapping used by the compose file:

- `../../DATAMODEL` → `/io/DATAMODEL`
- `../../test/data` → `/io/test/data`
- `./config` → `/io/pg_config`
- `./toms_test_db_init_scripts` → `/docker-entrypoint-initdb.d`

### Checklist before first PostGIS run

- [ ] Plugin root contains **DATAMODEL** and **test/data**.
- [ ] **DOCKER/postgis** contains **docker-compose.yml**, **dockerfile-toms-test-postgis**, **config/** (with postgresql.conf and pg_hba.conf), and **toms_test_db_init_scripts/** with the expected `.sh` files.
- [ ] **DOCKER/pg_service/.pg_service.conf** exists if you want to use the TOMs_Test service name.

---

## 12. Adding or changing Docker services

Use this section when you introduce a **new** Docker service (e.g. a new server, worker, or tool) or change an existing one so the project stays understandable and consistent.

### Guidelines

1. **One component per folder**  
   Create a subfolder under **DOCKER/** (e.g. `DOCKER/my_service/`) with its own **docker-compose.yml** (and Dockerfile if needed).

2. **Use the shared network for database access**  
   If the service must talk to the TOMs database:
   - Use the **toms_net** external network.
   - In `docker-compose.yml`:  
     `networks: default: name: toms_net; external: true`  
     (or attach the service to a network that is connected to toms_net).
   - Connect to the database at **toms_postgis:5432**, database **TOMs_Test**.

3. **Document the component**  
   - Add a row to the [Docker components table](#1-docker-components-in-this-project) in this README (path, purpose, depends on, network).
   - If the component has non-trivial setup, add a **README.md** in its folder (e.g. like **DOCKER/qgis/README.md**). For **QGIS Server** integration, follow [Section 10](#10-integrating-qgis-server-or-another-service-with-the-toms-database).

4. **Connection file**  
   If the new service needs the same DB connection as others, mount **DOCKER/pg_service/.pg_service.conf** and set **PGSERVICEFILE** (and optionally **PGSERVICE=TOMs_Test**) in the service’s environment. Keep **pg_service.conf** in sync if you add new services or ports.

5. **Ports and env**  
   - Avoid port clashes with existing services (e.g. 5435, 6080, 5900).
   - Use env vars or an **.env** file for hostnames, ports, and secrets; document them in the component’s README or in this doc.

6. **Dependencies**  
   If the new service depends on PostGIS (or another TOMs container), say so in the component’s README and in the components table (e.g. “Start postgis first”).

### Example: adding a new service

- Create **DOCKER/my_tool/docker-compose.yml** that:
  - Uses `network: toms_net` (external).
  - Connects to **toms_postgis:5432** (or uses **PGSERVICEFILE** and **TOMs_Test**).
- Add **DOCKER/my_tool/README.md** with a short description and how to run it.
- In this file, add a row in [Section 1](#1-docker-components-in-this-project) for **my_tool**.

---

## 13. Troubleshooting

| Problem | What to check |
|--------|----------------|
| “Port already in use” or “address already in use” | Something else is using the port (e.g. **5435**) on your machine. Stop that program or change the port in the compose file (host side of the mapping). |
| “Cannot connect to database” from QGIS (on your Mac) | 1) Is the container running? `docker compose ps` in **DOCKER/postgis**. 2) Use **localhost** and port **5435**. 3) Database **TOMs_Test**, user/password as in init scripts or pg_service.conf. |
| “Cannot connect” from another container | That container must be on **toms_net**. Use host **toms_postgis**, port **5432**. Check the service’s compose file for `networks` and `toms_net`. |
| Database empty or tables missing | First run runs init scripts; if the container was recreated, inits run again (or restore from backup). Check `docker compose logs postgis` for errors. |
| Docker “cannot connect to the Docker daemon” | Docker Desktop (or Docker Engine) is not running. Start Docker and try again. |
| QGIS in Docker: form path / config not found | See **[DOCKER/qgis/README.md](qgis/README.md)**. The container sets **TOMs_CONFIG_PATH** and **TOMs_FORM_PATH**; the plugin uses these when present. |

---

## 14. Summary diagram

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  YOUR COMPUTER (Mac / Windows / Linux)                                    │
│                                                                          │
│   QGIS / pgAdmin / psql  ────── connect to ──────►  localhost : 5435     │
│   (or any app on your PC)                              │                 │
│                                                        │                 │
│  ┌────────────────────────────────────────────────────│────────────────┐ │
│  │  DOCKER                                              │                │ │
│  │                                                      ▼                │ │
│  │   ┌──────────────────────────────────────────────────────────────┐   │ │
│  │   │  Container: postgis (hostname: toms_postgis)                   │   │ │
│  │   │  • PostgreSQL + PostGIS                                        │   │ │
│  │   │  • Listens inside on port 5432                                 │   │ │
│  │   │  • Host port 5435 → container 5432                             │   │ │
│  │   │  • Database: TOMs_Test (created by init scripts on first run)  │   │ │
│  │   └──────────────────────────────────────────────────────────────┘   │ │
│  │                              │                                       │ │
│  │   Network: toms_net          │  Other containers (e.g. QGIS in      │ │
│  │                              │  Docker) connect to: toms_postgis:5432│ │
│  │                              ▼                                       │ │
│  │   ┌──────────────────────────────────────────────────────────────┐   │ │
│  │   │  Optional: QGIS container, QGIS Server, etc. (same network)   │   │ │
│  │   └──────────────────────────────────────────────────────────────┘   │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘

From your computer:  Host: localhost   Port: 5435   Database: TOMs_Test
From a container:    Host: toms_postgis   Port: 5432   Database: TOMs_Test
```

---

## 15. Quick reference

| I want to… | Command or action |
|------------|-------------------|
| Start the database | `cd DOCKER/postgis` then `docker compose up -d` |
| Stop the database | `cd DOCKER/postgis` then `docker compose stop` |
| Connect from my computer | **localhost**, port **5435**, database **TOMs_Test** |
| Connect from another container | Host **toms_postgis**, port **5432**, network **toms_net** |
| Run QGIS in Docker | See **[DOCKER/qgis/README.md](qgis/README.md)** (start postgis first) |
| Connection file | **DOCKER/pg_service/.pg_service.conf** (service name: TOMs_Test) |
| Integrate QGIS Server with TOMs DB | Follow [Section 10](#10-integrating-qgis-server-or-another-service-with-the-toms-database) (postgis first, then qgis_server_camptocamp or adapt qgis_server_oq). |
| Add a new Docker service | Follow [Section 12](#12-adding-or-changing-docker-services) and update the [components table](#1-docker-components-in-this-project). |

This document is the single place to understand how Docker and the database fit into TOMs, how to run each component (including QGIS Server), and how to extend the setup in the future.
