#!/bin/bash
# =============================================================================
# GitHub Actions Self-Hosted Runner Setup for DigitalOcean
# =============================================================================
# Este script configura un runner de GitHub Actions en un droplet de DigitalOcean
# Ejecutar como root o con sudo
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Variables - CONFIGURAR ANTES DE EJECUTAR
GITHUB_OWNER="${GITHUB_OWNER:-atorresgleza}"
GITHUB_REPO="${GITHUB_REPO:-services}"
RUNNER_NAME="${RUNNER_NAME:-do-runner-$(hostname)}"
RUNNER_LABELS="self-hosted,linux,digitalocean,docker"
RUNNER_USER="runner"
RUNNER_DIR="/home/${RUNNER_USER}/actions-runner"

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script debe ejecutarse como root"
   exit 1
fi

# Verificar token
if [ -z "$GITHUB_TOKEN" ]; then
    log_error "Variable GITHUB_TOKEN no configurada"
    echo "Genera un token en: https://github.com/settings/tokens"
    echo "El token necesita scope 'repo' para repositorios privados"
    echo ""
    echo "Uso: GITHUB_TOKEN=ghp_xxx ./setup-runner.sh"
    exit 1
fi

log "=== Configurando GitHub Actions Runner ==="
log "Owner: $GITHUB_OWNER"
log "Repo: $GITHUB_REPO"
log "Runner: $RUNNER_NAME"

# 1. Actualizar sistema
log "Actualizando sistema..."
apt-get update && apt-get upgrade -y

# 2. Instalar dependencias
log "Instalando dependencias..."
apt-get install -y \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https

# 3. Instalar Docker si no está instalado
if ! command -v docker &> /dev/null; then
    log "Instalando Docker..."
    
    # Añadir clave GPG oficial de Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Añadir repositorio
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
    
    log_success "Docker instalado"
else
    log_success "Docker ya está instalado"
fi

# 4. Crear usuario runner si no existe
if ! id "$RUNNER_USER" &>/dev/null; then
    log "Creando usuario $RUNNER_USER..."
    useradd -m -s /bin/bash "$RUNNER_USER"
    usermod -aG docker "$RUNNER_USER"
    log_success "Usuario $RUNNER_USER creado"
else
    usermod -aG docker "$RUNNER_USER"
    log_success "Usuario $RUNNER_USER ya existe"
fi

# 5. Crear directorio para el runner
log "Preparando directorio del runner..."
mkdir -p "$RUNNER_DIR"
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

# 6. Obtener token de registro del runner
log "Obteniendo token de registro..."
REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runners/registration-token" | jq -r '.token')

if [ "$REGISTRATION_TOKEN" == "null" ] || [ -z "$REGISTRATION_TOKEN" ]; then
    log_error "No se pudo obtener el token de registro"
    log_error "Verifica que GITHUB_TOKEN tiene los permisos correctos"
    exit 1
fi

log_success "Token de registro obtenido"

# 7. Descargar e instalar el runner
log "Descargando GitHub Actions Runner..."

cd "$RUNNER_DIR"

# Obtener la última versión
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
RUNNER_ARCH="x64"

if [ "$(uname -m)" == "aarch64" ]; then
    RUNNER_ARCH="arm64"
fi

RUNNER_FILE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_FILE}"

sudo -u "$RUNNER_USER" curl -sL "$RUNNER_URL" -o "$RUNNER_FILE"
sudo -u "$RUNNER_USER" tar xzf "$RUNNER_FILE"
rm "$RUNNER_FILE"

log_success "Runner descargado (v$RUNNER_VERSION)"

# 8. Configurar el runner
log "Configurando runner..."

sudo -u "$RUNNER_USER" ./config.sh \
    --url "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}" \
    --token "$REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work "_work" \
    --unattended \
    --replace

log_success "Runner configurado"

# 9. Instalar como servicio
log "Instalando como servicio..."

./svc.sh install "$RUNNER_USER"
./svc.sh start

log_success "Servicio instalado e iniciado"

# 10. Crear directorios para Plane
log "Preparando directorios para Plane..."
mkdir -p /home/agen/services/plane
mkdir -p /home/agen/backups/plane
chown -R "$RUNNER_USER:$RUNNER_USER" /home/agen/services
chown -R "$RUNNER_USER:$RUNNER_USER" /home/agen/backups

# 11. Crear redes de Docker necesarias
log "Creando redes de Docker..."
docker network create services_internal_net 2>/dev/null || true
docker network create services_database_net 2>/dev/null || true
docker network create services_external_net 2>/dev/null || true

log_success "Redes creadas"

# 12. Verificar estado
log "Verificando estado del runner..."
./svc.sh status

echo ""
log_success "=== Configuración completada ==="
echo ""
echo "El runner está configurado y ejecutándose."
echo "Verifica el estado en: https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/settings/actions/runners"
echo ""
echo "Comandos útiles:"
echo "  ./svc.sh status  - Ver estado del servicio"
echo "  ./svc.sh stop    - Detener el runner"
echo "  ./svc.sh start   - Iniciar el runner"
echo "  journalctl -u actions.runner.* -f  - Ver logs"
