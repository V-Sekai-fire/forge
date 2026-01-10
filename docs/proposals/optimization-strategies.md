## Optimization Strategies

### A. Connection Pool Adjustment

```elixir
# config/runtime.exs
config :my_app, MyApp.Repo,
  pool_size: 15  # Moderate increase for trial
```

### B. Batch Processing

Use `Oban.insert_all` for logging model outputs efficiently.

### C. Async Responses

Ensure Discord replies happen before model inference.
