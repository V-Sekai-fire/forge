defmodule Forge.Qwen3VL do
  @moduledoc """
  Qwen3-VL Vision-Language Inference Module
  """

  require Logger

  # Load shared utilities
  Code.eval_file("lib/forge/shared_utils.exs")

  @model_id "huihui-ai/Huihui-Qwen3-VL-4B-Instruct-abliterated"
  @weights_dir "priv/pretrained_weights/Huihui-Qwen3-VL-4B-Instruct-abliterated"

  defstruct [
    :image_path,
    :prompt,
    :max_tokens,
    :temperature,
    :top_p,
    :output_path,
    :use_flash_attention,
    :use_4bit
  ]

  def new(opts \\ []) do
    %__MODULE__{
      image_path: opts[:image_path],
      prompt: opts[:prompt],
      max_tokens: opts[:max_tokens] || 4096,
      temperature: opts[:temperature] || 0.7,
      top_p: opts[:top_p] || 0.9,
      output_path: opts[:output_path],
      use_flash_attention: opts[:use_flash_attention] || false,
      use_4bit: opts[:use_4bit] || true
    }
  end

  def run(%__MODULE__{} = config) do
    # Validate inputs
    validate_config(config)

    # Download model if needed
    download_model()

    # Run inference
    do_inference(config)
  end

  defp validate_config(config) do
    unless config.image_path && File.exists?(config.image_path) do
      raise "Image file not found: #{config.image_path}"
    end

    unless config.prompt do
      raise "Prompt is required"
    end
  end

  defp download_model do
    # Use shared downloader
    case HuggingFaceDownloader.download_repo(@model_id, @weights_dir, "Qwen3-VL", false) do
      {:ok, _} -> :ok
      {:error, _} -> Logger.warning("Model download had errors, continuing...")
    end
  end

  defp do_inference(config) do
    # Python environment is initialized automatically via config

    # Python code for inference (adapted from script)
    python_code = """
import json
import sys
import os
from pathlib import Path
import torch
from PIL import Image
from transformers import Qwen3VLForConditionalGeneration, AutoProcessor, BitsAndBytesConfig

# Model setup
MODEL_ID = "#{@model_id}"
device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.bfloat16 if device == "cuda" else torch.float32

quantization_config = None
if #{if config.use_4bit, do: "True", else: "False"} and device == "cuda":
    quantization_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
        bnb_4bit_quant_type="nf4"
    )
    dtype = None

load_kwargs = {
    "device_map": "auto",
    "trust_remote_code": True,
    "low_cpu_mem_usage": True,
    "attn_implementation": "flash_attention_2" if #{if config.use_flash_attention, do: "True", else: "False"} else "sdpa",
}

if quantization_config:
    load_kwargs["quantization_config"] = quantization_config
elif dtype:
    load_kwargs["dtype"] = dtype

model_path = "#{@weights_dir}"
if Path(model_path).exists() and (Path(model_path) / "config.json").exists():
    model = Qwen3VLForConditionalGeneration.from_pretrained(model_path, **load_kwargs)
else:
    model = Qwen3VLForConditionalGeneration.from_pretrained(MODEL_ID, **load_kwargs)

processor = AutoProcessor.from_pretrained(MODEL_ID, trust_remote_code=True)

# Load image
image = Image.open("#{config.image_path}").convert("RGB")

# Prepare messages
messages = [
    {
        "role": "user",
        "content": [
            {"type": "image", "image": "#{config.image_path}"},
            {"type": "text", "text": "#{String.replace(config.prompt, "\"", "\\\"")}"},
        ],
    }
]

inputs = processor.apply_chat_template(
    messages,
    tokenize=True,
    add_generation_prompt=True,
    return_dict=True,
    return_tensors="pt"
).to(model.device)

# Generate
generated_ids = model.generate(
    **inputs,
    max_new_tokens=#{config.max_tokens},
    temperature=#{config.temperature},
    top_p=#{config.top_p},
    do_sample=#{if config.temperature > 0.0, do: "True", else: "False"},
)

generated_ids_trimmed = [
    out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
]

output_text = processor.batch_decode(
    generated_ids_trimmed,
    skip_special_tokens=True,
    clean_up_tokenization_spaces=False
)

response = output_text[0] if output_text else ""
print(response)
"""

    {result, _} = Pythonx.eval(python_code, %{})
    result
  end

  @doc """
  Queue Qwen3-VL inference for asynchronous processing.

  ## Parameters
  - `image_path` - Path to the input image
  - `prompt` - Text prompt for the model
  - `opts` - Additional options

  ## Options
  - `:max_tokens` - Maximum tokens to generate (default: 4096)
  - `:temperature` - Sampling temperature (default: 0.7)
  - `:top_p` - Top-p sampling (default: 0.9)
  - `:output_path` - Path to save results (optional)
  - `:use_flash_attention` - Use flash attention (default: false)
  - `:use_4bit` - Use 4-bit quantization (default: true)

  ## Examples

      iex> LivebookNx.Qwen3VL.queue_inference("image.jpg", "Describe this image")
      {:ok, %Oban.Job{}}
  """
  @spec queue_inference(String.t(), String.t(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def queue_inference(image_path, prompt, opts \\ []) do
    config = %{
      image_path: image_path,
      prompt: prompt,
      max_tokens: Keyword.get(opts, :max_tokens, 4096),
      temperature: Keyword.get(opts, :temperature, 0.7),
      top_p: Keyword.get(opts, :top_p, 0.9),
      output_path: Keyword.get(opts, :output_path),
      use_flash_attention: Keyword.get(opts, :use_flash_attention, false),
      use_4bit: Keyword.get(opts, :use_4bit, true)
    }

    case validate_config(struct(__MODULE__, config)) do
      :ok ->
        %{config: config}
        |> Forge.Qwen3VL.Worker.new()
        |> Oban.insert()
      {:error, reason} ->
        {:error, reason}
    end
  end
end
