defmodule SquidStudio.Web.Resolver do
  @moduledoc """
  Behavior for host applications that embed Squid Studio.

  The default resolver exposes a small sample workflow so the editor can render
  before a host app wires in real Squid Mesh workflow discovery.
  """

  @callback resolve_user(Plug.Conn.t()) :: term()
  @callback resolve_access(term()) :: :all | :read_only
  @callback resolve_workflows(term()) :: [map()]

  def call_with_fallback(resolver, callback, args) do
    if function_exported?(resolver, callback, length(args)) do
      apply(resolver, callback, args)
    else
      apply(__MODULE__, callback, args)
    end
  end

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all

  @doc false
  def resolve_workflows(_user) do
    [
      %{
        id: "daily_digest",
        name: "Daily Digest",
        nodes: [
          %{
            id: "fetch_feed",
            type: "input",
            position: %{x: 0, y: 80},
            data: %{label: "fetch_feed"}
          },
          %{id: "build_digest", position: %{x: 240, y: 80}, data: %{label: "build_digest"}},
          %{id: "approval", position: %{x: 480, y: 80}, data: %{label: "approval"}},
          %{id: "publish", type: "output", position: %{x: 720, y: 80}, data: %{label: "publish"}}
        ],
        edges: [
          %{id: "fetch_feed-build_digest", source: "fetch_feed", target: "build_digest"},
          %{id: "build_digest-approval", source: "build_digest", target: "approval"},
          %{id: "approval-publish", source: "approval", target: "publish"}
        ]
      }
    ]
  end
end
