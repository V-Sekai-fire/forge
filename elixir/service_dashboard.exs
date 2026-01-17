#!/usr/bin/env elixir
# service_dashboard.exs
# Service Dashboard: Lists all active Zenoh Liveliness tokens found in the Forge fabric.

Mix.install([
  {:zenohex, "~> 0.7.2"}
])

defmodule Forge.ServiceDashboard do
  def run() do
    {:ok, session} = Zenohex.open()

    # Subscribe to liveliness queries under "forge/services/**"
    # This will receive notifications when liveliness tokens appear/disappear
    liveliness_subscriber = Zenohex.Session.declare_subscriber(session, "forge/services/**", liveliness: true)

    IO.puts("Forge Service Dashboard")
    IO.puts("========================")
    IO.puts("Active AI Services:")
    IO.puts("")

    # Initial query to get current liveliness tokens
    query_current_liveliness(session)

    # Listen for changes (in a loop, printing updates)
    loop(liveliness_subscriber)
  end

  defp query_current_liveliness(session) do
    # To get current state, we can query for liveliness
    # Zenoh supports querying liveliness
    queryable = Zenohex.Session.declare_queryable(session, "forge/services/dashboard-query")

    # Perform a get query for liveliness
    # Note: This is a simplified example; actual implementation may vary based on Zenoh API
    Zenohex.Session.get(session, "forge/services/**", liveliness: true, queryable: queryable)
  end

  defp loop(subscriber) do
    Zenohex.Subscriber.loop(subscriber, fn sample ->
      case sample.kind do
        :put ->
          IO.puts("[+] #{sample.key_expr}")
        :delete ->
          IO.puts("[-] #{sample.key_expr}")
      end
    end)
  end
end

Forge.ServiceDashboard.run()
