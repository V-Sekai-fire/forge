# Livebook Nx

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple)](https://elixir-lang.org/)

A comprehensive Elixir-based AI inference platform featuring Qwen3-VL vision-language models, distributed storage, and integrated third-party AI tools.

## ✨ Features

- **Vision-Language AI**: Qwen3-VL model for image understanding and description
- **Distributed Storage**: CockroachDB and SeaweedFS integration
- **Background Processing**: Asynchronous job queues with Oban
- **GPU Acceleration**: CUDA support for high-performance inference
- **Third-Party Tools**: Integrated mesh processing, text-to-speech, and image generation
- **Production Ready**: Docker, Kubernetes, and cloud deployment support

## 🚀 Quick Start

### Automated Setup

```bash
# Clone and setup
git clone <repository-url>
cd livebook-nx
elixir setup.exs
```

### Manual Setup

```bash
# Install dependencies
mix deps.get
mix compile

# Setup CockroachDB with TLS
mix run tools/generate_certs.exs  # Generate certificates
mix crdb.start                    # Start CockroachDB with TLS
mix ecto.migrate                  # Run database migrations
mix run priv/repo/seeds.exs       # Seed initial data

# Alternative: Full setup
mix ecto.setup  # Creates DB, runs migrations and seeds
```

### Run Inference

```bash
# Describe an image
mix qwen3vl image.jpg "What do you see?"

# With custom options
mix qwen3vl photo.png "Analyze in detail" --max-tokens 200 --temperature 0.8
```

## �️ Database Configuration

Livebook Nx uses CockroachDB with TLS encryption for secure, distributed data storage.

### Connection Details

- **Host**: localhost:26257
- **Database**: livebook_nx_dev
- **User**: root
- **Password**: secure_password_123
- **SSL**: Enabled with client certificates

### Database Management

```bash
# Start CockroachDB
mix crdb.start

# Stop CockroachDB
mix crdb.stop

# View CockroachDB Web UI
open https://localhost:8080
```

### Certificate Management

TLS certificates are automatically generated and stored in `cockroach-certs/`:

- `ca.crt` - Certificate Authority
- `client.root.crt` / `client.root.key` - Client certificates
- `node.crt` / `node.key` - Node certificates

## �📚 Documentation

- **[📖 User Guide](docs/user-guide.md)** - Complete usage guide
- **[🛠️ Setup Guide](docs/setup.md)** - Installation and deployment
- **[🔧 API Reference](docs/api.md)** - Technical documentation
- **[🧰 Third-Party Tools](docs/third-party-tools.md)** - Integrated AI tools

## 🏗️ Architecture

```
Livebook Nx
├── Core Application (Elixir/Phoenix)
│   ├── Qwen3-VL Inference Engine
│   ├── Job Queue (Oban)
│   └── Database Layer (Ecto)
├── Distributed Storage
│   ├── CockroachDB (Metadata)
│   └── SeaweedFS (Files)
└── Third-Party Tools
    ├── Mesh Processing
    ├── Audio Synthesis
    ├── Image Generation
    └── Character Rigging
```

## 🐳 Deployment

### Docker

```bash
docker build -t livebook-nx .
docker run -p 4000:4000 livebook-nx
```

### Docker Compose

```bash
docker-compose up -d
```

See [Setup Guide](docs/setup.md) for detailed deployment instructions.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋 Support

- 📖 [Documentation](docs/)
- 🐛 [Issues](https://github.com/your-org/livebook-nx/issues)
- 💬 [Discussions](https://github.com/your-org/livebook-nx/discussions)
