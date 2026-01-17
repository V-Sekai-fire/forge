defmodule Zimage.ZenohService do
  @moduledoc """
  Zenoh service for Z-Image generation.

  This module provides a Zenoh queryable service that accepts image generation
  requests and responds with generated image paths.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Zimage Zenoh service...")

    # Open Zenoh session
    case Zenohex.Session.open() do
      {:ok, session_id} ->
        Logger.info("Zenoh session opened successfully")

        # Declare queryable for image generation requests
        case Zenohex.Nif.session_declare_queryable(session_id, "zimage/generate", self(), []) do
          {:ok, queryable_id} ->
            Logger.info("Zimage queryable declared at 'zimage/generate'")

            # Declare liveliness token
            {:ok, _token} = Zenohex.Nif.liveliness_declare_token(session_id, "zimage/service")

            {:ok, %{session_id: session_id, queryable_id: queryable_id}}

          {:error, reason} ->
            Logger.error("Failed to declare queryable: #{inspect(reason)}")
            {:stop, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to open Zenoh session: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def terminate(_reason, %{session_id: session_id}) do
    Zenohex.Session.close(session_id)
    Logger.info("Zimage Zenoh service terminated")
  end

  @impl true
  def handle_info({:zenoh_query, query}, %{session_id: session_id} = state) do
    Logger.info("Received generation request")

    try do
      # Parse query parameters (URL-encoded string)
      params = URI.decode_query(query.parameters)
      prompt = Map.get(params, "prompt", "")
      width = Map.get(params, "width", "1024") |> String.to_integer()
      height = Map.get(params, "height", "1024") |> String.to_integer()
      seed = Map.get(params, "seed", "0") |> String.to_integer()
      num_steps = Map.get(params, "num_steps", "4") |> String.to_integer()
      guidance_scale = Map.get(params, "guidance_scale", "0.0") |> String.to_float()
      output_format = Map.get(params, "output_format", "png")

      # Validate parameters
      with :ok <- validate_params(prompt, width, height) do
        # Generate image
        case Zimage.generate(prompt, [
          width: width,
          height: height,
          seed: seed,
          num_steps: num_steps,
          guidance_scale: guidance_scale,
          output_format: output_format
        ]) do
          {:ok, output_path} ->
            Logger.info("Image generated successfully: #{output_path}")
            # Reply to query
            Zenohex.Query.reply(query.zenoh_query, "zimage/generate/result", Jason.encode!(%{
              status: "success",
              output_path: output_path,
              prompt: prompt
            }))

          {:error, reason} ->
            Logger.error("Image generation failed: #{inspect(reason)}")
            Zenohex.Query.reply_error(query.zenoh_query, Jason.encode!(%{
              status: "error",
              reason: inspect(reason),
              prompt: prompt
            }))
        end
      else
        {:error, validation_error} ->
          Logger.warning("Invalid parameters: #{validation_error}")
          Zenohex.Query.reply_error(query.zenoh_query, Jason.encode!(%{
            status: "error",
            reason: "Invalid parameters: #{validation_error}"
          }))
      end

    rescue
      e ->
        Logger.error("Unexpected error processing query: #{inspect(e)}")
        Zenohex.Query.reply_error(query.zenoh_query, Jason.encode!(%{
          status: "error",
          reason: "Internal server error"
        }))
    end

    {:noreply, state}
  end

  defp validate_params(prompt, width, height) do
    cond do
      String.trim(prompt) == "" ->
        {:error, "Prompt cannot be empty"}

      width < 64 or width > 2048 ->
        {:error, "Width must be between 64 and 2048"}

      height < 64 or height > 2048 ->
        {:error, "Height must be between 64 and 2048"}

      true ->
        :ok
    end
  end
end