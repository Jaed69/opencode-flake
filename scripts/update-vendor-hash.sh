#!/usr/bin/env bash
# Script para actualizar hashes de forma universal en package.nix
set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Buscando desajustes de hash..."

# Intentar construir y capturar la salida de error
BUILD_OUTPUT=$(nix build .#opencode 2>&1) || BUILD_FAILED=$?

if [ "${BUILD_FAILED:-0}" -ne 0 ]; then
    if echo "$BUILD_OUTPUT" | grep -q "hash mismatch"; then
        echo -e "${YELLOW}Desajuste detectado. Extrayendo hashes...${NC}"
        
        # Extraer el hash que Nix esperaba (specified) y el que obtuvo (got)
        OLD_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'specified:\s+\Ksha256-[A-Za-z0-9+/]+=*')
        NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*')
        
        if [ -n "$OLD_HASH" ] && [ -n "$NEW_HASH" ]; then
            echo -e "Reemplazando ${RED}$OLD_HASH${NC} por ${GREEN}$NEW_HASH${NC}"
            
            # Reemplazo global en package.nix (funciona para vendorHash, outputHash, etc.)
            sed -i "s|$OLD_HASH|$NEW_HASH|g" package.nix
            
            echo "Verificando construcción..."
            if nix build .#opencode; then
                echo -e "${GREEN}¡Construcción exitosa!${NC}"
                exit 0
            fi
        fi
    fi
    echo -e "${RED}No se pudo actualizar el hash automáticamente.${NC}"
    exit 1
fi

echo -e "${GREEN}No se requiere actualización.${NC}"
exit 0
