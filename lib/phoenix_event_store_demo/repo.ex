defmodule PhoenixEventStoreDemo.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_event_store_demo,
    adapter: Ecto.Adapters.Postgres
end
