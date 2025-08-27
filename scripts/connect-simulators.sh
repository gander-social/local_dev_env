#!/bin/bash

# Gander Social Hybrid Setup - Connect Simulators Script
# This script helps connect iOS and Android simulators to the running services

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SOCIAL_APP_ROOT="$PROJECT_ROOT/../social-app"

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

# Get local IP address
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1
    else
        # Linux
        hostname -I | awk '{print $1}'
    fi
}

# Setup Android emulator
setup_android() {
    print_info "Setting up Android Emulator connections..."
    
    # Check if adb is available
    if ! command -v adb &> /dev/null; then
        print_warning "ADB not found. Please ensure Android SDK is installed and in PATH"
        return
    fi
    
    # Check if any device is connected
    if ! adb devices | grep -q "device$"; then
        print_warning "No Android device/emulator detected"
        echo "  Please start an Android emulator and run this script again"
        return
    fi
    
    # Forward ports for Android emulator
    local ports=(2582 2583 2584 2470 6379 5433 5434 5435)
    
    for port in "${ports[@]}"; do
        adb reverse tcp:$port tcp:$port 2>/dev/null || true
    done
    
    print_status "Android emulator ports forwarded"
    
    # Create Android configuration
    cat > "$SOCIAL_APP_ROOT/android-config.json" << EOF
{
  "PLC_URL": "http://10.0.2.2:2582",
  "PDS_URL": "http://10.0.2.2:2583",
  "APPVIEW_URL": "http://10.0.2.2:2584",
  "BGS_URL": "ws://10.0.2.2:2470"
}
EOF
    
    print_info "Android config created at $SOCIAL_APP_ROOT/android-config.json"
}

# Setup iOS simulator
setup_ios() {
    print_info "Setting up iOS Simulator connections..."
    
    # iOS Simulator can use localhost directly
    cat > "$SOCIAL_APP_ROOT/ios-config.json" << EOF
{
  "PLC_URL": "http://localhost:2582",
  "PDS_URL": "http://localhost:2583",
  "APPVIEW_URL": "http://localhost:2584",
  "BGS_URL": "ws://localhost:2470"
}
EOF
    
    print_status "iOS simulator can use localhost directly"
    print_info "iOS config created at $SOCIAL_APP_ROOT/ios-config.json"
}

# Setup physical device
setup_physical_device() {
    local ip=$(get_local_ip)
    
    if [ -z "$ip" ]; then
        print_error "Could not determine local IP address"
        return
    fi
    
    print_info "Setting up physical device connections..."
    echo ""
    echo "Your local IP address is: $ip"
    echo ""
    echo "For physical devices, use these URLs:"
    echo "  PLC:     http://$ip:2582"
    echo "  PDS:     http://$ip:2583"
    echo "  AppView: http://$ip:2584"
    echo "  BGS:     ws://$ip:2470"
    echo ""
    
    # Create physical device configuration
    cat > "$SOCIAL_APP_ROOT/physical-device-config.json" << EOF
{
  "PLC_URL": "http://$ip:2582",
  "PDS_URL": "http://$ip:2583",
  "APPVIEW_URL": "http://$ip:2584",
  "BGS_URL": "ws://$ip:2470"
}
EOF
    
    print_info "Physical device config created at $SOCIAL_APP_ROOT/physical-device-config.json"
    print_warning "Ensure your device is on the same network as this machine"
}

# Check social-app exists
check_social_app() {
    if [ ! -d "$SOCIAL_APP_ROOT" ]; then
        print_error "social-app not found at $SOCIAL_APP_ROOT"
        echo "Please ensure the social-app repository is cloned"
        exit 1
    fi
    print_status "Found social-app"
}

# Start social app with proper configuration
start_social_app() {
    echo ""
    read -p "Would you like to start the social app now? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$SOCIAL_APP_ROOT"
        
        # Check if dependencies are installed
        if [ ! -d "node_modules" ]; then
            print_info "Installing social-app dependencies..."
            yarn install
        fi
        
        # Export environment variables for the app
        export RN_AT_SERVICE_URL="http://localhost:2583"
        export RN_BGS_SERVICE_URL="ws://localhost:2470"
        export RN_PLC_URL="http://localhost:2582"
        
        print_info "Starting social app..."
        yarn start
    fi
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║   Gander Social - Simulator Connection Setup          ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    
    check_social_app
    
    # First check if services are running
    if ! curl -s -f "http://localhost:2583" >/dev/null 2>&1; then
        print_error "Services don't appear to be running"
        echo "Please run: $SCRIPT_DIR/start-hybrid.sh"
        exit 1
    fi
    
    print_status "Services are running"
    echo ""
    
    # Detect what type of setup is needed
    echo "Select your target platform:"
    echo "1) iOS Simulator"
    echo "2) Android Emulator"
    echo "3) Physical Device (iOS or Android)"
    echo "4) All of the above"
    echo ""
    
    read -p "Enter your choice (1-4): " choice
    echo ""
    
    case $choice in
        1)
            setup_ios
            ;;
        2)
            setup_android
            ;;
        3)
            setup_physical_device
            ;;
        4)
            setup_ios
            echo ""
            setup_android
            echo ""
            setup_physical_device
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                  Connection URLs                      ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║ Service  │ iOS Simulator  │ Android    │ Physical    ║"
    echo "╠══════════╪═══════════════╪════════════╪═════════════╣"
    echo "║ PLC      │ localhost:2582 │ 10.0.2.2   │ $ip    ║"
    echo "║ PDS      │ localhost:2583 │ 10.0.2.2   │ $ip    ║"
    echo "║ AppView  │ localhost:2584 │ 10.0.2.2   │ $ip    ║"
    echo "║ BGS      │ localhost:2470 │ 10.0.2.2   │ $ip    ║"
    echo "╚══════════╧═══════════════╧════════════╧═════════════╝"
    echo ""
    
    start_social_app
}

main
