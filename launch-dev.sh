#!/bin/bash

# Gander Social Unified Development Launcher
# One-stop script to launch the entire development environment with proper connectivity

echo "🦆 Gander Social Development Launcher"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Directories
DEVELO_DIR="/Users/paulbrooker/IdeaProjects/gander-social-develo"
ATPROTO_DIR="/Users/paulbrooker/IdeaProjects/gander-social-atproto"
SOCIAL_APP_DIR="/Users/paulbrooker/IdeaProjects/social-app"

# Check dependencies
check_dependencies() {
    echo "📋 Checking Dependencies..."
    echo "=========================="
    
    local missing=false
    
    # Check Node.js
    if command -v node > /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "✅ Node.js: ${GREEN}$NODE_VERSION${NC}"
    else
        echo -e "❌ Node.js: ${RED}Not installed${NC}"
        missing=true
    fi
    
    # Check package managers
    for pm in yarn pnpm npm; do
        if command -v $pm > /dev/null; then
            echo -e "✅ $pm: ${GREEN}$(${pm} --version)${NC}"
        else
            echo -e "⚠️  $pm: ${YELLOW}Not installed${NC}"
        fi
    done
    
    # Check Docker (optional)
    if command -v docker > /dev/null; then
        echo -e "✅ Docker: ${GREEN}$(docker --version | cut -d' ' -f3 | tr -d ',')${NC}"
    else
        echo -e "ℹ️  Docker: ${YELLOW}Not installed (optional)${NC}"
    fi
    
    # Check ADB (optional)
    if command -v adb > /dev/null; then
        echo -e "✅ ADB: ${GREEN}Installed${NC}"
    else
        echo -e "ℹ️  ADB: ${YELLOW}Not installed (needed for Android)${NC}"
    fi
    
    echo ""
    
    if [ "$missing" = true ]; then
        echo -e "${RED}Missing required dependencies!${NC}"
        return 1
    fi
    return 0
}

# Select development mode
select_mode() {
    echo "🚀 Select Development Mode:"
    echo "=========================="
    echo ""
    echo -e "${BLUE}1)${NC} Native Development Environment ${GREEN}(Recommended)${NC}"
    echo "   - Uses built-in dev-env from atproto"
    echo "   - Faster startup, hot reloading"
    echo "   - Better for active development"
    echo ""
    echo -e "${BLUE}2)${NC} Docker Environment"
    echo "   - Full containerized setup"
    echo "   - Better isolation"
    echo "   - Closer to production"
    echo ""
    echo -e "${BLUE}3)${NC} Hybrid Mode"
    echo "   - Core services in Docker"
    echo "   - Dev services native"
    echo "   - Best of both worlds"
    echo ""
    read -p "Enter choice (1-3): " mode_choice
    echo ""
    
    case $mode_choice in
        1) echo "native" ;;
        2) echo "docker" ;;
        3) echo "hybrid" ;;
        *) echo "native" ;;
    esac
}

# Launch native environment
launch_native() {
    echo -e "${MAGENTA}🚀 Launching Native Development Environment${NC}"
    echo "=========================================="
    
    # Start dev-env in a new terminal
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        osascript -e "tell app \"Terminal\" to do script \"cd $DEVELO_DIR && ./start-dev-env.sh\""
        echo -e "${GREEN}✅ Started dev-env in new Terminal window${NC}"
    else
        # Linux - try common terminal emulators
        if command -v gnome-terminal > /dev/null; then
            gnome-terminal -- bash -c "cd $DEVELO_DIR && ./start-dev-env.sh; exec bash"
        elif command -v xterm > /dev/null; then
            xterm -e "cd $DEVELO_DIR && ./start-dev-env.sh" &
        else
            echo "Starting in background..."
            cd "$DEVELO_DIR" && ./start-dev-env.sh &
        fi
    fi
    
    # Wait for services to start
    echo ""
    echo "⏳ Waiting for services to start..."
    sleep 5
    
    # Check service health
    "$DEVELO_DIR/ensure-dev-connectivity.sh"
}

