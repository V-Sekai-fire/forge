import Config

# Runtime configuration for production
if config_env() == :prod do
  # Database for SQLite (embedded)
  config :livebook_nx, LivebookNx.Repo,
    database: System.get_env("DATABASE_PATH") || "livebook_nx_prod.db"

  # Oban queues for production
  config :livebook_nx, Oban,
    queues: [
      default: String.to_integer(System.get_env("OBAN_DEFAULT_QUEUE") || "5"),
      ml: String.to_integer(System.get_env("OBAN_ML_QUEUE") || "8")
    ],
    repo: LivebookNx.Repo,
    notifier: Oban.Notifiers.Isolated
end
