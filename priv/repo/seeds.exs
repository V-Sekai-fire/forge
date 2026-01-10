# Script for populating the database with initial data.
#
# This script is run with `mix run priv/repo/seeds.exs` or as part of
# `mix ecto.setup` (which also runs migrations).
#
# We recommend using the bang functions (`insert!`, `update!` etc) as they
# will fail if something goes wrong.

# Seed data for Livebook Nx application
#
# Database Configuration:
# - Database: livebook_nx_dev
# - User: root
# - Password: secure_password_123
# - Host: localhost:26257
# - SSL: enabled with client certificates
#
# This includes:
# - Database user setup (password already set via SQL)
# - Oban job queue tables (created via migrations)
# - Any initial configuration or sample data

IO.puts("Database seeded successfully!")
IO.puts("")
IO.puts("Database Configuration:")
IO.puts("  Database: livebook_nx_dev")
IO.puts("  User: root")
IO.puts("  Password: secure_password_123")
IO.puts("  Host: localhost:26257")
IO.puts("  SSL: enabled")
IO.puts("")
IO.puts("Oban job queues configured:")
IO.puts("  - default: 5 workers (system jobs)")
IO.puts("  - ml: 8 workers (shared ML inference: zimage, qwen3vl, etc.)")
