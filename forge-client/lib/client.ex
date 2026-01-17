defmodule ZimageClient.Client do
  @moduledoc """
  Zenoh client for requesting Z-Image generation.

  This module provides functions to send image generation requests
  to Zimage services via Zenoh.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate an image using the Zenoh service.

  ## Parameters
  - prompt: Text description of the image
  - opts: Keyword list of options

  ## Options
  - timeout: Request timeout in milliseconds (default: 30000)
  - width: Image width (default: 1024)
  - height: Image height (default: 1024)
  - seed: Random seed (default: 0)
  - num_steps: Number of inference steps (default: 4)
  - guidance_scale: Guidance scale (default: 0.0)
  - output_format: Output format (default: "png")

  ## Returns
  - {:ok, output_path} on success
  - {:error, reason} on failure
  """
  def generate(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:generate, prompt, opts}, 60_000)
  end

  @doc """
  Generate multiple images using the Zenoh service.

  ## Parameters
  - prompts: List of text prompts
  - opts: Options (same as generate/2)

  ## Returns
  - {:ok, results} - List of {:ok, path} | {:error, reason} tuples
  - {:error, reason} on connection failure
  """
  def generate_batch(prompts, opts \\ []) when is_list(prompts) do
    GenServer.call(__MODULE__, {:generate_batch, prompts, opts}, 120_000)
  end

  @doc """
  Check if Zimage service is available.

  ## Returns
  - :ok if service is available
  - {:error, reason} if not available
  """
  def ping do
    GenServer.call(__MODULE__, :ping)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting ZimageClient...")

    case Zenohex.Session.open() do
      {:ok, session_id} ->
        Logger.info("Zenoh session opened for client")
        {:ok, %{session_id: session_id}}

      {:error, reason} ->
        Logger.error("Failed to open Zenoh session: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:generate, prompt, opts}, _from, %{session_id: session_id} = state) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    # Build selector with parameters
    selector =
      "zimage/generate?" <>
        URI.encode_query(%{
          "prompt" => prompt,
          "width" => Integer.to_string(Keyword.get(opts, :width, 1024)),
          "height" => Integer.to_string(Keyword.get(opts, :height, 1024)),
          "seed" => Integer.to_string(Keyword.get(opts, :seed, 0)),
          "num_steps" => Integer.to_string(Keyword.get(opts, :num_steps, 4)),
          "guidance_scale" => Float.to_string(Keyword.get(opts, :guidance_scale, 0.0)),
          "output_format" => Keyword.get(opts, :output_format, "png")
        })

    case Zenohex.Session.get(session_id, selector, timeout) do
      {:ok, replies} ->
        # Process replies
        process_replies(replies)

      {:error, reason} ->
        {:reply, {:error, "Failed to send request: #{inspect(reason)}"}, state}
    end
  end

  @impl true
  def handle_call({:generate_batch, prompts, opts}, _from, %{session_id: session_id} = state) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    # Send requests concurrently
    tasks =
      Enum.map(prompts, fn prompt ->
        Task.async(fn ->
          selector = build_selector(prompt, opts)
          send_batch_request(session_id, selector, timeout, prompt)
        end)
      end)

    # Collect results
    results =
      Task.yield_many(tasks, timeout + 1000)
      |> Enum.map(&process_task_result/1)

    {:reply, {:ok, results}, state}
  end

  defp build_selector(prompt, opts) do
    "zimage/generate?" <>
      URI.encode_query(%{
        "prompt" => prompt,
        "width" => Integer.to_string(Keyword.get(opts, :width, 1024)),
        "height" => Integer.to_string(Keyword.get(opts, :height, 1024)),
        "seed" => Integer.to_string(Keyword.get(opts, :seed, 0)),
        "num_steps" => Integer.to_string(Keyword.get(opts, :num_steps, 4)),
        "guidance_scale" => Float.to_string(Keyword.get(opts, :guidance_scale, 0.0)),
        "output_format" => Keyword.get(opts, :output_format, "png")
      })
  end

  defp send_batch_request(session_id, selector, timeout, prompt) do
    case Zenohex.Session.get(session_id, selector, timeout) do
      {:ok, replies} ->
        case process_replies(replies) do
          {:ok, path} -> {:ok, prompt, path}
          {:error, reason} -> {:error, prompt, reason}
        end

      {:error, reason} ->
        {:error, prompt, "Request failed: #{inspect(reason)}"}
    end
  end

  defp process_task_result({task, result}) do
    case result do
      {:ok, reply} -> reply
      {:exit, reason} -> {:error, "unknown", "Task failed: #{inspect(reason)}"}
      nil -> {:error, "unknown", "Request timeout"}
    end
  end

  @impl true
  def handle_call(:ping, _from, %{session_id: session_id} = state) do
    case Zenohex.Session.get(session_id, "zimage/generate?prompt=test", 2000) do
      {:ok, _replies} ->
        {:reply, :ok, state}

      {:error, _reason} ->
        {:reply, {:error, "Service not available"}, state}
    end
  end

  @impl true
  def terminate(_reason, %{session_id: session_id}) do
    Zenohex.Session.close(session_id)
    Logger.info("ZimageClient terminated")
  end

  # Helper functions

  defp process_replies(replies) do
    # Find the first successful reply
    success_reply = find_success_reply(replies)
    error_reply = find_error_reply(replies)

    cond do
      success_reply -> extract_success_path(success_reply)
      error_reply -> extract_error_reason(error_reply)
      true -> {:error, "No valid response received"}
    end
  end

  defp find_success_reply(replies) do
    Enum.find(replies, &success_reply?/1)
  end

  defp find_error_reply(replies) do
    Enum.find(replies, &error_reply?/1)
  end

  defp success_reply?(%Zenohex.Sample{payload: payload}) do
    case Jason.decode(payload) do
      {:ok, %{"status" => "success"}} -> true
      _ -> false
    end
  end

  defp success_reply?(_), do: false

  defp error_reply?(%Zenohex.Sample{payload: payload}) do
    case Jason.decode(payload) do
      {:ok, %{"status" => "error"}} -> true
      _ -> false
    end
  end

  defp error_reply?(_), do: false

  defp extract_success_path(%Zenohex.Sample{payload: payload}) do
    {:ok, data} = Jason.decode(payload)
    {:ok, data["output_path"]}
  end

  defp extract_error_reason(%Zenohex.Sample{payload: payload}) do
    {:ok, data} = Jason.decode(payload)
    {:error, data["reason"]}
  end
end
