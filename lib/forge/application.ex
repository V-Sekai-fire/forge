defmodule Forge.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start Ecto repo first
      Forge.Repo,
      # Start Oban for job queuing
      {Oban, Application.fetch_env!(:forge, Oban)},
      # Forge server for managing operations
      Forge.Server
    ]

    opts = [strategy: :one_for_one, name: Forge.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
