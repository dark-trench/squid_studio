defmodule SquidStudio.Web.Resolver do
  @moduledoc """
  Behavior for host applications that embed Squid Studio.

  The default resolver exposes a small sample workflow so the editor can render
  before a host app wires in real Squidie workflow discovery.
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
        name: "Daily RSS To Discord",
        nodes: [
          node("daily_digest", "trigger :daily_digest", :trigger, 0, 80),
          node("fetch_feed", "step :fetch_feed", :step, 240, 80),
          node("build_digest", "step :build_digest", :step, 480, 80),
          node("post_to_discord", "step :post_to_discord", :retry, 720, 80),
          node("complete", ":complete", :terminal, 960, 80),
          node("record_failed_delivery", "failure route", :failure, 960, 220)
        ],
        edges: [
          %{id: "daily_digest-fetch_feed", source: "daily_digest", target: "fetch_feed"},
          %{id: "fetch_feed-build_digest", source: "fetch_feed", target: "build_digest"},
          %{
            id: "build_digest-post_to_discord",
            source: "build_digest",
            target: "post_to_discord"
          },
          %{id: "post_to_discord-complete", source: "post_to_discord", target: "complete"},
          %{
            id: "post_to_discord-record_failed_delivery",
            source: "post_to_discord",
            target: "record_failed_delivery"
          }
        ]
      }
    ]
  end

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end
end
