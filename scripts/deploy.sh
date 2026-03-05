#!/bin/bash
# =============================================================================
# Plane Deployment Script for DigitalOcean
# =============================================================================
# Este script puede ejecutarse manualmente o desde GitHub Actions
# Uso: ./deploy.sh [action] [environment]
#   actions: deploy, restart, stop, status, logs, backup, restore
#   environment: production, staging (default: production)
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANE_DIR="${PLANE_DIR:-$SCRIPT_DIR}"
BACKUP_DIR="/home/agen/backups/plane"
LOG_FILE="/var/log/plane-deploy.log"

# Funciones de utilidad
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "$1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "✓ $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "⚠ $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE" 2>/dev/null || echo "✗ $1"
}

# Verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker no está instalado"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose no está disponible"
        exit 1
    fi
    
    log_success "Dependencias verificadas"
}

# Cargar variables de entorno
load_env() {
    local env_file="$PLANE_DIR/plane.env"
    
    if [ "$1" == "production" ] && [ -f "$PLANE_DIR/plane.env.production" ]; then
        env_file="$PLANE_DIR/plane.env.production"
        log "Usando configuración de producción"
    fi
    
    if [ -f "$env_file" ]; then
        set -o allexport
        source "$env_file"
        set +o allexport
        log_success "Variables de entorno cargadas desde $env_file"
    else
        log_error "Archivo de configuración no encontrado: $env_file"
        exit 1
    fi
}

# Crear redes de Docker
create_networks() {
    log "Creando redes de Docker..."
    
    docker network create services_internal_net 2>/dev/null && log_success "Red services_internal_net creada" || true
    docker network create services_database_net 2>/dev/null && log_success "Red services_database_net creada" || true
    docker network create services_external_net 2>/dev/null && log_success "Red services_external_net creada" || true
}

