# Gander Social Hybrid Setup

This hybrid setup runs the AT Protocol services (PLC, PDS, AppView) natively from the gander-social-atproto dev-env, while running supporting services (PostgreSQL, Redis) in Docker containers.

## Architecture

### Native Services (from dev-env)
- **PLC (DID Registry)**: Port 2582
- **PDS (Personal Data Server)**: Port 2583  
- **AppView (Gndr)**: Port 2584
- **BGS (Big Graph Service)**: Port 2470 (WebSocket)

### Docker Services
- **PostgreSQL for PLC**: Port 5433
- **PostgreSQL for PDS**: Port 5434
- **PostgreSQL for AppView**: Port 5435
- **Redis**: Port 6379

### Native Application
- **Social App**: Runs via Metro bundler

## Directory Structure

```
hybrid-setup/
├── docker/
│   └── docker-compose.yml    # Docker services configuration
├── scripts/
│   ├── start-hybrid.sh      # Main start script
│   ├── stop-hybrid.sh       # Stop all services
│   ├── check-health.sh      # Health check script
│   └── connect-simulators.sh # Setup simulator connections
├── config/
│   └── env.hybrid           # Environment configuration
└── data/                    # Created at runtime
    ├── pds/                 # PDS data storage
    └── logs/                # Service logs
```

## Quick Start

1. **Make scripts executable:**
   ```bash
   cd hybrid-setup/scripts
   chmod +x *.sh
   ```

2. **Start all services:**
   ```bash
   ./start-hybrid.sh
   ```

3. **Connect simulators and start social app:**
   ```bash
   ./connect-simulators.sh
   ```

## Usage

### Starting Services

The `start-hybrid.sh` script will:
1. Check Docker is running
2. Start PostgreSQL and Redis containers
3. Wait for databases to be healthy
4. Start the AT Protocol dev-env
5. Wait for all services to be ready

### Stopping Services

```bash
./scripts/stop-hybrid.sh
```

This cleanly stops both the native dev-env and Docker containers.

### Health Check

```bash
./scripts/check-health.sh
```

This shows the status of all services and data storage.

### Connecting Mobile Simulators

```bash
./scripts/connect-simulators.sh
```

This script:
- Sets up port forwarding for Android emulators
- Creates configuration files for each platform
- Optionally starts the social app

#### Platform-specific URLs:

| Service | iOS Simulator | Android Emulator | Physical Device |
|---------|--------------|------------------|-----------------|
| PLC     | localhost:2582 | 10.0.2.2:2582 | [YOUR_IP]:2582 |
| PDS     | localhost:2583 | 10.0.2.2:2583 | [YOUR_IP]:2583 |
| AppView | localhost:2584 | 10.0.2.2:2584 | [YOUR_IP]:2584 |
| BGS     | ws://localhost:2470 | ws://10.0.2.2:2470 | ws://[YOUR_IP]:2470 |

## Troubleshooting

### Services won't start
1. Check Docker is running: `docker info`
2. Check ports are free: `lsof -i :2582,2583,2584,5433,5434,5435,6379`
3. Check logs: `tail -f data/logs/dev-env.log`

### Database connection issues
- Ensure Docker containers are healthy: `cd docker && docker-compose ps`
- Check database logs: `docker logs gander-plc-db`

### Dev-env build issues
```bash
cd ../../gander-social-atproto
pnpm install
pnpm build
```

### Android emulator can't connect
```bash
# Ensure ADB is running
adb devices

# Re-run port forwarding
adb reverse tcp:2583 tcp:2583
```

## Environment Variables

The `config/env.hybrid` file contains all configuration. Key variables:
- Database URLs pointing to Docker containers
- Service ports and hostnames
- Feature flags for Gander-specific functionality
- In the social-app repository, ensure you have pulled the most recent develop branch, copy example.env to .env - then follow the make and docs/build instructions
- In the gander-social-atproto repository, ensure you have pulled the most recent develop branch and run the build instructions 

## Data Persistence

- **Docker volumes**: Database data persists between restarts
- **Local data directory**: PDS blobs and logs stored in `data/`

## Development Tips

1. **View logs**: `tail -f data/logs/dev-env.log`
2. **Access databases**: 
   ```bash
   # PLC database
   psql -h localhost -p 5433 -U plc -d plc_dev
   
   # PDS database  
   psql -h localhost -p 5434 -U pds -d pds_dev
   ```
3. **Monitor Redis**: `redis-cli -p 6379 monitor`

## Why Hybrid?

This approach provides:
- **Faster development**: Native dev-env with hot reloading
- **Isolation**: Databases in Docker prevent conflicts
- **Flexibility**: Easy to switch between Docker and native services
- **Debugging**: Direct access to dev-env logs and code
