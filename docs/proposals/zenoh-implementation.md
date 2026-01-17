# Proposal: Implementing Zenoh Protocol in Forge for Distributed AI Processing

## Overview

Forge is a multi-modal AI content creation platform that integrates various AI models and processing tools. Currently, the system uses standalone Elixir scripts in the `elixir/` directory for tasks like image generation, vision-language processing, TTS synthesis, and 3D processing. To enable efficient coordination and communication between these components, we propose implementing the Zenoh protocol using Zenohex as the messaging backbone.

## Background

### Current Architecture

- **Standalone Scripts**: Each AI task runs as an independent `.exs` script
- **No Inter-Process Communication**: Scripts operate in isolation
- **Manual Coordination**: Users must manually chain operations
- **Limited Scalability**: No distributed processing capabilities

### Zenoh Protocol

Zenoh is a high-performance, peer-to-peer protocol designed for distributed systems and IoT. It provides:

- **Pub/Sub**: Publish-subscribe messaging
- **Query/Reply**: Request-response patterns
- **Storage**: Distributed key-value storage
- **Liveliness**: Service discovery and health monitoring
- **Zero-Overhead**: Minimal latency and resource usage

Zenohex is the official Elixir client library for Zenoh, built using Rustler for high performance.

## Proposed Implementation

### 1. Core Components

#### Zenoh Session Management

- **Peer Mode**: Brokerless P2P communication
- **Automatic Discovery**: Services find each other without configuration
- **URI-Based Addressing**: Path-based resource identification (`forge/inference/**`)

#### Resource Providers

- **Queryables**: Scripts that provide AI inference services
- **Storages**: Distributed state management for model status
- **Publishers**: Real-time status updates and results

### 2. Message Flow Architecture

```
User Request → FlatBuffers Encode → Zenoh Network → FlatBuffers Decode → Processing Pipeline
    ↓              ↓              ↓              ↓              ↓
Qwen3-VL     Z-Image-Turbo    Kokoro TTS     Inference       Synthesis
Analysis     Generation       Synthesis      Results         Results
    ↓              ↓              ↓              ↓              ↓
FlatBuffers → Pub/Sub Updates → FlatBuffers → Client Notifications
Encode       Updates          Decode
```

### 3. Protocol Implementation

### Zenohex Integration

Add to `mix.exs` (when Elixir app is restored):

```elixir
defp deps do
  [
    {:zenohex, "~> 0.7.2"},
    {:flatbuffer, "~> 0.3.1"}
  ]
end
```

### FlatBuffers Serialization

To ensure efficient, cross-platform message serialization for AI processing data (images, tensors, metadata), we will use FlatBuffers. FlatBuffers provides zero-copy deserialization and compact binary formats ideal for high-performance distributed systems.

#### Message Schemas

Define FlatBuffers schemas for common message types:

```fbs
// inference_request.fbs
table InferenceRequest {
  image_data:[ubyte];
  prompt:string;
  model:string;
}

table InferenceResponse {
  result_data:[ubyte];
  metadata:string;
}
```

Generate Elixir modules from these schemas using the FlatBuffers compiler.

#### Inference Node Example

```elixir
# elixir/qwen_inference_node.exs
# Open a Zenoh session in Peer mode
{:ok, session} = Zenohex.open()

# Declare a 'Queryable' for inference requests
{:ok, queryable} = Zenohex.Session.declare_queryable(session, "forge/inference/qwen")

# Listen for incoming requests
Task.start(fn ->
  Zenohex.Queryable.loop(queryable, fn query ->
    # Extract FlatBuffers-encoded parameters from query
    payload = Zenohex.Query.payload(query)
    request = InferenceRequest.decode(payload)

    image_data = request.image_data
    prompt = request.prompt

    # Run AI inference
    result = Qwen3VL.infer(image_data, prompt)

    # Serialize response with FlatBuffers
    response = InferenceResponse.new(result_data: result.data, metadata: result.metadata)
    encoded_response = InferenceResponse.encode(response)

    # Reply directly to requester
    Zenohex.Query.reply(query, "forge/inference/qwen/result", encoded_response)
  end)
end)
```

#### Model Status Storage

```elixir
# Publish model loading status
{:ok, storage} = Zenohex.Session.declare_storage(session, "forge/weights/status")

# Update status when weights are loaded
Zenohex.Storage.put(storage, "qwen3vl", "loaded")
Zenohex.Storage.put(storage, "zimage", "loading")
```

