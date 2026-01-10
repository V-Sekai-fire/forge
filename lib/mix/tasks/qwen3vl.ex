defmodule Mix.Tasks.Qwen3vl do
  @moduledoc "Run Qwen3-VL inference"
  @shortdoc "qwen3vl <image_path> <prompt> [options]"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    # Start required applications
    Application.ensure_all_started(:pythonx)
    Application.ensure_all_started(:req)

    {opts, args, _} = OptionParser.parse(args,
      switches: [
        max_tokens: :integer,
        temperature: :float,
        top_p: :float,
        output: :string,
        use_flash_attention: :boolean,
        use_4bit: :boolean,
        full_precision: :boolean
      ],
      aliases: [
        m: :max_tokens,
        t: :temperature,
        o: :output
      ]
    )

    [image_path, prompt] = args

    config = LivebookNx.Qwen3VL.new(
      image_path: image_path,
      prompt: prompt,
      max_tokens: opts[:max_tokens],
      temperature: opts[:temperature],
      top_p: opts[:top_p],
      output_path: opts[:output],
      use_flash_attention: opts[:use_flash_attention],
      use_4bit: if(opts[:full_precision], do: false, else: opts[:use_4bit] || true)
    )

    LivebookNx.Qwen3VL.run(config)
  end
end
