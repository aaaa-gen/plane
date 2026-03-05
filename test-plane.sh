#!/bin/bash
# Script de pruebas para Plane.so
# Ejecuta pruebas de conectividad y salud desde un contenedor temporal

set +e  # No salir en error para continuar con todas las pruebas

echo "=========================================="
echo "  Plane.so Health Check & Tests"
echo "=========================================="
echo ""

# Crear contenedor temporal si no existe
if ! docker ps | grep -q plane-test; then
    echo "📦 Creando contenedor de pruebas..."
    docker run -d --name plane-test --network services_internal_net --rm curlimages/curl:latest sleep 3600 > /dev/null 2>&1
    sleep 2
fi

echo "✅ Contenedor de pruebas listo"
echo ""

# Función para probar endpoint
test_endpoint() {
    local name=$1
    local url=$2
    echo "🔍 Testing: $name"
    local status=$(docker exec plane-test curl -s -w "%{http_code}" -o /dev/null "$url")
    if [ "$status" = "200" ] || [ "$status" = "401" ]; then
        echo "   ✅ $name - HTTP $status"
        return 0
    else
        echo "   ❌ $name - HTTP $status"
        return 1
    fi
}

# Función para probar conectividad de red
test_connectivity() {
    local name=$1
    local host=$2
    local port=$3
    echo "🔍 Testing: $name ($host:$port)"
    if docker exec plane-test nc -zv "$host" "$port" > /dev/null 2>&1; then
        echo "   ✅ $name - Conectividad OK"
        return 0
    else
        echo "   ❌ $name - Sin conectividad"
        return 1
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  API Endpoints"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_endpoint "Health Check" "http://plane-api:8000/"
test_endpoint "Instances API" "http://plane-api:8000/api/instances/"
test_endpoint "Users API (auth required)" "http://plane-api:8000/api/users/me/"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Frontend Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_endpoint "Web Frontend" "http://plane-web:3000/"
test_endpoint "Space Service" "http://plane-space:80/"
test_endpoint "Admin Service" "http://plane-admin:80/"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Backend Services Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
test_connectivity "PostgreSQL" "plane-db" "5432"
test_connectivity "Redis/Valkey" "plane-redis" "6379"
test_connectivity "RabbitMQ" "plane-mq" "5672"
test_connectivity "MinIO" "plane-minio" "9000"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Detailed API Response"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Health Check Response:"
docker exec plane-test curl -s http://plane-api:8000/ | docker exec -i plane-test sh -c "cat"
echo ""
echo ""
echo "Instance Configuration:"
docker exec plane-test curl -s http://plane-api:8000/api/instances/ | docker exec -i plane-test sh -c "cat" | head -c 500
echo "..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Todas las pruebas completadas"
echo ""
echo "Para ver logs en tiempo real:"
echo "  docker compose logs -f api"
echo ""
echo "Para acceder a Plane:"
echo "  http://172.16.0.98:9000"
echo ""
echo "Credenciales de administrador:"
echo "  Email: admin@plane.local"
echo "  Password: admin123"
echo ""

