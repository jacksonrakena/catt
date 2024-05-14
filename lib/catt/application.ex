defmodule Catt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CattWeb.Telemetry,
      Catt.Repo,
      {DNSCluster, query: Application.get_env(:catt, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Catt.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Catt.Finch},
      Catt.GameSupervisor,
      # Start a worker by calling: Catt.Worker.start_link(arg)
      # {Catt.Worker, arg},
      # Start to serve requests, typically the last entry
      CattWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Catt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CattWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
