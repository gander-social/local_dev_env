#!/bin/bash

# Gander Social Native Dev Environment Port Manager
# Ensures proper port exposure when using the native dev-env package

echo "🦆 Gander Social Native Dev Environment Port Manager"
echo "==================================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DEV_ENV_DIR="/Users/paulbrooker/IdeaProjects/gander-social-atproto"
SOCIAL_APP_DIR="/Users/paulbrooker/IdeaProjects/social-app"

# Service ports from dev-env
declare -A SERVICE_PORTS=(
    ["PLC"]="2582"
    ["PDS"]="2583"
    ["AppView/Gndr"]="2584"
    ["BGS"]="2470"
)

# Check if dev-env is running
check_dev_env() {
    local running=true
    
    echo "🔍 Checking Native Dev Environment Status..."
    echo "==========================================="
    
    # Check if the dev-env process is running
    if pgrep -f "dev-env" > /dev/null; then
        echo -e "${GREEN}✅ Dev environment process detected${NC}"
    else
        echo -e "${YELLOW}⚠️  Dev environment process not found${NC}"
        running=false
    fi
    
    # Check each service port
    echo ""
    echo "Service Port Check:"
    for service in "${!SERVICE_PORTS[@]}"; do
        port="${SERVICE_PORTS[$service]}"
        printf "%-20s port %-5s: " "$service" "$port"
        
        if lsof -i :$port > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Active${NC}"
        else
            echo -e "${RED}❌ Not listening${NC}"
            running=false
        fi
    done
    
    if [ "$running" = true ]; then
        return 0
    else
        return 1
    fi
}

# Configure firewall (macOS specific)
configure_firewall() {
    echo ""
    echo "🔥 Configuring Firewall Rules..."
    echo "================================"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Check if firewall is enabled
        if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "enabled"; then
            echo -e "${YELLOW}Firewall is enabled. Adding exceptions...${NC}"
            
            # Add node to firewall exceptions
            if command -v node > /dev/null; then
                NODE_PATH=$(which node)
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$NODE_PATH" > /dev/null 2>&1
                sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$NODE_PATH" > /dev/null 2>&1
                echo -e "${GREEN}✅ Added Node.js to firewall exceptions${NC}"
            fi
            
            echo "Note: You may need to allow incoming connections when prompted"
        else
            echo -e "${GREEN}✅ Firewall is disabled - no configuration needed${NC}"
        fi
    fi
}

