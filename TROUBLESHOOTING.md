# Troubleshooting Plane - Botón "Get started" no funciona

## Problema
El botón "Get started" en la interfaz de Plane no hace nada al hacer clic.

## Causa
El botón intenta crear un workspace mediante una petición POST a la API, pero falla silenciosamente debido a:
1. **Problemas de CSRF**: El frontend necesita obtener y usar tokens CSRF para peticiones POST
2. **Autenticación requerida**: Algunos endpoints requieren autenticación incluso para crear el primer workspace
3. **Configuración de CORS**: Aunque CORS está configurado, puede haber problemas con las peticiones POST

## Solución Temporal: Crear Workspace Manualmente

Ya se ha creado un workspace manualmente:

```bash
cd /home/agen/services/plane
docker compose exec api python manage.py shell << 'EOF'
from plane.db.models import Workspace, WorkspaceMember
from django.contrib.auth import get_user_model
User = get_user_model()

admin = User.objects.first()
workspace = Workspace.objects.first()

if admin and workspace:
    member, created = WorkspaceMember.objects.get_or_create(
        workspace=workspace,
        member=admin,
        defaults={'role': 20}  # Owner
    )
    print(f"Workspace: {workspace.name}")
    print(f"Owner: {admin.email}")
EOF
```

## Solución Permanente

### Opción 1: Iniciar sesión directamente
1. Accede a `http://172.16.0.98:9000`
2. Inicia sesión con:
   - Email: `admin@plane.local`
   - Password: `admin123`
3. Una vez dentro, deberías ver el workspace "My Workspace"

### Opción 2: Verificar configuración del frontend
El frontend necesita saber dónde está la API. Verifica que:
- `WEB_URL` esté configurado correctamente en `plane.env`
- El frontend pueda acceder a la API en `http://api:8000` (dentro de Docker) o a través de Traefik

### Opción 3: Habilitar DEBUG para ver errores
Edita `plane.env` y cambia:
```
DEBUG=1
```

Luego reinicia los servicios:
```bash
docker compose restart api web
```

Esto mostrará más información de errores en los logs.

## Verificación

Para verificar que todo está funcionando:

```bash
# Verificar workspaces
docker compose exec api python manage.py shell -c "from plane.db.models import Workspace; print(f'Workspaces: {Workspace.objects.count()}')"

# Verificar estado de la instancia
curl -s http://172.16.0.98:9000/api/instances/ | jq '.instance.workspaces_exist'
```

## Notas

- El workspace "My Workspace" ya está creado
- El usuario `admin@plane.local` es el owner del workspace
- Una vez que inicies sesión, deberías poder acceder al workspace directamente

