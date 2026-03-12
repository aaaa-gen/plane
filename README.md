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
GOOGLE_CLIENT_ID=tu-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=tu-client-secret
IS_GOOGLE_ENABLED=1
```

## Google OAuth

Plane soporta Google OAuth por variables de entorno. En este repo el deploy ya propaga `GOOGLE_CLIENT_ID` y `GOOGLE_CLIENT_SECRET` desde GitHub Actions al contenedor backend, y activa `IS_GOOGLE_ENABLED=1` automáticamente cuando ambos valores existen.

1. En Google Cloud Console crea un OAuth Client ID de tipo **Web application**.
2. Configura estos valores en el cliente OAuth:
	- **Authorized JavaScript origin:** `https://APP_DOMAIN`
	- **Authorized redirect URI:** `https://APP_DOMAIN/auth/google/callback/`
	- **Authorized redirect URI (mobile):** `https://APP_DOMAIN/auth/mobile/google/callback/`
3. Guarda estas credenciales en GitHub como secrets:
	- **Repository Secret:** `GOOGLE_CLIENT_ID`
	- **Repository Secret:** `GOOGLE_CLIENT_SECRET`
4. Ejecuta el workflow de deploy o vuelve a desplegar `main`.
5. Verifica en `https://APP_DOMAIN/` que aparezca la opción `Sign in with Google`.
6. Si ya tenías Plane desplegado y no aparece, entra a `https://APP_DOMAIN/god-mode` → **Authentication** → **Google** y confirma que esté habilitado.

Notas:
- Para que OAuth funcione, `APP_DOMAIN` debe resolver públicamente por HTTPS.
- Este stack ya enruta `/auth` al backend API, por lo que no hace falta cambiar Traefik para Google OAuth.
- Plane espera el callback web con barra final: `https://APP_DOMAIN/auth/google/callback/`.
- En este repo puedes guardar ambos (`GOOGLE_CLIENT_ID` y `GOOGLE_CLIENT_SECRET`) como GitHub Secrets.

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

