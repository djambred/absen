#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Starting Absensi Backend (Docker)  ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check if docker compose is available (v2 or v1)
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

# Stop existing containers
echo -e "${YELLOW}Stopping existing containers...${NC}"
$COMPOSE_CMD down

# Build and start containers
echo -e "${YELLOW}Building and starting containers...${NC}"
$COMPOSE_CMD up --build -d

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 10

# Check container status
echo ""
echo -e "${GREEN}Container Status:${NC}"
$COMPOSE_CMD ps

# Show logs
echo ""
echo -e "${GREEN}Application Logs (last 20 lines):${NC}"
$COMPOSE_CMD logs --tail=20 api

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Backend is running!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "API URL: ${YELLOW}http://localhost:8000${NC}"
echo -e "API Docs: ${YELLOW}http://localhost:8000/docs${NC}"
echo -e "Database: ${YELLOW}localhost:13306${NC}"
echo ""
echo -e "Commands:"
echo -e "  View logs:    ${YELLOW}docker compose logs -f api${NC}"
echo -e "  Stop:         ${YELLOW}docker compose down${NC}"
echo -e "  Restart:      ${YELLOW}docker compose restart api${NC}"
echo -e "  Shell access: ${YELLOW}docker compose exec api bash${NC}"
echo ""
echo -e "${GREEN}Auto-checkout scheduler: Runs daily at 00:00 WIB${NC}"
echo ""
