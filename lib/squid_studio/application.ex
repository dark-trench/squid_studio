defmodule SquidStudio.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: SquidStudio.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(_changed, _new, _removed), do: :ok
end
