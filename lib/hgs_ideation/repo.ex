defmodule HgsIdeation.Repo do
  use Ecto.Repo,
    otp_app: :hgs_ideation,
    adapter: Ecto.Adapters.Postgres
end
