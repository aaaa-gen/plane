# Plane.so Service

Plane.so es una herramienta de gestión de proyectos de código abierto. Este servicio está configurado para ejecutarse localmente usando Docker Compose e integrado con Traefik como reverse proxy.

## Configuración

### Variables de Entorno

El archivo `plane.env` contiene todas las variables de configuración. Las principales son:

- `APP_DOMAIN`: Dominio donde se accederá a Plane (por defecto: `plane.aaaagen.lan`)
- `APP_RELEASE`: Versión de Plane a usar (por defecto: `v1.1.0`)
- `WEB_URL`: URL completa de acceso (por defecto: `http://${APP_DOMAIN}`)
- `SECRET_KEY`: Clave secreta para la aplicación (cambiar en producción)
- `POSTGRES_PASSWORD`: Contraseña de la base de datos (cambiar en producción)
- `RABBITMQ_PASSWORD`: Contraseña de RabbitMQ (cambiar en producción)

### Servicios

Plane incluye los siguientes servicios:

- **web**: Frontend principal
- **space**: Espacios de trabajo
- **admin**: Panel de administración
- **api**: API backend
- **worker**: Procesador de tareas en segundo plano
- **beat-worker**: Programador de tareas
- **live**: Servidor WebSocket para actualizaciones en tiempo real
- **migrator**: Ejecuta migraciones de base de datos
- **plane-db**: Base de datos PostgreSQL
- **plane-redis**: Cache Redis/Valkey
- **plane-mq**: Message queue RabbitMQ
- **plane-minio**: Almacenamiento de objetos S3-compatible

## Uso

### Desde el directorio de Plane

```bash
# Cargar variables de entorno
cd /home/agen/services/plane
set -o allexport; source plane.env; set +o allexport

# Iniciar todos los servicios
docker compose up -d

# Ver logs
docker compose logs -f

# Detener servicios
docker compose down
```

### Desde el directorio maestro

```bash
# Cargar variables de entorno primero
cd /home/agen/services/plane
set -o allexport; source plane.env; set +o allexport
cd /home/agen/services

# Iniciar Plane junto con Traefik
docker compose --profile traefik -f docker-compose.yml -f plane/docker-compose.yml up -d
```

## Integración con Traefik

Plane está configurado para usar Traefik como reverse proxy. El proxy interno de Plane está deshabilitado. Las rutas están configuradas mediante labels de Traefik:

- Frontend principal: `http://${APP_DOMAIN}/`
- API: `http://${APP_DOMAIN}/api`
- Admin: `http://${APP_DOMAIN}/admin`
- Space: `http://${APP_DOMAIN}/space`
- WebSocket: `http://${APP_DOMAIN}/ws`

## Redes

- `internal_net`: Comunicación entre servicios de Plane y con Traefik
- `database_net`: Base de datos PostgreSQL (red interna)

## Volúmenes

- `pgdata`: Datos de PostgreSQL
- `redisdata`: Datos de Redis
- `uploads`: Archivos subidos (MinIO)
- `rabbitmq_data`: Datos de RabbitMQ
- `logs_*`: Logs de cada servicio

## Primera Ejecución

1. Asegúrate de que Traefik esté ejecutándose:
   ```bash
   docker compose --profile traefik up -d
   ```

2. Carga las variables de entorno:
   ```bash
   cd /home/agen/services/plane
   set -o allexport; source plane.env; set +o allexport
   ```

## Despliegue en Producción (DigitalOcean)

Para despliegue automatizado usando GitHub Actions con self-hosted runner, ver:

📖 **[DEPLOY.md](DEPLOY.md)** - Guía completa de despliegue en DigitalOcean

### Resumen rápido:

```bash
# 1. En el servidor de DigitalOcean, configurar el runner
export GITHUB_TOKEN="ghp_xxx"
export GITHUB_OWNER="usuario"
export GITHUB_REPO="services"
sudo -E ./scripts/setup-runner.sh

# 2. Configurar secrets en GitHub (Settings > Secrets)
# - PLANE_SECRET_KEY
# - POSTGRES_PASSWORD
# - PLANE_DOMAIN

# 3. Ejecutar el workflow desde GitHub Actions
# O manualmente en el servidor:
./scripts/deploy.sh deploy production
```

### Scripts disponibles:

| Script | Descripción |
|--------|-------------|
| `scripts/deploy.sh` | Despliegue, restart, backup, restore |
| `scripts/setup-runner.sh` | Configuración del runner de GitHub |

3. Inicia Plane:
   ```bash
   docker compose up -d
   ```

4. El migrator se ejecutará automáticamente en el primer inicio para configurar la base de datos.

5. Accede a Plane en:
   - Por Traefik (puerto 9000): `http://<IP_SERVIDOR>:9000`
     - 172.16.0.98:9000
     - 192.168.12.236:9000
     - 172.16.0.77:9000
   - Nota: Plane está expuesto a través de Traefik en el puerto 9000, no hay puertos directos

## Actualización

Para actualizar Plane a una nueva versión:

1. Edita `plane.env` y cambia `APP_RELEASE` a la nueva versión
2. Detén los servicios: `docker compose down`
3. Recarga las variables: `set -o allexport; source plane.env; set +o allexport`
4. Inicia los servicios: `docker compose up -d --pull always`

## Notas

- El proxy interno de Plane está deshabilitado ya que usamos Traefik
- Plane está expuesto a través de Traefik en el puerto 9000 (entrypoint "plane")
- Traefik maneja el enrutamiento de todos los servicios de Plane (web, api, space, admin, live)
- Asegúrate de cambiar las contraseñas por defecto en producción
- Para producción, considera usar bases de datos externas (PostgreSQL, Redis, RabbitMQ)
- Si accedes desde fuera de la red local, asegúrate de que el firewall permita el puerto 9000

