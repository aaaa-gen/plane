# Despliegue de Plane en DigitalOcean con GitHub Actions

Este documento describe cómo configurar el despliegue automático de Plane.so en DigitalOcean usando GitHub Actions con un self-hosted runner.

## Arquitectura

```
┌─────────────────┐     push/dispatch     ┌──────────────────┐
│   GitHub Repo   │ ──────────────────────▶│  GitHub Actions  │
│   (services)    │                        │    Workflow      │
└─────────────────┘                        └────────┬─────────┘
                                                    │
                                                    │ self-hosted runner
                                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DigitalOcean Droplet                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  plane-web  │  │  plane-api  │  │ plane-worker│             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  plane-db   │  │ plane-redis │  │  plane-mq   │             │
│  │ (Postgres)  │  │  (Valkey)   │  │ (RabbitMQ)  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## Requisitos

### En DigitalOcean
- Droplet con Ubuntu 22.04+ (recomendado: 4GB RAM, 2 vCPUs mínimo)
- Docker y Docker Compose instalados
- Puerto 80/443 abiertos

### En GitHub
- Repositorio con los archivos de Plane
- Token de acceso personal con permisos `repo`

## Configuración Inicial

### 1. Crear el Droplet en DigitalOcean

```bash
# Crear un droplet básico (ajustar según necesidades)
doctl compute droplet create plane-server \
    --region nyc1 \
    --size s-2vcpu-4gb \
    --image ubuntu-22-04-x64 \
    --ssh-keys YOUR_SSH_KEY_FINGERPRINT
```

### 2. Configurar el Runner

Conectarse al droplet y ejecutar:

```bash
# Exportar variables necesarias
export GITHUB_OWNER="tu-usuario"
export GITHUB_REPO="services"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

# Descargar y ejecutar script de configuración
curl -sSL https://raw.githubusercontent.com/$GITHUB_OWNER/$GITHUB_REPO/main/plane/scripts/setup-runner.sh | sudo bash
```

O manualmente:

```bash
cd /home/agen/services/plane/scripts
chmod +x setup-runner.sh
sudo GITHUB_TOKEN="ghp_xxx" GITHUB_OWNER="tu-usuario" GITHUB_REPO="services" ./setup-runner.sh
```

### 3. Configurar Secrets en GitHub

Ir a `Settings > Secrets and variables > Actions` y crear:

| Secret | Descripción | Ejemplo |
|--------|-------------|---------|
| `PLANE_SECRET_KEY` | Clave secreta para la app | `$(openssl rand -hex 32)` |
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL | Contraseña segura |
| `RABBITMQ_PASSWORD` | Contraseña de RabbitMQ | Contraseña segura |
| `PLANE_DOMAIN` | Dominio de Plane | `plane.tudominio.com` |
| `AWS_ACCESS_KEY_ID` | Credenciales MinIO (opcional) | `access-key` |
| `AWS_SECRET_ACCESS_KEY` | Credenciales MinIO (opcional) | `secret-key` |

Generar claves seguras:

```bash
# Generar SECRET_KEY
openssl rand -hex 32

# Generar LIVE_SERVER_SECRET_KEY
openssl rand -base64 32
```

### 4. Configurar Environment en GitHub

Crear un environment llamado `production` en `Settings > Environments`:

1. Click en "New environment"
2. Nombre: `production`
3. Opcionalmente configurar:
   - Protection rules (required reviewers)
   - Deployment branches (solo main)

## Uso

### Despliegue Automático

El workflow se ejecuta automáticamente cuando:
- Se hace push a `main` con cambios en `plane/**`
- Se modifica `.github/workflows/deploy-plane.yml`

### Despliegue Manual

1. Ir a `Actions > Deploy Plane to DigitalOcean`
2. Click en "Run workflow"
3. Seleccionar:
   - **Environment**: production/staging
   - **Action**: deploy/restart/stop/logs

### Desde el Servidor (Script)

```bash
cd /home/agen/services/plane/scripts

# Desplegar
./deploy.sh deploy production

# Reiniciar
./deploy.sh restart

# Ver estado
./deploy.sh status

# Ver logs
./deploy.sh logs              # Todos
./deploy.sh logs api          # Solo API

# Backup manual
./deploy.sh backup

# Restaurar
./deploy.sh restore           # Último backup
./deploy.sh restore file.gz   # Archivo específico
```

## Estructura de Archivos

```
services/
├── .github/
│   └── workflows/
│       └── deploy-plane.yml    # Workflow de GitHub Actions
└── plane/
    ├── docker-compose.yml      # Compose principal
    ├── plane.env               # Variables locales
    ├── plane.env.production    # Variables producción
    ├── README.md               # Documentación general
    ├── DEPLOY.md               # Este archivo
    └── scripts/
        ├── deploy.sh           # Script de despliegue
        └── setup-runner.sh     # Configuración del runner
```

## Monitoreo

### Ver Estado del Runner

```bash
# En el servidor
cd /home/runner/actions-runner
./svc.sh status

# Ver logs del runner
journalctl -u actions.runner.* -f
```

### Ver Estado de Plane

```bash
# Todos los contenedores
docker compose -f /home/agen/services/plane/docker-compose.yml ps

# Recursos
docker stats

# Logs en tiempo real
docker compose -f /home/agen/services/plane/docker-compose.yml logs -f
```

## Backups

Los backups se guardan en `/home/agen/backups/plane/`:

```bash
# Listar backups
ls -la /home/agen/backups/plane/

# Restaurar manualmente
gunzip -c backup.sql.gz | docker exec -i plane-db psql -U plane plane
```

El workflow hace backup automático antes de cada despliegue.

## Troubleshooting

### El runner no aparece en GitHub

```bash
# Verificar estado
cd /home/runner/actions-runner
./svc.sh status

# Ver logs
journalctl -u "actions.runner.*" --since "1 hour ago"

# Reiniciar
./svc.sh stop
./svc.sh start
```

### Servicios no inician

```bash
# Ver logs de error
docker compose logs --tail=100

# Verificar redes
docker network ls

# Recrear redes
docker network create services_internal_net
docker network create services_database_net
```

### Base de datos corrupta

```bash
# Restaurar desde backup
cd /home/agen/services/plane/scripts
./deploy.sh restore

# O manualmente
BACKUP=$(ls -t /home/agen/backups/plane/*.gz | head -1)
gunzip -c "$BACKUP" | docker exec -i plane-db psql -U plane plane
```

### Actualizar imágenes de Plane

```bash
# Actualizar a última versión stable
cd /home/agen/services/plane/scripts
./deploy.sh update
```

## Seguridad

### Firewall (UFW)

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### Actualizar Sistema

```bash
sudo apt update && sudo apt upgrade -y
```

### Rotar Claves

1. Generar nuevas claves
2. Actualizar secrets en GitHub
3. Ejecutar deploy

## Recursos Recomendados

| Configuración | RAM | vCPUs | Usuarios |
|---------------|-----|-------|----------|
| Mínima        | 4GB | 2     | ~10      |
| Básica        | 8GB | 4     | ~50      |
| Producción    | 16GB| 8     | ~200     |

## Enlaces Útiles

- [Plane Documentation](https://docs.plane.so/)
- [GitHub Actions Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [DigitalOcean Docker](https://marketplace.digitalocean.com/apps/docker)
