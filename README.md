# Plane.so Docker Deployment

Gestión de proyectos open source usando el Traefik compartido del proyecto gateway.

## Requisitos

- Docker y Docker Compose
- Gateway desplegado y corriendo en el runner (publica Traefik y la red `traefik`)
- Certificados SSL configurados con Cloudflare

## Instalación

```bash
# 1. Copiar y configurar variables
cp plane.env.example plane.env
nano plane.env  # Editar valores

# 2. Iniciar
docker compose up -d

# 3. Ver logs
docker compose logs -f
```

## Dependencia de Infraestructura

El deploy de Plane en producción valida que el contenedor `traefik` del proyecto gateway esté activo. Si no lo está, el workflow falla para evitar un despliegue sin enrutamiento público.

## Configuración Requerida

Edita `plane.env`:

```bash
APP_DOMAIN=plane.tudominio.com
SECRET_KEY=<openssl rand -hex 32>
LIVE_SERVER_SECRET_KEY=<openssl rand -hex 32>
POSTGRES_PASSWORD=contraseña-segura
RABBITMQ_PASSWORD=contraseña-segura
AWS_ACCESS_KEY_ID=minio-access-key
AWS_SECRET_ACCESS_KEY=minio-secret-key
```

## Servicios

| Servicio | Descripción |
|----------|-------------|
| web | Frontend principal |
| api | Backend API |
| space | Espacios públicos |
| admin | Panel de administración (god-mode) |
| live | WebSocket real-time |
| worker | Background jobs |
| plane-db | PostgreSQL |
| plane-redis | Redis cache |
| plane-mq | RabbitMQ |
| plane-minio | S3 storage |

## URLs

- **App:** `https://APP_DOMAIN/`
- **Admin:** `https://APP_DOMAIN/god-mode`
- **API:** `https://APP_DOMAIN/api`

## Comandos

```bash
# Detener
docker compose down

# Reiniciar
docker compose restart

# Ver estado
docker compose ps

# Backup BD
docker exec plane-db pg_dump -U plane plane > backup.sql
```

