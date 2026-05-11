# Squid Studio

Visual editor for Squid Mesh workflows.

## Embed In A Phoenix App

Add Squid Studio as a dependency, then mount it from the host router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import SquidStudio.Web.Router

  scope "/dev" do
    pipe_through :browser

    squid_studio "/squid-studio"
  end
end
```

Host applications can provide workflow data by implementing `SquidStudio.Web.Resolver`:

```elixir
defmodule MyApp.SquidStudioResolver do
  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(conn), do: conn.assigns[:current_user]

  @impl true
  def resolve_access(_user), do: :all

  @impl true
  def resolve_workflows(_user) do
    [
      %{
        id: "workflow",
        name: "Workflow",
        nodes: [],
        edges: []
      }
    ]
  end
end
```

Then pass it to the mount macro:

```elixir
squid_studio "/squid-studio", resolver: MyApp.SquidStudioResolver
```

## Standalone Development

```sh
mix deps.get
mix assets.build
cd standalone
mix phx.server
```

Visit `http://localhost:4000`.

Run validation with:

```sh
mix precommit
```
