#!/bin/bash

# Gander Social Hybrid Setup - Main Start Script
# This script starts Docker services and then the native dev-env

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
HYBRID_ROOT="$PROJECT_ROOT/MacGanderDocker"
ATPROTO_ROOT="$PROJECT_ROOT/gander-social-atproto"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_info "Starting the environment using: $ATPROTO_ROOT AND $HYBRID_ROOT. Script dir is $SCRIPT_DIR. Project root is $PROJECT_ROOT"

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    print_status "Docker is running"
}

# Start Docker services
start_docker_services() {
    print_info "Starting Docker services (Postgres & Redis)..."
    
    cd "$HYBRID_ROOT/docker"
    
    # Stop any existing containers
    docker-compose down 2>/dev/null || true
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be healthy
    print_info "Waiting for services to be healthy..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps | grep -q "unhealthy\|starting"; then
            echo -n "."
            sleep 2
            ((attempt++))
        else
            echo ""
            print_status "All Docker services are healthy"
            return 0
        fi
    done
    
    print_error "Services failed to become healthy"
    docker-compose ps
    return 1
}

# Check if gander-social-atproto exists
check_atproto() {
    if [ ! -d "$ATPROTO_ROOT" ]; then
        print_error "gander-social-atproto not found at $ATPROTO_ROOT"
        exit 1
    fi
    
    if [ ! -d "$ATPROTO_ROOT/packages/dev-env" ]; then
        print_error "dev-env package not found in gander-social-atproto"
        exit 1
    fi
    
    print_status "Found gander-social-atproto"
}

# Create data directories
create_data_dirs() {
    print_info "Creating data directories..."
    mkdir -p "$HYBRID_ROOT/data/pds/blocks"
    mkdir -p "$HYBRID_ROOT/data/logs"
    print_status "Data directories created"
}

# Export environment variables
setup_environment() {
    print_info "Setting up environment variables..."
    
    # Source the hybrid environment file
    set -a
    source "$HYBRID_ROOT/config/env.hybrid"
    set +a
    
    # Override data directory to use hybrid-setup location
    export PDS_DATA_DIRECTORY="$HYBRID_ROOT/data/pds"
    export PDS_BLOBSTORE_DISK_LOCATION="$HYBRID_ROOT/data/pds/blocks"
    
    print_status "Environment configured"
}

# Ensure .env.dev variables are loaded
load_env_dev() {
    print_info "Loading .env.dev variables..."
    set -a
    source "$ATPROTO_ROOT/packages/dev-env/.env.dev"
    set +a
    print_status ".env.dev variables loaded"
}

# Initialize environment variables
initialize_env_variables() {
    print_info "Initializing environment variables..."

    export PLC_DATABASE_URL="postgres://plc:plc@localhost:5433/plc_dev"
    export PDS_DATABASE_URL="postgres://pds:pds@localhost:5434/pds_dev"
    export GNDR_DATABASE_URL="postgres://gndr:gndr@localhost:5435/gndr_dev"
    export REDIS_URL="redis://localhost:6379"

    print_status "Environment variables initialized"
}

# Start the dev-env
start_dev_env() {
    print_info "Starting AT Protocol dev environment..."

    load_env_dev
    initialize_env_variables

    cd "$ATPROTO_ROOT/packages/dev-env"

    # Ensure NODE_ENV is set to development
    export NODE_ENV=development

    current_dir=$(pwd)
    echo "You are currently in: $current_dir"

    # Check if packages are built
    if [ ! -d "dist" ]; then
        print_warning "Packages not built. Building now..."
        pnpm build
    fi

    # Start dev-env
    print_info "Starting dev-env services..."
    print_info "Logs will be written to: $SCRIPT_DIR/data/logs/dev-env.log"

    nohup env DB_POSTGRES_URL=$PLC_DATABASE_URL REDIS_HOST=localhost PLC_DATABASE_URL=$PLC_DATABASE_URL PDS_DATABASE_URL=$PDS_DATABASE_URL GNDR_DATABASE_URL=$GNDR_DATABASE_URL REDIS_URL=$REDIS_URL pnpm run start > "$SCRIPT_DIR/data/logs/dev-env.log" 2>&1 &

    echo $! > "$SCRIPT_DIR/data/dev-env.pid"

    print_info "Dev-env started with PID: $(cat "$SCRIPT_DIR/data/dev-env.pid")"
}

export PDS_POSTGRES_HOST=localhost
export PDS_POSTGRES_PORT=5434
export PLC_POSTGRES_HOST=localhost
export PLC_POSTGRES_PORT=5433
export APPVIEW_POSTGRES_HOST=localhost
export APPVIEW_POSTGRES_PORT=5435
export REDIS_HOST=localhost
export REDIS_PORT=6379

# Wait for services to be ready
wait_for_services() {
    print_info "Waiting for AT Protocol services to be ready..."
    
    local services=(
        "http://localhost:2582|PLC"
        "http://localhost:2583|PDS"
        "http://localhost:2584|AppView"
    )
    
    for service_info in "${services[@]}"; do
        IFS='|' read -r url name <<< "$service_info"
        local max_attempts=40 # Increased attempts for slower services
        local attempt=0

        echo -n "  Waiting for $name..."
        while [ $attempt -lt $max_attempts ]; do
            if curl -s -o /dev/null "$url"; then
                echo " Ready!"
                break
            fi

            echo -n "."
            sleep 3 # Increased interval for slower services
            ((attempt++))
        done

        if [ $attempt -eq $max_attempts ]; then
            echo " Failed!"
            print_error "$name failed to start"
            return 1
        fi
    done
    
    print_status "All AT Protocol services are ready"
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║       Gander Social Hybrid Setup - Start Script      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    
    check_docker
    check_atproto
    create_data_dirs
    start_docker_services
    setup_environment
    start_dev_env
    wait_for_services
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                  Services Running                     ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║ PLC (DID Registry):    http://localhost:2582         ║"
    echo "║ PDS (Data Server):    http://localhost:2583         ║"
    echo "║ AppView (Gndr):       http://localhost:2584         ║"
    echo "║ BGS (Firehose):       ws://localhost:2470          ║"
    echo "║                                                      ║"
    echo "║ PostgreSQL (PLC):     localhost:5433                ║"
    echo "║ PostgreSQL (PDS):     localhost:5434                ║"
    echo "║ PostgreSQL (AppView): localhost:5435                ║"
    echo "║ Redis:                localhost:6379                ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "To stop all services, run: $SCRIPT_DIR/stop-hybrid.sh"
    echo "To view logs: tail -f $HYBRID_ROOT/data/logs/dev-env.log"
    echo "To connect simulators: $SCRIPT_DIR/connect-simulators.sh"
}

main
