#!/bin/bash

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}Stopping Absensi Backend containers...${NC}"
docker compose down

echo -e "${GREEN}Containers stopped!${NC}"
