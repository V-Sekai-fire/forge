# Livebook Nx

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple)](https://elixir-lang.org/)

A friendly Elixir-based AI inference platform featuring Qwen3-VL vision-language models, with optional distributed storage and background job processing.

## ✨ Features

- **Vision-Language AI**: Qwen3-VL model for image understanding and description
- **Simple Setup**: Get started with just `mix deps.get && mix compile`
- **Background Processing**: Optional job queues for long-running tasks
- **Flexible Storage**: Choose between local files or distributed databases
- **Third-Party Tools**: Integrated mesh processing, text-to-speech, and image generation
- **Production Ready**: Docker, Kubernetes, and cloud deployment support

## 🚀 Quick Start

### Basic Setup (No Database Required)

```bash
# Install dependencies
mix deps.get
mix compile

# Run inference immediately
mix qwen3vl image.jpg "What do you see?"
```

### Full Setup (With Database & Job Queues)

```bash
# Install dependencies
mix deps.get
mix compile

# Optional: Setup database for job queuing
mix run tools/generate_certs.exs  # Generate certificates
mix crdb.start                    # Start CockroachDB
mix ecto.migrate                  # Setup database tables
mix run priv/repo/seeds.exs       # Load initial data
```

### Run Inference

```bash
# Describe an image
mix qwen3vl image.jpg "What do you see?"

# Queue for background processing (requires database)
{:ok, job} = LivebookNx.Qwen3VL.queue_inference("image.jpg", "Describe this image")
```

# With custom options

mix qwen3vl photo.png "Analyze in detail" --max-tokens 200 --temperature 0.8

````

## 🗄️ Database Configuration (Optional)

Livebook Nx can work without a database for basic inference tasks. For production use with job queuing, it supports CockroachDB with TLS encryption.

### Connection Details

When using the database, it connects with:
- **Host**: localhost:26257
- **Database**: livebook_nx_dev
- **User**: root
- **SSL**: Enabled with automatically generated certificates

### Database Management

```bash
# Start CockroachDB
mix crdb.start

# Stop CockroachDB
mix crdb.stop

# View CockroachDB Web UI
open https://localhost:8080
````

### Certificate Management

TLS certificates are automatically generated in `cockroach-certs/` for secure connections.

## �📚 Documentation

- **[📖 User Guide](docs/user-guide.md)** - Complete usage guide
- **[🛠️ Setup Guide](docs/setup.md)** - Installation and deployment
- **[🔧 API Reference](docs/api.md)** - Technical documentation
- **[🧰 Third-Party Tools](docs/third-party-tools.md)** - Integrated AI tools

## 🏗️ Architecture

```
Livebook Nx
├── Core Application (Elixir)
│   ├── Qwen3-VL Inference Engine
│   ├── Job Queue (Oban - optional)
│   └── Database Layer (Ecto - optional)
├── Storage Options
│   ├── Local Files (default)
│   ├── CockroachDB (optional)
│   └── SeaweedFS (optional)
└── Third-Party Tools
    ├── Mesh Processing
    ├── Audio Synthesis
    ├── Image Generation
    └── Character Rigging
```

**Note**: Database and distributed storage are optional. You can use Livebook Nx for basic inference without any database setup.

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