### 4. Script Integration

#### Current Script Structure

- `qwen3vl_inference.exs`: Vision-language analysis
- `zimage_generation.exs`: Image generation
- `kokoro_tts_generation.exs`: Text-to-speech
- `sam3_video_segmentation.exs`: Video processing

#### Modified Script Structure

Each script becomes a Zenoh resource provider with FlatBuffers serialization:

```elixir
defmodule Forge.Scripts.Qwen3VL do
  def run() do
    # Open Zenoh session
    {:ok, session} = Zenohex.open()

    # Declare queryable
    {:ok, queryable} = Zenohex.Session.declare_queryable(session, "forge/inference/qwen")

    # Publish liveliness token
    {:ok, liveliness} = Zenohex.Session.declare_liveliness(session, "forge/services/qwen3vl")

    # Process requests
    Zenohex.Queryable.loop(queryable, fn query ->
      # Deserialize request
      payload = Zenohex.Query.payload(query)
      request = InferenceRequest.decode(payload)

      # Handle inference request
      result = process_inference(request)

      # Serialize and reply
      response = InferenceResponse.new(result_data: result.data, metadata: result.metadata)
      encoded = InferenceResponse.encode(response)
      Zenohex.Query.reply(query, encoded)
    end)
  end
end
```

### 5. Benefits

#### Improved Coordination

- **Automatic Discovery**: Services find each other without configuration
- **Peer-to-Peer**: No single point of failure
- **Low Latency**: Zero-overhead protocol design with efficient FlatBuffers serialization
- **Cross-Platform**: FlatBuffers enables language-agnostic message formats

#### Scalability

- **Horizontal Scaling**: Add more processing nodes dynamically
- **Resource Management**: Monitor and allocate compute resources
- **Fault Tolerance**: Automatic failover and recovery

#### Developer Experience

- **URI-Based**: Intuitive path-based resource addressing
- **Real-time Monitoring**: Liveliness tokens for service health
- **Storage Integration**: Distributed state management

## Implementation Plan

### Phase 1: Core Protocol (Week 1-2)

- Add Zenohex dependency
- Implement basic session management
- Unit tests for peer discovery

### Phase 2: Queryable Services (Week 3)

- Convert one script to Zenoh queryable
- Test P2P communication
- Implement parameter parsing

### Phase 3: Storage & Liveliness (Week 4)

- Add model status storage
- Implement liveliness monitoring
- Create service discovery utilities

### Phase 4: Full Integration (Week 5-6)

- Convert remaining scripts
- Add monitoring and metrics
- Performance optimization

## Dependencies

- **Zenohex**: Zenoh client for Elixir (~> 0.7.2)
- **FlatBuffers**: Efficient serialization library for Elixir (~> 0.1)
- **Erlang/OTP 25+**: For NIF support
- **Elixir 1.14+**: For scripting

## Risk Assessment

### Low Risk

- Zenohex is actively maintained
- Zenoh has proven performance characteristics
- Incremental migration approach

### Mitigation Strategies

- Start with simple query-reply patterns
- Comprehensive testing of P2P discovery
- Rollback to standalone scripts if needed

## Success Metrics

- **Latency**: <1ms message routing
- **Discovery**: <100ms service discovery
- **Throughput**: 10,000+ messages/second
- **Reliability**: 99.99% message delivery

## Comparison with Alternatives

| Feature         | ZeroMQ (Chumak)  | Zenoh (Zenohex)   |
| --------------- | ---------------- | ----------------- |
| **Discovery**   | Manual / ZBeacon | **Automatic P2P** |
| **Addressing**  | IP/Port          | **URI Paths**     |
| **Storage**     | None             | **Built-in**      |
| **Liveliness**  | None             | **Built-in**      |
| **Performance** | High             | **Zero-Overhead** |

## Conclusion

Implementing Zenoh in Forge with FlatBuffers serialization will transform our collection of standalone scripts into a cohesive, distributed AI processing network. By leveraging Zenohex and Zenoh's peer-to-peer architecture combined with FlatBuffers' efficient zero-copy serialization, we can achieve reliable inter-process communication without brokers or complex configuration.

The automatic discovery, URI-based addressing, and compact binary message formats make it ideal for dynamic AI processing environments where services come and go, and data efficiency is critical.

**Ready to proceed with Phase 1 implementation?**
