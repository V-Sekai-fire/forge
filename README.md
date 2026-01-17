# Forge

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Distributed AI platform with peer-to-peer networking via Zenoh. Generates images using Z-Image-Turbo model and provides real-time service monitoring.

## Components

- **zimage/**: Python AI service (Hugging Face diffusers + torch)
- **zimage-client/**: Elixir CLI tools + live service dashboard
- **zenoh-router/**: Dedicated Zenoh router daemon management

## Quick Start

### 1. Install Zenoh Daemon
```bash
# Cargo installation (requires Rust)
cargo install zenohd

# Or use pre-built binaries
curl -L https://github.com/eclipse-zenoh/zenoh/releases/download/1.2.2/zenohd-1.2.2-x86_64-unknown-linux-gnu.tar.gz -o zenohd.tar.gz
tar -xzf zenohd.tar.gz && sudo cp zenohd /usr/local/bin/

# Verify installation
zenohd --version
```

### 2. Launch System
```bash
./boot_forge.sh  # Starts all components: router + services + dashboard
```

### 3. Generate Images
```bash
# Simple generation
./zimage_client "sunset over mountains"

# Advanced options
./zimage_client "cyberpunk city" --width 1024 --height 1024 --guidance-scale 0.5

# Batch processing
./zimage_client --batch "cat" "dog" "bird"

# Monitor services
./zimage_client --dashboard
```

## Architecture

```
[zimage-client] ←→ [zenoh-router] ←→ [zimage service]
  CLI/Dash           P2P Network          AI Generation
   (Elixir)            (Zenoh)              (Python)
```

- **Peer-to-Peer**: Services discover each other automatically
- **Binary Transport**: FlatBuffers for efficient data exchange
- **GPU Optimized**: torch.compile for 2x AI speedup on CUDA

## Development

### Setup
```bash
# Clone repository
git clone https://github.com/V-Sekai-fire/forge.git
cd forge

# Setup Python AI service
cd zimage && uv sync

# Setup Elixir tools
cd ../zimage-client && mix deps.get && mix escript.build
```

### Runtime
- **Zenoh Router**: `./zenoh-router/zenoh_router start`
- **AI Service**: `cd zimage && uv run python inference_service.py`
- **Client Tools**: `cd zimage-client && ./zimage_client [command]`

## Documentation

- **[Development Guide](CONTRIBUTING.md)** - Setup, guidelines, and contribution process
- **[Zenoh Integration](docs/proposals/zenoh-implementation.md)** - Technical architecture details
- **[API Reference](docs/api.md)** - Service interfaces and protocols

## License

MIT License - see [LICENSE](LICENSE)
