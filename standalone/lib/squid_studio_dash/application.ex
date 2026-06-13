defmodule SquidStudioDash.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: SquidStudioDash.PubSub},
      %{
        id: SquidStudioDash.Resolver.Drafts,
        start: {Agent, :start_link, [fn -> %{} end, [name: SquidStudioDash.Resolver.Drafts]]}
      },
      SquidStudioDash.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SquidStudioDash.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
