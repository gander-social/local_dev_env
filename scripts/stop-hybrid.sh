#!/bin/bash

# Gander Social Hybrid Setup - Stop Script
# This script stops all services

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

# Stop dev-env
stop_dev_env() {
    print_info "Stopping AT Protocol dev environment..."
    
    if [ -f "$HYBRID_ROOT/dev-env.pid" ]; then
        PID=$(cat "$HYBRID_ROOT/dev-env.pid")
        if ps -p $PID > /dev/null 2>&1; then
            print_info "Stopping dev-env (PID: $PID)..."
            kill $PID 2>/dev/null || true
            
            # Wait for process to stop
            local count=0
            while ps -p $PID > /dev/null 2>&1 && [ $count -lt 10 ]; do
                sleep 1
                ((count++))
            done
            
            # Force kill if still running
            if ps -p $PID > /dev/null 2>&1; then
                print_warning "Force stopping dev-env..."
                kill -9 $PID 2>/dev/null || true
            fi
            
            print_status "Dev-env stopped"
        else
            print_warning "Dev-env process not found"
        fi
        rm -f "$HYBRID_ROOT/dev-env.pid"
    else
        print_warning "No dev-env PID file found"
    fi
    
    # Clean up the temporary script
    rm -f "$HYBRID_ROOT/start-dev-env-process.sh"
}

# Stop Docker services
stop_docker_services() {
    print_info "Stopping Docker services..."
    
    cd "$HYBRID_ROOT/docker"
    
    if docker-compose ps -q | grep -q .; then
        docker-compose down
        print_status "Docker services stopped"
    else
        print_warning "No Docker services running"
    fi
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       Gander Social Hybrid Setup - Stop Script       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    
    stop_dev_env
    stop_docker_services
    
    echo ""
    print_status "All services stopped"
    echo ""
    echo "Data is preserved in:"
    echo "  - Docker volumes (databases)"
    echo "  - $HYBRID_ROOT/data (PDS data)"
}

main