# Launch Docker environment
launch_docker() {
    echo -e "${MAGENTA}🚀 Launching Docker Environment${NC}"
    echo "================================"
    
    cd "$DEVELO_DIR"
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running!${NC}"
        echo "Please start Docker Desktop first."
        return 1
    fi
    
    # Start services
    echo "Starting Docker services..."
    docker-compose -f docker-compose.final.yml up -d
    
    # Wait for services
    echo ""
    echo "⏳ Waiting for services to be healthy..."
    sleep 10
    
    # Show status
    docker-compose -f docker-compose.final.yml ps
    
    # Check connectivity
    "$DEVELO_DIR/ensure-dev-connectivity.sh"
}

# Launch hybrid environment
launch_hybrid() {
    echo -e "${MAGENTA}🚀 Launching Hybrid Environment${NC}"
    echo "==============================="
    
    echo "Starting PostgreSQL and Redis in Docker..."
    cd "$DEVELO_DIR"
    docker-compose -f docker-compose.final.yml up -d postgres redis
    
    echo ""
    echo "Starting native dev-env..."
    launch_native
}

# Setup mobile app
setup_mobile() {
    echo ""
    echo "📱 Mobile App Setup"
    echo "=================="
    
    # Check if mobile app directory exists
    if [ ! -d "$SOCIAL_APP_DIR" ]; then
        echo -e "${RED}❌ Social app directory not found!${NC}"
        echo "Expected at: $SOCIAL_APP_DIR"
        return 1
    fi
    
    cd "$SOCIAL_APP_DIR"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "📦 Installing mobile app dependencies..."
        if [ -f "yarn.lock" ]; then
            yarn install
        elif [ -f "pnpm-lock.yaml" ]; then
            pnpm install
        else
            npm install
        fi
    fi
    
    # Configure for development
    "$DEVELO_DIR/ensure-dev-connectivity.sh"
    
    echo ""
    echo -e "${GREEN}✅ Mobile app configured${NC}"
    echo ""
    echo "Start the mobile app with:"
    echo -e "${BLUE}cd $SOCIAL_APP_DIR${NC}"
    echo -e "${BLUE}yarn start${NC}"
    echo ""
    echo "Or use the helper script:"
    echo -e "${BLUE}cd $DEVELO_DIR${NC}"
    echo -e "${BLUE}./start-mobile-app.sh${NC}"
}

# Main launcher
main() {
    # Header
    echo -e "${MAGENTA}    ___              _              ___         _       _ ${NC}"
    echo -e "${MAGENTA}   / __|__ _ _ _  __| |___ _ _     / __| ___ __(_)__ _ | |${NC}"
    echo -e "${MAGENTA}  | (_ / _\` | ' \/ _\` / -_) '_|    \__ \/ _ / _| / _\` || |${NC}"
    echo -e "${MAGENTA}   \___\__,_|_||_\__,_\___|_|      |___/\___\__|_\__,_||_|${NC}"
    echo ""
    
    # Check dependencies
    if ! check_dependencies; then
        echo -e "${RED}Please install missing dependencies first!${NC}"
        exit 1
    fi
    
    # Make scripts executable
    echo "🔧 Ensuring scripts are executable..."
    chmod +x "$DEVELO_DIR"/*.sh
    echo ""
    
    # Select and launch environment
    MODE=$(select_mode)
    
    case $MODE in
        "native")
            launch_native
            ;;
        "docker")
            launch_docker
            ;;
        "hybrid")
            launch_hybrid
            ;;
    esac
    
    # Setup mobile if services are running
    if nc -z localhost 2583 2>/dev/null; then
        setup_mobile
    else
        echo ""
        echo -e "${YELLOW}⚠️  Services not fully started yet${NC}"
        echo "Wait a moment and run this script again to set up mobile app"
    fi
    
    # Show final instructions
    echo ""
    echo "🎉 Development Environment Ready!"
    echo "================================"
    echo ""
    echo "Service URLs:"
    echo "  • PLC: http://localhost:2582"
    echo "  • PDS: http://localhost:2583"
    echo "  • AppView: http://localhost:2584"
    echo "  • BGS: ws://localhost:2470"
    echo ""
    echo "Useful Commands:"
    echo "  • Check connectivity: ./ensure-dev-connectivity.sh"
    echo "  • Monitor services: ./native-dev-ports.sh"
    echo "  • Start mobile app: ./start-mobile-app.sh"
    echo ""
    echo -e "${GREEN}Happy coding! 🦆${NC}"
}

# Trap Ctrl+C
trap 'echo ""; echo "Interrupted. Cleaning up..."; exit 1' INT

# Run main
main
