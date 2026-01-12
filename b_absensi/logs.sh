#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Viewing API logs...${NC}"
echo -e "${GREEN}Press Ctrl+C to exit${NC}"
echo ""

docker compose logs -f api
