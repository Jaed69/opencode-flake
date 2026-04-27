#!/usr/bin/env bash
set -euo pipefail

# Colores para la salida
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Iniciando actualización automática de hashes..."

# Intentar construir y capturar el error
BUILD_OUTPUT=$(nix build .#opencode 2>&1) || BUILD_FAILED=$?

if [ "${BUILD_FAILED:-0}" -ne 0 ]; then
    # Verificar si es un error de desajuste de hash
    if echo "$BUILD_OUTPUT" | grep -q "hash mismatch"; then
        echo -e "${YELLOW}Se detectó un desajuste de hash. Extrayendo valores...${NC}"
        
        # Extraer el hash antiguo (specified) y el nuevo (got)
        OLD_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'specified:\s+\Ksha256-[A-Za-z0-9+/]+=*')
        NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*')
        
        if [ -z "$OLD_HASH" ] || [ -z "$NEW_HASH" ]; then
            echo -e "${RED}No se pudieron extraer los hashes del error.${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Reemplazando:${NC} $OLD_HASH"
        echo -e "${GREEN}Por el nuevo:${NC} $NEW_HASH"
        
        # Reemplazo universal en package.nix
        sed -i "s|$OLD_HASH|$NEW_HASH|g" package.nix
        
        echo -e "${GREEN}Verificando construcción con el nuevo hash...${NC}"
        if nix build .#opencode; then
            echo -e "${GREEN}¡Construcción exitosa con el hash actualizado!${NC}"
            exit 0
        else
            echo -e "${RED}La construcción volvió a fallar. Puede haber otro hash pendiente.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}El fallo no parece ser por un desajuste de hash.${NC}"
        echo "$BUILD_OUTPUT"
        exit 1
    fi
fi

echo -e "${GREEN}No se necesitan actualizaciones de hash.${NC}"
exit 0
