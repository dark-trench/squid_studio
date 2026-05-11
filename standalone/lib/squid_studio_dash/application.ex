defmodule SquidStudioDash.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: SquidStudioDash.PubSub},
      SquidStudioDash.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SquidStudioDash.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