# Backup de la base de datos
backup_database() {
    log "Creando backup de la base de datos..."
    
    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/plane_${timestamp}.sql"
    
    if docker ps -q -f name=plane-db | grep -q .; then
        docker exec plane-db pg_dump -U "${POSTGRES_USER:-plane}" "${POSTGRES_DB:-plane}" > "$backup_file"
        
        if [ -f "$backup_file" ] && [ -s "$backup_file" ]; then
            # Comprimir backup
            gzip "$backup_file"
            log_success "Backup creado: ${backup_file}.gz"
            
            # Mantener solo los últimos 7 backups
            ls -t "$BACKUP_DIR"/*.gz 2>/dev/null | tail -n +8 | xargs -r rm
        else
            log_error "El backup está vacío o falló"
            return 1
        fi
    else
        log_warning "Contenedor de base de datos no está corriendo, saltando backup"
    fi
}

# Restaurar base de datos
restore_database() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        # Usar el backup más reciente
        backup_file=$(ls -t "$BACKUP_DIR"/*.gz 2>/dev/null | head -1)
        if [ -z "$backup_file" ]; then
            log_error "No se encontraron backups para restaurar"
            return 1
        fi
    fi
    
    log "Restaurando base de datos desde: $backup_file"
    
    if docker ps -q -f name=plane-db | grep -q .; then
        gunzip -c "$backup_file" | docker exec -i plane-db psql -U "${POSTGRES_USER:-plane}" "${POSTGRES_DB:-plane}"
        log_success "Base de datos restaurada"
    else
        log_error "Contenedor de base de datos no está corriendo"
        return 1
    fi
}

# Desplegar servicios
deploy() {
    log "=== Iniciando despliegue de Plane ==="
    
    cd "$PLANE_DIR"
    
    create_networks
    
    # Crear backup antes del deploy
    backup_database || true
    
    log "Descargando imágenes..."
    docker compose pull --quiet
    
    log "Deteniendo servicios existentes..."
    docker compose down --remove-orphans 2>/dev/null || true
    
    log "Iniciando servicios..."
    docker compose up -d
    
    log "Esperando a que los servicios estén listos..."
    sleep 30
    
    health_check
    
    log_success "=== Despliegue completado ==="
}

# Reiniciar servicios
restart() {
    log "Reiniciando servicios de Plane..."
    cd "$PLANE_DIR"
    docker compose restart
    log_success "Servicios reiniciados"
    status
}

# Detener servicios
stop() {
    log "Deteniendo servicios de Plane..."
    cd "$PLANE_DIR"
    docker compose down
    log_success "Servicios detenidos"
}

# Estado de los servicios
status() {
    log "Estado de los servicios:"
    cd "$PLANE_DIR"
    docker compose ps
    echo ""
    log "Uso de recursos:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker compose ps -q) 2>/dev/null || true
}

# Mostrar logs
show_logs() {
    local service="$1"
    cd "$PLANE_DIR"
    
    if [ -n "$service" ]; then
        docker compose logs -f --tail=100 "$service"
    else
        docker compose logs -f --tail=100
    fi
}

# Health check
health_check() {
    log "Ejecutando health checks..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec plane-api curl -s -f http://localhost:8000/api/v1/license/configuration/ > /dev/null 2>&1; then
            log_success "API está respondiendo correctamente"
            break
        fi
        
        log "Esperando API... ($attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "API no responde después de $max_attempts intentos"
        log "Logs de errores:"
        docker compose logs --tail=50 api
        return 1
    fi
    
    # Verificar todos los servicios
    cd "$PLANE_DIR"
    local unhealthy=$(docker compose ps | grep -c "unhealthy\|Exit" || true)
    
    if [ "$unhealthy" -gt 0 ]; then
        log_warning "Hay $unhealthy servicios con problemas"
        docker compose ps
        return 1
    fi
    
    log_success "Todos los servicios están saludables"
}

# Actualizar servicios
update() {
    log "=== Actualizando Plane ==="
    
    cd "$PLANE_DIR"
    
    backup_database
    
    log "Descargando nuevas imágenes..."
    docker compose pull
    
    log "Recreando servicios..."
    docker compose up -d --force-recreate
    
    sleep 30
    health_check
    
    log_success "=== Actualización completada ==="
}

# Limpiar recursos no utilizados
cleanup() {
    log "Limpiando recursos de Docker no utilizados..."
    
    docker system prune -f
    docker volume prune -f
    
    log_success "Limpieza completada"
}

# Mostrar ayuda
show_help() {
    echo "Plane Deployment Script"
    echo ""
    echo "Uso: $0 [comando] [opciones]"
    echo ""
    echo "Comandos:"
    echo "  deploy      Desplegar/actualizar Plane"
    echo "  restart     Reiniciar todos los servicios"
    echo "  stop        Detener todos los servicios"
    echo "  status      Mostrar estado de los servicios"
    echo "  logs [srv]  Mostrar logs (opcional: servicio específico)"
    echo "  backup      Crear backup de la base de datos"
    echo "  restore [f] Restaurar base de datos (opcional: archivo)"
    echo "  update      Actualizar imágenes y reiniciar"
    echo "  health      Verificar salud de los servicios"
    echo "  cleanup     Limpiar recursos de Docker no utilizados"
    echo "  help        Mostrar esta ayuda"
    echo ""
    echo "Entornos:"
    echo "  production  Usar plane.env.production"
    echo "  staging     Usar plane.env (por defecto)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 deploy production"
    echo "  $0 logs api"
    echo "  $0 backup"
}

# Main
main() {
    local action="${1:-help}"
    local environment="${2:-staging}"
    
    case "$action" in
        deploy)
            check_dependencies
            load_env "$environment"
            deploy
            ;;
        restart)
            load_env "$environment"
            restart
            ;;
        stop)
            load_env "$environment"
            stop
            ;;
        status)
            load_env "$environment"
            status
            ;;
        logs)
            load_env "$environment"
            show_logs "$2"
            ;;
        backup)
            load_env "$environment"
            backup_database
            ;;
        restore)
            load_env "$environment"
            restore_database "$2"
            ;;
        update)
            check_dependencies
            load_env "$environment"
            update
            ;;
        health)
            load_env "$environment"
            health_check
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Comando desconocido: $action"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
