# Gander Social Port Connectivity & Development Setup Guide

## Overview

This guide documents the complete port exposure and connectivity setup for the Gander Social development environment, ensuring seamless communication between the native dev-env package and mobile applications across all platforms.

## 🚀 Quick Start

### One-Command Launch
```bash
cd /Users/paulbrooker/IdeaProjects/gander-social-develo
./launch-dev.sh
```

This unified launcher will:
- Check all dependencies
- Let you choose between Native, Docker, or Hybrid mode
- Start all services with proper port exposure
- Configure mobile app connectivity
- Provide real-time service monitoring

### Manual Setup

#### Step 1: Make Scripts Executable
```bash
cd /Users/paulbrooker/IdeaProjects/gander-social-develo
./make-executable.sh
```

#### Step 2: Start Backend Services
```bash
# Option A: Native Dev Environment (Recommended)
./start-dev-env.sh

# Option B: Docker Environment
docker-compose -f docker-compose.final.yml up -d
```

#### Step 3: Ensure Connectivity
```bash
./ensure-dev-connectivity.sh
```

#### Step 4: Start Mobile App
```bash
./start-mobile-app.sh
```

## 📡 Port Configuration

### Service Ports
| Service | Port | URL | Description |
|---------|------|-----|-------------|
| PLC | 2582 | http://localhost:2582 | DID Registry |
| PDS | 2583 | http://localhost:2583 | Personal Data Server |
| AppView (Gndr) | 2584 | http://localhost:2584 | Application View |
| BGS | 2470 | ws://localhost:2470 | Big Graph Service (WebSocket) |
| PostgreSQL | 5432 | postgres://localhost:5432 | Database |
| Redis | 6379 | redis://localhost:6379 | Cache |

### Platform-Specific URLs

#### iOS Simulator
- Use `localhost` for all services
- No special configuration needed

#### Android Emulator
Two options:
1. **With Port Forwarding (Recommended)**:
   - Use `localhost` after running port forwarding
   - Automatically configured by our scripts
   
2. **Without Port Forwarding**:
   - Replace `localhost` with `10.0.2.2`
   - Example: `http://10.0.2.2:2583`

#### Physical Devices
- Use your Mac's IP address (automatically detected by scripts)
- Ensure device is on same network
- Example: `http://192.168.1.100:2583`

## 🔧 New Scripts Created

### 1. `ensure-dev-connectivity.sh`
Comprehensive connectivity manager that:
- Checks all service statuses
- Configures Android port forwarding
- Creates development configuration files
- Tests service endpoints
- Generates connectivity reports

### 2. `native-dev-ports.sh`
Native dev environment port manager that:
- Monitors dev-env process health
- Configures macOS firewall rules
- Creates service discovery modules
- Provides real-time health monitoring
- Sets up development proxy configurations

### 3. `launch-dev.sh`
Unified development launcher that:
- Checks all dependencies
- Offers multiple launch modes (Native/Docker/Hybrid)
- Automates the entire startup process
- Configures mobile app connectivity
- Provides a beautiful ASCII banner

## 📱 Mobile App Configuration

### Auto-Generated Files

#### 1. Service Discovery Module
Location: `/Users/paulbrooker/IdeaProjects/social-app/src/lib/service-discovery.ts`

Features:
- Platform-aware URL selection
- Network type detection
- Health check functions
- Automatic failover

#### 2. Development Configuration
Location: `/Users/paulbrooker/IdeaProjects/social-app/src/config/dev-services.ts`

Exports:
- `DEV_SERVICES` object with all endpoints
- Individual URL constants for backward compatibility
- Platform detection helpers

### Usage in Your App

```typescript
import { DEV_SERVICES, discoverServices } from './config/dev-services'

// Option 1: Use static configuration
const pdsUrl = DEV_SERVICES.PDS_URL

// Option 2: Use dynamic discovery
const services = await discoverServices()
const pdsUrl = services.pds

// Option 3: Check service health
import { checkAllServices } from './lib/service-discovery'
const health = await checkAllServices()
console.log('PDS healthy:', health.pds)
```

## 🐛 Troubleshooting

### Common Issues

#### Services Not Accessible
```bash
# Check if services are running
./ensure-dev-connectivity.sh

# Check specific port
lsof -i :2583

# View logs (native)
# Check the terminal running ./start-dev-env.sh

# View logs (Docker)
docker-compose -f docker-compose.final.yml logs pds
```

#### Android Can't Connect
```bash
# Ensure ADB is connected
adb devices

# Re-run port forwarding
adb reverse tcp:2583 tcp:2583
adb reverse tcp:2584 tcp:2584
adb reverse tcp:2582 tcp:2582
adb reverse tcp:2470 tcp:2470
```

#### Physical Device Can't Connect
1. Check both devices are on same network
2. Verify your Mac's IP: `ifconfig | grep inet`
3. Test connectivity: `ping YOUR_MAC_IP` from device
4. Check firewall settings

### macOS Firewall Configuration
If prompted about incoming connections:
1. Click "Allow" for Node.js
2. Or disable firewall temporarily for testing
3. Or run: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add $(which node)`

## 🔍 Monitoring Tools

### Real-Time Service Monitor
```bash
./native-dev-ports.sh
# Then choose option 2 (Monitor service health)
```

### Connectivity Report
After running `ensure-dev-connectivity.sh`, check:
```
/Users/paulbrooker/IdeaProjects/gander-social-develo/connectivity-report.txt
```

### Docker Status (if using Docker)
```bash
docker-compose -f docker-compose.final.yml ps
docker-compose -f docker-compose.final.yml logs --tail=50 -f
```

## 🚦 Development Workflows

### Workflow 1: Native Development (Fastest)
1. `./launch-dev.sh` → Choose option 1
2. Wait for services to start
3. Mobile app auto-configured
4. Hot reloading enabled

### Workflow 2: Docker Development (Isolated)
1. `./launch-dev.sh` → Choose option 2
2. Services start in containers
3. Mobile app connects to Docker
4. More production-like

### Workflow 3: Hybrid Mode (Flexible)
1. `./launch-dev.sh` → Choose option 3
2. Database/Cache in Docker
3. App services native
4. Best debugging experience

## 📋 Environment Variables

### Native Dev Environment
Automatically configured by `dev-env` package:
- `PDS_PORT=2583`
- `APPVIEW_PORT=2584`
- `PLC_PORT=2582`
- `NODE_ENV=development`

### Docker Environment
Set in `docker-compose.final.yml`:
- Bind to `0.0.0.0` for external access
- Canadian data retention settings
- Service discovery endpoints

## 🎯 Best Practices

1. **Always use the launcher script** for consistent setup
2. **Check connectivity** before starting mobile development
3. **Use port forwarding** for Android development
4. **Monitor services** during development
5. **Keep logs visible** in separate terminal windows

## 🔄 Next Steps

1. Integrate with ThinkOn infrastructure
2. Add SSL/TLS for production readiness
3. Implement service mesh for microservices
4. Add centralized logging
5. Create CI/CD pipeline

## 📚 Additional Resources

- [Bluesky AT Protocol Docs](https://atproto.com/docs)
- [React Native Networking](https://reactnative.dev/docs/network)
- [Docker Networking Guide](https://docs.docker.com/network/)
- Project Status: `/docker-fixes/PROJECT_STATUS_UPDATE.md`
- Troubleshooting Guide: `/docker-fixes/TROUBLESHOOTING.md`
