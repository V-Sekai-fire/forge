#!/usr/bin/env python3
# python/inference_service.py
# Zenoh-based inference service for image generation using JSON.

import zenoh
import asyncio
import json
import urllib.parse

async def main():
    # Open Zenoh session
    async with zenoh.open(zenoh.Config()) as session:
        # Declare liveliness token
        liveliness = session.liveness().declare_token("forge/services/qwen3vl")

        # Declare queryable for requests (match client GET requests)
        queryable = session.declare_queryable("zimage/generate/**")

        print("Python Zenoh Inference Service started for Qwen.")

        async for query in queryable:
            # Parse parameters from key_expr (client sends "zimage/generate?params")
            key_expr = query.key_expr
            # key_expr like "zimage/generate?prompt=...&width=..."
            if '?' in key_expr:
                params_str = key_expr.split('?', 1)[1]
                params = urllib.parse.parse_qs(params_str)

                prompt = params.get('prompt', [''])[0]
                width = int(params.get('width', ['1024'])[0])
                height = int(params.get('height', ['1024'])[0])
                seed = int(params.get('seed', ['0'])[0])
                num_steps = int(params.get('num_steps', ['4'])[0])
                guidance_scale = float(params.get('guidance_scale', ['0.0'])[0])
                output_format = params.get('output_format', ['png'])[0]

                print(f"Received inference request: prompt={prompt[:50]}..., width={width}, height={height}")

                # Process inference (placeholder)
                output_path = await process_inference(prompt, width, height, seed, num_steps, guidance_scale, output_format)

                # Reply with JSON as expected by client
                response = {
                    "status": "success",
                    "output_path": output_path
                }
            else:
                response = {
                    "status": "error",
                    "reason": "Invalid request format"
                }

            # Reply
            await query.reply(json.dumps(response))

async def process_inference(prompt, width, height, seed, num_steps, guidance_scale, output_format):
    # Placeholder: integrate with actual AI model here
    # For example, call a preloaded model
    # result = model.predict(prompt, width, height, ...)
    # Here, simulate
    await asyncio.sleep(0.1)  # simulate processing
    return f"/tmp/generated_image.{output_format}"

if __name__ == "__main__":
    asyncio.run(main())
