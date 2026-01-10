defmodule Forge.Qwen3VL.Worker do
  @moduledoc """
  Oban worker for asynchronous Qwen3-VL vision-language inference.
  """

  use Oban.Worker,
    queue: :ml,
    max_attempts: 3,
    unique: [period: 300] # 5 minutes uniqueness

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"config" => config_params}}) do
    config = struct(Forge.Qwen3VL, config_params)

    Logger.info("Starting Qwen3-VL inference job", %{
      job_id: inspect(self()),
      image_path: config.image_path,
      prompt: config.prompt,
      max_tokens: config.max_tokens
    })

    case Forge.Qwen3VL.run(config) do
      {:ok, result} ->
        Logger.info("Qwen3-VL inference completed successfully", %{job_id: inspect(self())})
        {:ok, result}

      {:error, reason} ->
        Logger.error("Qwen3-VL inference failed", %{
          job_id: inspect(self()),
          reason: inspect(reason)
        })
        {:error, reason}
    end
  end
end
