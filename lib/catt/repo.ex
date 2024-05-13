defmodule Catt.Repo do
  use Ecto.Repo,
    otp_app: :catt,
    adapter: Ecto.Adapters.Postgres
end
