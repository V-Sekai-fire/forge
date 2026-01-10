defmodule Forge.ZImage.Worker do
  @moduledoc """
  Oban worker for asynchronous Z-Image generation.
  """

  use Oban.Worker,
    queue: :ml,
    max_attempts: 3,
    unique: [period: 300] # 5 minutes uniqueness

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"config" => config_params}}) do
    config = struct(Forge.ZImage, config_params)

    Logger.info("Starting Z-Image generation job", %{
      job_id: inspect(self()),
      prompt: String.slice(config.prompt, 0, 50), # Log first 50 chars for privacy
      width: config.width,
      height: config.height,
      num_steps: config.num_steps
    })

    case Forge.ZImage.run(config) do
      {:ok, result} ->
        Logger.info("Z-Image generation completed successfully", %{job_id: inspect(self())})
        {:ok, result}

      {:error, reason} ->
        Logger.error("Z-Image generation failed", %{
          job_id: inspect(self()),
          reason: inspect(reason)
        })
        {:error, reason}
    end
  end
end
