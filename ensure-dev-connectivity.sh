#!/bin/bash

# Gander Social Development Connectivity Manager
# Ensures all ports are properly exposed and services are accessible for local testing

echo "🦆 Gander Social Development Connectivity Manager"
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service configuration
declare -A SERVICES=(
    ["PLC"]="2582"
    ["PDS"]="2583"
    ["AppView"]="2584"
    ["BGS"]="2470"
    ["Redis"]="6379"
    ["PostgreSQL"]="5432"
)

# Get host IP address
get_host_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | grep -v "::1" | head -1 | awk '{print $2}')
        if [ -z "$IP" ]; then
            IP=$(ifconfig en0 | grep "inet " | awk '{print $2}')
        fi
    else
        # Linux
        IP=$(hostname -I | awk '{print $1}')
    fi
    echo ${IP:-"127.0.0.1"}
}

HOST_IP=$(get_host_ip)

# Check if running in Docker mode or native dev-env
check_mode() {
    if docker ps --format '{{.Names}}' | grep -q "gander-"; then
        echo "docker"
    elif lsof -i :2583 > /dev/null 2>&1; then
        echo "native"
    else
        echo "none"
    fi
}

MODE=$(check_mode)

echo -e "${BLUE}📡 Host IP Address: ${HOST_IP}${NC}"
echo -e "${BLUE}🔧 Running Mode: ${MODE}${NC}"
echo ""

# Check service connectivity
check_service() {
    local name=$1
    local port=$2
    local url="http://localhost:$port"
    
    # Special handling for WebSocket
    if [ "$name" == "BGS" ]; then
        url="ws://localhost:$port"
    fi
    
    printf "%-15s %-6s " "$name:" "$port"
    
    if nc -z localhost "$port" 2>/dev/null; then
        echo -e "${GREEN}✅ Running${NC}"
        return 0
    else
        echo -e "${RED}❌ Not accessible${NC}"
        return 1
    fi
}

# Check all services
echo "🔍 Service Status:"
echo "=================="
services_running=true
for service in "${!SERVICES[@]}"; do
    if ! check_service "$service" "${SERVICES[$service]}"; then
        services_running=false
    fi
done
echo ""

# If services aren't running, provide instructions
if [ "$services_running" = false ]; then
    echo -e "${YELLOW}⚠️  Some services are not running${NC}"
    echo ""
    if [ "$MODE" == "none" ]; then
        echo "Start the development environment with one of these options:"
        echo ""
        echo "Option 1 - Native Dev Environment (Recommended):"
        echo -e "${BLUE}cd /Users/paulbrooker/IdeaProjects/gander-social-develo${NC}"
        echo -e "${BLUE}./start-dev-env.sh${NC}"
        echo ""
        echo "Option 2 - Docker Environment:"
        echo -e "${BLUE}cd /Users/paulbrooker/IdeaProjects/gander-social-develo${NC}"
        echo -e "${BLUE}docker-compose -f docker-compose.final.yml up -d${NC}"
    fi
fi

# Setup mobile connectivity
echo "📱 Mobile Platform Configuration:"
echo "================================"

# iOS Configuration
echo ""
echo -e "${BLUE}iOS Simulator:${NC}"
echo "  • Can use 'localhost' directly"
echo "  • No additional configuration needed"
echo "  • Service URLs:"
echo "    - PDS: http://localhost:2583"
echo "    - AppView: http://localhost:2584"
echo "    - PLC: http://localhost:2582"
echo "    - BGS: ws://localhost:2470"

# Android Configuration
echo ""
echo -e "${BLUE}Android Emulator:${NC}"
echo "  • Must use '10.0.2.2' instead of 'localhost'"
echo "  • OR set up port forwarding (recommended)"

# Check if ADB is available and set up Android forwarding
if command -v adb &> /dev/null; then
    echo ""
    echo -e "${YELLOW}Setting up Android port forwarding...${NC}"
    
    # Check if any device is connected
    if adb devices | grep -q "device$"; then
        # Forward all necessary ports
        adb reverse tcp:8081 tcp:8081 2>/dev/null  # Metro bundler
        adb reverse tcp:2582 tcp:2582 2>/dev/null  # PLC
        adb reverse tcp:2583 tcp:2583 2>/dev/null  # PDS
        adb reverse tcp:2584 tcp:2584 2>/dev/null  # AppView
        adb reverse tcp:2470 tcp:2470 2>/dev/null  # BGS
        adb reverse tcp:6379 tcp:6379 2>/dev/null  # Redis
        adb reverse tcp:19000 tcp:19000 2>/dev/null  # Expo
        adb reverse tcp:19001 tcp:19001 2>/dev/null  # Expo
        
        echo -e "${GREEN}✅ Android port forwarding configured${NC}"
        echo "  • Android can now use 'localhost' URLs"
    else
        echo -e "${YELLOW}⚠️  No Android device/emulator connected${NC}"
        echo "  • Connect device and run: $0"
        echo "  • OR use these URLs in your app:"
        echo "    - PDS: http://10.0.2.2:2583"
        echo "    - AppView: http://10.0.2.2:2584"
        echo "    - PLC: http://10.0.2.2:2582"
        echo "    - BGS: ws://10.0.2.2:2470"
    fi
else
    echo -e "${YELLOW}⚠️  ADB not found${NC}"
    echo "  • Install Android SDK tools"
    echo "  • OR use '10.0.2.2' URLs in your Android app"
fi

