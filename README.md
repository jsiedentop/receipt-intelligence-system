## Receipt Intelligence System

### Documentation

- [Initial Requirements](docs/requirements.md)
- [Project Specification](docs/specs.md)
- [Architecture Decision Record](docs/adr.md)

### Docker Compose

The repository includes a root `docker-compose.yml` that starts:

- `ris_extract` on `http://localhost:8081`
- `ris_backend` on `http://localhost:8080`
- `ris_ui` (Flutter Web via nginx) on `http://localhost:8082`

Compose builds the services when needed.

Setup `.env` file:

```bash
cp default.env .env
```

Then edit `.env` and add your OpenAI token:

```env
OPEN_AI_TOKEN=your-token
```

Alternatively, you can edit the docker compose file to use the OPEN_AI_TOKEN variable from your system environment: 

```docker-compose
  #environment:
  #  OPEN_AI_TOKEN: ${OPEN_AI_TOKEN:-}
  env_file: ./.env
```

Start everything:

```bash
docker compose up --build
```

Run in background:

```bash
docker compose up --build -d
```

Stop everything:

```bash
docker compose down
```

Persistent host data is stored under:

- `./data/backend`
- `./data/extract`

The backend database and receipt images are stored in `./data/backend`.
The extract model cache is stored in `./data/extract/model-cache`.

### Development

You can start only the `ris_extract` service via Docker Compose and run everything else via the `launch.json` configuration in VSCode:

```bash
docker compose up ris_extract --build
```

Then start the remaining services (`ris_backend` and `ris_ui`) using the VSCode debugger with your configured `launch.json` settings.

