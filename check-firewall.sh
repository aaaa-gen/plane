#!/bin/bash
# Script para verificar y configurar firewall para Plane.so

echo "=== Verificación de Firewall para Puerto 9000 ==="
echo ""

# Verificar UFW
echo "1. Estado de UFW:"
if command -v ufw &> /dev/null; then
    sudo ufw status verbose
    echo ""
    read -p "¿Permitir puerto 9000 en UFW? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo ufw allow 9000/tcp
        sudo ufw reload
        echo "✅ Puerto 9000 permitido en UFW"
    fi
else
    echo "UFW no está instalado"
fi
echo ""

# Verificar iptables
echo "2. Reglas de iptables para puerto 9000:"
echo "   INPUT:"
sudo iptables -L INPUT -n -v | grep 9000 || echo "   No hay reglas para puerto 9000 en INPUT"
echo "   DOCKER:"
sudo iptables -L DOCKER -n -v 2>/dev/null | grep 9000 || echo "   No hay reglas para puerto 9000 en DOCKER"
echo ""

# Verificar NAT de Docker
echo "3. Reglas NAT de Docker:"
sudo iptables -t nat -L -n -v | grep 9000 || echo "   No hay reglas NAT para puerto 9000"
echo ""

# Verificar si el puerto está escuchando
echo "4. Puerto escuchando:"
sudo netstat -tlnp 2>/dev/null | grep :9000 || sudo ss -tlnp 2>/dev/null | grep :9000 || echo "   Puerto 9000 no está escuchando"
echo ""

# Opción para agregar regla
read -p "¿Agregar regla de iptables para puerto 9000? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    sudo iptables -A INPUT -p tcp --dport 9000 -j ACCEPT
    echo "✅ Regla agregada. Para hacerla permanente:"
    echo "   sudo iptables-save > /etc/iptables/rules.v4"
fi

echo ""
echo "=== Verificación completada ==="