# Create service discovery file
create_service_discovery() {
    echo ""
    echo "📄 Creating Service Discovery Configuration..."
    echo "============================================"
    
    # Get host IP
    HOST_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    
    # Create service discovery file
    cat > "$SOCIAL_APP_DIR/src/lib/service-discovery.ts" << EOF
// Gander Social Service Discovery
// Auto-generated: $(date)

import { Platform } from 'react-native'
import NetInfo from '@react-native-community/netinfo'

export interface ServiceEndpoints {
  plc: string
  pds: string
  appView: string
  bgs: string
}

// Development service ports
const DEV_PORTS = {
  plc: 2582,
  pds: 2583,
  appView: 2584,
  bgs: 2470,
}

// Get appropriate host based on platform and network
export async function discoverServices(): Promise<ServiceEndpoints> {
  const netInfo = await NetInfo.fetch()
  const isConnected = netInfo.isConnected
  
  // Default to localhost for iOS simulator
  let host = 'localhost'
  
  if (Platform.OS === 'android') {
    // Android emulator special IP
    host = '10.0.2.2'
  } else if (Platform.OS === 'ios' && !__DEV__) {
    // Production or physical device
    host = '${HOST_IP}'
  }
  
  // Check if we're on a physical device by checking network type
  if (netInfo.type === 'wifi' || netInfo.type === 'cellular') {
    // Physical device - use host IP
    host = '${HOST_IP}'
  }
  
  return {
    plc: \`http://\${host}:\${DEV_PORTS.plc}\`,
    pds: \`http://\${host}:\${DEV_PORTS.pds}\`,
    appView: \`http://\${host}:\${DEV_PORTS.appView}\`,
    bgs: \`ws://\${host}:\${DEV_PORTS.bgs}\`,
  }
}

// Health check function
export async function checkServiceHealth(endpoint: string): Promise<boolean> {
  try {
    const response = await fetch(\`\${endpoint}/health\`, {
      method: 'GET',
      timeout: 5000,
    })
    return response.ok
  } catch {
    return false
  }
}

// Check all services
export async function checkAllServices(): Promise<Record<string, boolean>> {
  const services = await discoverServices()
  const health: Record<string, boolean> = {}
  
  for (const [name, url] of Object.entries(services)) {
    if (name === 'bgs') continue // Skip WebSocket
    health[name] = await checkServiceHealth(url)
  }
  
  return health
}
EOF
    
    echo -e "${GREEN}✅ Created service discovery module${NC}"
}

# Setup development proxy (optional)
setup_dev_proxy() {
    echo ""
    echo "🔀 Setting Up Development Proxy..."
    echo "================================="
    
    # Create a simple proxy configuration
    cat > "$SOCIAL_APP_DIR/proxy-config.json" << EOF
{
  "/xrpc/*": {
    "target": "http://localhost:2583",
    "secure": false,
    "changeOrigin": true
  },
  "/api/*": {
    "target": "http://localhost:2584",
    "secure": false,
    "changeOrigin": true
  }
}
EOF
    
    echo -e "${GREEN}✅ Created proxy configuration${NC}"
    echo "   Use this with webpack-dev-server or similar tools"
}

# Monitor service health
monitor_services() {
    echo ""
    echo "📊 Starting Service Health Monitor..."
    echo "===================================="
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while true; do
        clear
        echo "🦆 Gander Social Service Health Monitor"
        echo "======================================"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        for service in "${!SERVICE_PORTS[@]}"; do
            port="${SERVICE_PORTS[$service]}"
            printf "%-20s [:%s] " "$service" "$port"
            
            if nc -z localhost "$port" 2>/dev/null; then
                echo -e "${GREEN}● HEALTHY${NC}"
                
                # Try to get more info
                case "$service" in
                    "PLC")
                        if curl -s "http://localhost:$port/health" > /dev/null 2>&1; then
                            echo "                     └─ Health endpoint responding"
                        fi
                        ;;
                    "PDS")
                        if curl -s "http://localhost:$port/_health" > /dev/null 2>&1; then
                            echo "                     └─ Health endpoint responding"
                        fi
                        ;;
                esac
            else
                echo -e "${RED}● OFFLINE${NC}"
            fi
        done
        
        echo ""
        echo "Press Ctrl+C to exit"
        sleep 5
    done
}

# Main execution
main() {
    # Check if dev-env is running
    if check_dev_env; then
        echo ""
        echo -e "${GREEN}✅ Native dev environment is running!${NC}"
        
        # Configure firewall if needed
        configure_firewall
        
        # Create service discovery
        create_service_discovery
        
        # Setup proxy config
        setup_dev_proxy
        
        echo ""
        echo "🎉 Port exposure configured successfully!"
        echo ""
        echo "Available endpoints:"
        echo "  • PLC Registry: http://localhost:2582"
        echo "  • PDS Server: http://localhost:2583"
        echo "  • AppView (Gndr): http://localhost:2584"
        echo "  • BGS WebSocket: ws://localhost:2470"
        echo ""
        echo "Mobile app configuration updated at:"
        echo "  ${SOCIAL_APP_DIR}/src/lib/service-discovery.ts"
        echo ""
        echo "Would you like to:"
        echo "  1) Start the mobile app"
        echo "  2) Monitor service health"
        echo "  3) Exit"
        echo ""
        read -p "Enter choice (1-3): " choice
        
        case $choice in
            1)
                echo "Starting mobile app..."
                cd "$SOCIAL_APP_DIR"
                if [ -f "yarn.lock" ]; then
                    yarn start
                elif [ -f "package-lock.json" ]; then
                    npm start
                else
                    pnpm start
                fi
                ;;
            2)
                monitor_services
                ;;
            3)
                echo "Exiting..."
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    else
        echo ""
        echo -e "${RED}❌ Native dev environment is not running!${NC}"
        echo ""
        echo "Start it with:"
        echo -e "${BLUE}cd $DEV_ENV_DIR${NC}"
        echo -e "${BLUE}make run-dev-env${NC}"
        echo ""
        echo "Or use the start script:"
        echo -e "${BLUE}cd /Users/paulbrooker/IdeaProjects/gander-social-develo${NC}"
        echo -e "${BLUE}./start-dev-env.sh${NC}"
        exit 1
    fi
}

# Run main function
main
