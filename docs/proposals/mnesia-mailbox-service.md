# Mnesia + Zenoh: The "Goldilocks" Mailbox Service

[![Proposal Status: Draft](https://img.shields.io/badge/status-draft-yellow.svg)](#)

Choosing **Mnesia** for a Zenoh-backed mailbox service is the "Goldilocks" choice. It's built into Erlang/Elixir (no external dependencies), supports distributed replication out of the box, and is significantly faster and simpler to implement than a full Raft (RA) cluster for this specific use case.

In this architecture, **Zenoh** provides the "Global Nervous System" (transport and discovery), while **Mnesia** provides the "Long-term Memory" (durable, replicated mailboxes).

## 1. The Architecture: Zenoh + Mnesia

Instead of a single Malamute broker, you have a **cluster of Elixir nodes**. Any node can receive a message via Zenoh, and Mnesia ensures that message is replicated to all other nodes in the cluster.

### How it works

1. **Storage Logic:** Your Elixir service registers as a Zenoh **Queryable** or **Storage**.
2. **Persistence:** When a `PUT` arrives, the Elixir node writes it to a Mnesia table.
3. **Consumption:** When a user calls `GET`, the service reads from Mnesia. To simulate a "mailbox" (where reading consumes the message), you perform a **Read + Delete** inside a Mnesia transaction.

## 2. Minimal Conceptual Implementation

You would use the [`Zenohex`](https://hex.pm/packages/zenohex) library (the Elixir bindings for Zenoh) and the standard `:mnesia` module.

### Step 1: Define the Mailbox Table

```elixir
# lib/my_app/db.ex
defmodule MyApp.DB do
  def setup do
    :mnesia.create_schema([node()])
    :mnesia.start()

    # A table for mailboxes: {id, user_id, payload, timestamp}
    :mnesia.create_table(:mailboxes, [
      attributes: [:id, :user, :data, :ts],
      disc_copies: [node()], # Persist to disk
      type: :ordered_set
    ])
  end
end
```

### Step 2: The Zenoh-Mnesia Bridge

This logic would live inside a GenServer that manages your Zenoh session.

```elixir
# Pseudo-logic for handling a Zenoh Query
def handle_zenoh_query(query) do
  user_id = parse_user_from_key(query.key_expr)

  # A Mnesia transaction ensures "Atomic Pop"
  result = :mnesia.transaction(fn ->
    # 1. Find the oldest message for this user
    case :mnesia.match_object({:mailboxes, :_, user_id, :_, :_}) do
      [msg | _] ->
        :mnesia.delete_object(msg) # 2. Delete it (the "mailbox" effect)
        msg
      [] -> nil
    end
  end)

  # 3. Send the message back via Zenoh
  reply_to_zenoh(query, result)
end
```

## 3. Why this is "Malamute-Style"

* **Persistence:** If an Elixir node goes down, the messages are safe on disk.
* **Distribution:** If you have three Elixir nodes, Mnesia keeps them in sync. A client can connect to *any* node in the Zenoh network and query their mailbox.
* **Decoupling:** Zenoh handles the routing. You don't need to know the IP of the "Mailbox Service"; you just query `mailbox/alice`.

## 4. The "Minimal Usefulness" Factor

To make this truly useful, you can add **TTL (Time To Live)** logic. Elixir can run a background task every minute to delete records from Mnesia that are older than 24 hours. This prevents your "Malamute" service from eating up all your disk space if users never check their mail.

## Deployment Pattern

Your Forge platform can extend this architecture for **user-specific services**:

```elixir
# Forge Mailbox Service (run on any Elixir node)
# Registers to Zenoh as: forge/mailbox/*

# Put message for user
PUT forge/mailbox/user123 {"message": "Your AI generation is ready"}
PUT forge/mailbox/admin {"alert": "System maintenance in 5 minutes"}

# Get next message (consumes it)
GET forge/mailbox/user123
# Returns: {"message": "Your AI generation is ready", "id": "msg_456"}

# Client continues polling
GET forge/mailbox/user123
# Returns: null (mailbox empty)
```

## Comparison Summary

| Feature | Malamute (Original) | Zenoh Native Storage | Elixir + Mnesia |
| --- | --- | --- | --- |
| **Broker Architecture** | Single-point bottleneck | Sharded by key | **Distributed cluster** |
| **Persistence** | Custom implementation | Basic disk storage | **ACID + Replication** |
| **Logic** | Static (Put/Get) | Static (Put/Get) | **Custom** (Read-and-Delete, Filter) |
| **Reliability** | Manual failover | Basic replication | **Auto-healing cluster** |
| **Scaling** | Single instance limit | Sharded by Key | **Replicated** across Erlang nodes |
| **Complexity** | High (custom broker) | Very Low | Moderate |
| **Dependencies** | ZeroMQ + Custom | Zenoh primitives | Built into Erlang/Elixir |

## Implementation Benefits

### Why "Goldilocks"

* **Simpler than Raft:** No consensus protocol complexity
* **Built-in:** No additional dependencies to manage
* **Erlang Distributed:** Automatic node discovery and syncing
* **ACID Properties:** Proper transactions for message operations
* **OTT Performance:** Custom logic fits exactly what mailboxes need

### Production Benefits

* **High Availability:** Messages survive node crashes with replication
* **Horizontal Scaling:** Add more Elixir nodes for more processing power
* **Network Efficiency:** Zenoh routes queries to nearest node
* **Operational Simplicity:** Standard Erlang operations and monitoring

## Mix Configuration Example

```elixir
# mix.exs
defp deps do
  [
    {:zenohex, "~> 0.7.2"}  # Zenoh Elixir bindings
  ]
end
```

```erlang
# vm.args
# For distributed Erlang cluster
-name mailbox_service@<hostname>
-cookie our_secret_cookie
```

## Next Steps

Would you like me implement a complete working example that:
1. Sets up Mnesia with distributed mailboxes
2. Implements the Zenoh Queryable interface
3. Demonstrates message PUT/GET patterns
4. Handles TTL cleanup and replication
5. Provides Forge integration examples

This would give you a **production-ready, highly available mailbox service** that maintains the simplicity原则 while adding proper persistence and reliability.
