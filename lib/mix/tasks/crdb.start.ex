defmodule Mix.Tasks.Crdb.Start do
  @moduledoc """
  Start CockroachDB with TLS certificates.

  This task starts a single-node CockroachDB instance with the generated
  TLS certificates for secure development use.

  ## Usage

      mix crdb.start

  The task will:
  1. Check if CockroachDB is already running
  2. Start CockroachDB with TLS certificates
  3. Wait for it to be ready
  4. Create the database if it doesn't exist
  """
  use Mix.Task

  @cockroach_path "tools/cockroach-v22.1.22.windows-6.2-amd64/cockroach.exe"
  @certs_dir "cockroach-certs"

  @impl Mix.Task
  def run(_args) do
    # Ensure certificates exist
    unless File.exists?(@certs_dir) do
      Mix.shell().error("Certificate directory '#{@certs_dir}' not found. Run certificate generation first.")
      exit({:shutdown, 1})
    end

    # Check if CockroachDB is already running
    if cockroach_running?() do
      Mix.shell().info("CockroachDB is already running")
      print_connection_info()
      exit(:normal)
    end

    Mix.shell().info("Starting CockroachDB...")

    # Start CockroachDB
    case start_cockroach() do
      {:ok, _pid} ->
        Mix.shell().info("CockroachDB started successfully")
        wait_for_ready()
        create_database()
        print_connection_info()

      {:error, reason} ->
        Mix.shell().error("Failed to start CockroachDB: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp cockroach_running? do
    case System.cmd("tasklist", ["/FI", "IMAGENAME eq cockroach.exe", "/NH"]) do
      {output, 0} ->
        String.contains?(output, "cockroach.exe")
      _ ->
        false
    end
  end

  defp start_cockroach do
    # Start CockroachDB in background using PowerShell Start-Process
    # start-single-node runs in foreground by default, so we use Start-Process
    abs_cockroach_path = Path.absname(@cockroach_path)
    abs_certs_dir = Path.absname(@certs_dir)

    ps_command = """
    $cockroachPath = "#{abs_cockroach_path}"
    $certsDir = "#{abs_certs_dir}"
    Start-Process -FilePath $cockroachPath -ArgumentList "start-single-node", "--certs-dir=$certsDir", "--listen-addr=localhost:26257", "--http-addr=localhost:8080" -NoNewWindow -RedirectStandardOutput "cockroach.out" -RedirectStandardError "cockroach.err"
    """

    case System.cmd("powershell.exe", ["-Command", ps_command], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("CockroachDB start initiated")
        # Give it a moment to start
        Process.sleep(3000)
        {:ok, :started}
      {output, code} ->
        {:error, "Exit code #{code}: #{output}"}
    end
  end

  defp wait_for_ready do
    Mix.shell().info("Waiting for CockroachDB to be ready...")

    # Try to connect for up to 30 seconds
    Enum.each(1..30, fn _ ->
      case System.cmd(@cockroach_path, ["sql", "--certs-dir=#{@certs_dir}", "--execute=SELECT 1", "--format=csv"], stderr_to_stdout: true) do
        {_output, 0} ->
          Mix.shell().info("CockroachDB is ready!")
          throw(:ready)
        _ ->
          Process.sleep(1000)
      end
    end)

    Mix.shell().error("CockroachDB failed to start within 30 seconds")
    exit({:shutdown, 1})
  catch
    :ready -> :ok
  end

  defp create_database do
    Mix.shell().info("Creating database 'livebook_nx_dev'...")

    sql = "CREATE DATABASE IF NOT EXISTS livebook_nx_dev;"

    case System.cmd(@cockroach_path, ["sql", "--certs-dir=#{@certs_dir}", "--execute=#{sql}"], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("Database created successfully")
      {output, _code} ->
        Mix.shell().error("Failed to create database: #{output}")
    end
  end

  defp print_connection_info do
    Mix.shell().info("")
    Mix.shell().info("CockroachDB Connection Info:")
    Mix.shell().info("  Host: localhost:26257")
    Mix.shell().info("  Database: livebook_nx_dev")
    Mix.shell().info("  User: root")
    Mix.shell().info("  Password: secure_password_123")
    Mix.shell().info("  SSL: enabled")
    Mix.shell().info("  Web UI: https://localhost:8080")
    Mix.shell().info("")
    Mix.shell().info("To connect manually:")
    Mix.shell().info("  .\\#{@cockroach_path} sql --certs-dir=#{@certs_dir}")
  end
end
