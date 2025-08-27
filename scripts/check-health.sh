#!/bin/bash

# Gander Social Hybrid Setup - Health Check Script
# This script checks the status of all services

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HYBRID_ROOT="$SCRIPT_DIR/.."

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if a service is running
check_service() {
    local url=$1
    local name=$2
    
    if curl -s -f "$url" >/dev/null 2>&1 || curl -s -f "$url/health" >/dev/null 2>&1; then
        print_status "$name is running at $url"
        return 0
    else
        print_error "$name is not responding at $url"
        return 1
    fi
}

# Check Docker services
check_docker_services() {
    echo ""
    echo "Docker Services Status:"
    echo "----------------------"
    
    cd "$HYBRID_ROOT/docker"
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        return 1
    fi
    
    # Get container status
    local containers=$(docker-compose ps --format json 2>/dev/null || echo "[]")
    
    if [ "$containers" = "[]" ] || [ -z "$containers" ]; then
        print_error "No Docker containers running"
        return 1
    fi
    
    # Check each database
    echo ""
    echo "Database Connections:"
    
    # PLC Database
    if docker exec gander-plc-db pg_isready -U plc -d plc_dev >/dev/null 2>&1; then
        print_status "PLC Database (port 5433)"
    else
        print_error "PLC Database (port 5433)"
    fi
    
    # PDS Database
    if docker exec gander-pds-db pg_isready -U pds -d pds_dev >/dev/null 2>&1; then
        print_status "PDS Database (port 5434)"
    else
        print_error "PDS Database (port 5434)"
    fi
    
    # AppView Database
    if docker exec gander-appview-db pg_isready -U appview -d appview_dev >/dev/null 2>&1; then
        print_status "AppView Database (port 5435)"
    else
        print_error "AppView Database (port 5435)"
    fi
    
    # Redis
    if docker exec gander-redis redis-cli ping >/dev/null 2>&1; then
        print_status "Redis (port 6379)"
    else
        print_error "Redis (port 6379)"
    fi
}

# Check AT Protocol services
check_atprotocol_services() {
    echo ""
    echo "AT Protocol Services Status:"
    echo "---------------------------"
    
    # Check if dev-env is running
    if [ -f "$HYBRID_ROOT/dev-env.pid" ]; then
        PID=$(cat "$HYBRID_ROOT/dev-env.pid")
        if ps -p $PID > /dev/null 2>&1; then
            print_status "Dev-env process is running (PID: $PID)"
        else
            print_error "Dev-env process is not running"
            return 1
        fi
    else
        print_warning "Dev-env PID file not found"
    fi
    
    echo ""
    
    # Check each service endpoint
    check_service "http://localhost:2582" "PLC (DID Registry)"
    check_service "http://localhost:2583" "PDS (Personal Data Server)"
    check_service "http://localhost:2584" "AppView (Gndr)"
    
    # Check WebSocket endpoint
    echo ""
    if curl -s -f -H "Connection: Upgrade" -H "Upgrade: websocket" "http://localhost:2470" 2>&1 | grep -q "Bad Request\|Upgrade Required"; then
        print_status "BGS WebSocket is available at ws://localhost:2470"
    else
        print_warning "BGS WebSocket status unknown (this is often normal)"
    fi
}

# Check disk usage
check_disk_usage() {
    echo ""
    echo "Data Storage:"
    echo "-------------"
    
    # Check Docker volume sizes
    echo "Docker Volumes:"
    docker volume ls --format "table {{.Name}}\t{{.Size}}" | grep gander || echo "  No Gander volumes found"
    
    # Check local data directory
    if [ -d "$HYBRID_ROOT/data" ]; then
        echo ""
        echo "Local Data Directory:"
        du -sh "$HYBRID_ROOT/data"/* 2>/dev/null | sed 's/^/  /' || echo "  No data yet"
    fi
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     Gander Social Hybrid Setup - Health Check        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    
    check_docker_services
    check_atprotocol_services
    check_disk_usage
    
    echo ""
    echo "═══════════════════════════════════════════════════════"
}

main
