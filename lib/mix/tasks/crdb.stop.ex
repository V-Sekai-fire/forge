defmodule Mix.Tasks.Crdb.Stop do
  @moduledoc """
  Stop CockroachDB.

  This task stops the running CockroachDB instance.

  ## Usage

      mix crdb.stop
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Stopping CockroachDB...")

    # Find and kill cockroach process
    case System.cmd("tasklist", ["/FI", "IMAGENAME eq cockroach.exe", "/NH"]) do
      {output, 0} ->
        if String.contains?(output, "cockroach.exe") do
          # Extract PID and kill process
          lines = String.split(output, "\n")
          Enum.each(lines, fn line ->
            if String.contains?(line, "cockroach.exe") do
              # Parse PID from line (format: "cockroach.exe    1234 Console    1    10,000 K")
              parts = String.split(String.trim(line))
              if length(parts) >= 2 do
                pid = Enum.at(parts, 1)
                case System.cmd("taskkill", ["/PID", pid, "/F"], stderr_to_stdout: true) do
                  {_output, 0} ->
                    Mix.shell().info("CockroachDB stopped (PID: #{pid})")
                  {error, _} ->
                    Mix.shell().error("Failed to stop CockroachDB: #{error}")
                end
              end
            end
          end)
        else
          Mix.shell().info("CockroachDB is not running")
        end

      {error, _} ->
        Mix.shell().error("Failed to check running processes: #{error}")
    end
  end
end
