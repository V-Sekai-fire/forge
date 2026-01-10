defmodule LivebookNx.Repo.Migrations.CreateObanTables do
  use Ecto.Migration

  def change do
    # Create Oban jobs table
    execute """
    CREATE TABLE oban_jobs (
      id bigserial not null primary key,
      state text not null,
      queue text not null default 'default',
      worker text not null,
      args jsonb not null default '{}',
      errors jsonb not null default '[]',
      attempt integer not null default 0,
      max_attempts integer not null default 20,
      inserted_at timestamp without time zone not null default now(),
      scheduled_at timestamp without time zone not null default now(),
      attempted_at timestamp without time zone,
      completed_at timestamp without time zone,
      attempted_by text[],
      discarded_at timestamp without time zone,
      priority integer not null default 0,
      tags text[] not null default '{}',
      meta jsonb not null default '{}',
      cancelled_at timestamp without time zone,
      CONSTRAINT attempt_range CHECK (attempt >= 0 AND attempt <= max_attempts),
      CONSTRAINT priority_range CHECK (priority >= 0 AND priority <= 3),
      CONSTRAINT queue_length CHECK (char_length(queue) > 0 AND char_length(queue) < 128),
      CONSTRAINT worker_length CHECK (char_length(worker) > 0 AND char_length(worker) < 128),
      CONSTRAINT state_length CHECK (char_length(state) > 0)
    );
    """

    # Create indexes for Oban
    execute "CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_idx ON oban_jobs (state, queue, priority, scheduled_at, id);"
    execute "CREATE INDEX oban_jobs_scheduled_at_id_idx ON oban_jobs (scheduled_at, id) WHERE state = 'scheduled';"
  end
end
