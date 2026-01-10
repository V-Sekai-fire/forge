defmodule LivebookNx.Repo do
  use Ecto.Repo,
    otp_app: :livebook_nx,
    adapter: Ecto.Adapters.SQLite3
end
