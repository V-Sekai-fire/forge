## Porting Process

1. **Adapt the existing Livebook script** (`qwen3vl_inference.exs`) to work within our Elixir application.
2. **Integrate with Oban** for job queuing and background processing.
3. **Test latency impact** using the 60ms remote database connection.