# Physical Devices Configuration
echo ""
echo -e "${BLUE}Physical Devices:${NC}"
echo "  • Must use host machine IP: ${HOST_IP}"
echo "  • Ensure device is on same network"
echo "  • Service URLs:"
echo "    - PDS: http://${HOST_IP}:2583"
echo "    - AppView: http://${HOST_IP}:2584"
echo "    - PLC: http://${HOST_IP}:2582"
echo "    - BGS: ws://${HOST_IP}:2470"

# Create development configuration file
echo ""
echo "📄 Creating Development Configuration..."

# Create config directory if it doesn't exist
mkdir -p /Users/paulbrooker/IdeaProjects/social-app/src/config

# Create the configuration file
cat > /Users/paulbrooker/IdeaProjects/social-app/src/config/dev-services.ts << EOF
// Auto-generated Gander Social development configuration
// Generated: $(date)
// Host IP: ${HOST_IP}

import { Platform } from 'react-native'

// Helper to select URL based on platform
const selectUrl = (ios: string, android: string, physical: string) => {
  if (Platform.OS === 'ios') {
    // iOS Simulator can use localhost
    return ios
  } else if (Platform.OS === 'android') {
    // Android Emulator needs special IP or port forwarding
    return android
  } else {
    // Physical devices need host IP
    return physical
  }
}

export const DEV_SERVICES = {
  // AT Protocol Services
  PLC_URL: selectUrl(
    'http://localhost:2582',
    'http://localhost:2582', // Using port forwarding
    'http://${HOST_IP}:2582'
  ),
  
  PDS_URL: selectUrl(
    'http://localhost:2583',
    'http://localhost:2583', // Using port forwarding
    'http://${HOST_IP}:2583'
  ),
  
  APPVIEW_URL: selectUrl(
    'http://localhost:2584',
    'http://localhost:2584', // Using port forwarding
    'http://${HOST_IP}:2584'
  ),
  
  BGS_URL: selectUrl(
    'ws://localhost:2470',
    'ws://localhost:2470', // Using port forwarding
    'ws://${HOST_IP}:2470'
  ),
  
  // Default service for authentication
  DEFAULT_SERVICE: selectUrl(
    'http://localhost:2583',
    'http://localhost:2583',
    'http://${HOST_IP}:2583'
  ),
  
  // Host IP for debugging
  HOST_IP: '${HOST_IP}',
  
  // Development flags
  IS_DEV: true,
  USE_LOCAL_SERVICES: true,
}

// Export individual URLs for backward compatibility
export const PLC_URL = DEV_SERVICES.PLC_URL
export const PDS_URL = DEV_SERVICES.PDS_URL
export const APPVIEW_URL = DEV_SERVICES.APPVIEW_URL
export const BGS_URL = DEV_SERVICES.BGS_URL
export const DEFAULT_SERVICE = DEV_SERVICES.DEFAULT_SERVICE
EOF

echo -e "${GREEN}✅ Created dev-services.ts configuration${NC}"

# Test connectivity from different contexts
echo ""
echo "🧪 Testing Service Connectivity:"
echo "==============================="

test_endpoint() {
    local name=$1
    local url=$2
    
    printf "%-15s " "$name:"
    
    if curl -s -f -o /dev/null -w "%{http_code}" "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Accessible${NC}"
    else
        echo -e "${RED}❌ Not accessible${NC}"
    fi
}

if [ "$services_running" = true ]; then
    test_endpoint "PLC Health" "http://localhost:2582/health"
    test_endpoint "PDS" "http://localhost:2583"
    test_endpoint "AppView" "http://localhost:2584"
fi

# Provide Next Steps
echo ""
echo "🚀 Next Steps:"
echo "=============="

if [ "$services_running" = true ]; then
    echo -e "${GREEN}Services are running! You can now:${NC}"
    echo ""
    echo "1. Start the mobile app:"
    echo -e "   ${BLUE}cd /Users/paulbrooker/IdeaProjects/gander-social-develo${NC}"
    echo -e "   ${BLUE}./start-mobile-app.sh${NC}"
    echo ""
    echo "2. Or start it manually:"
    echo -e "   ${BLUE}cd /Users/paulbrooker/IdeaProjects/social-app${NC}"
    echo -e "   ${BLUE}yarn start${NC}"
    echo ""
    echo "3. Test service endpoints:"
    echo "   - PLC: http://localhost:2582/health"
    echo "   - PDS: http://localhost:2583/_health"
    echo "   - AppView: http://localhost:2584"
else
    echo -e "${YELLOW}Start the development environment first!${NC}"
fi

echo ""
echo "📚 Troubleshooting:"
echo "=================="
echo "• Port conflicts: lsof -i :PORT_NUMBER"
echo "• Docker logs: docker-compose logs SERVICE_NAME"
echo "• Native logs: Check terminal running ./start-dev-env.sh"
echo "• Android issues: adb devices && adb reverse --list"
echo "• Network issues: ping ${HOST_IP}"

# Save connectivity report
REPORT_FILE="/Users/paulbrooker/IdeaProjects/gander-social-develo/connectivity-report.txt"
{
    echo "Gander Social Connectivity Report"
    echo "Generated: $(date)"
    echo "Host IP: ${HOST_IP}"
    echo "Mode: ${MODE}"
    echo ""
    echo "Service Status:"
    for service in "${!SERVICES[@]}"; do
        nc -z localhost "${SERVICES[$service]}" 2>/dev/null && echo "$service: Running" || echo "$service: Not Running"
    done
} > "$REPORT_FILE"

echo ""
echo -e "${GREEN}📋 Connectivity report saved to: ${REPORT_FILE}${NC}"
