defmodule FedecksDev.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FedecksDevWeb.Telemetry,
      {Phoenix.PubSub, name: FedecksDev.PubSub},
      FedecksDevWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: FedecksDev.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    FedecksDevWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
