defmodule SquidStudio.Web.Resolver do
  @moduledoc """
  Behavior for host applications that embed Squid Studio.

  The default resolver exposes a small sample workflow so the editor can render
  before a host app wires in real Squidie workflow discovery.
  """

  alias SquidStudio.Drafts

  @callback resolve_user(Plug.Conn.t()) :: term()
  @callback resolve_access(term()) :: :all | :read_only
  @callback resolve_workflows(term()) :: [map()]
  @callback resolve_drafts(term()) :: [map()] | {:ok, [map()]} | {:error, term()}
  @callback load_draft(term(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback save_draft(term(), map()) :: {:ok, map()} | {:error, term()}
  @callback delete_draft(term(), String.t()) :: :ok | {:ok, term()} | {:error, term()}
  @callback publish_draft(term(), String.t()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks resolve_user: 1,
                      resolve_access: 1,
                      resolve_workflows: 1,
                      resolve_drafts: 1,
                      load_draft: 2,
                      save_draft: 2,
                      delete_draft: 2,
                      publish_draft: 2

  def call_with_fallback(resolver, callback, args) do
    if Code.ensure_loaded?(resolver) and function_exported?(resolver, callback, length(args)) do
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

  @doc false
  def resolve_drafts(user), do: user |> resolve_workflows() |> Drafts.from_workflows()

  @doc false
  def load_draft(user, draft_id) do
    user
    |> resolve_drafts()
    |> Enum.find(&(&1["id"] == draft_id))
    |> case do
      nil -> {:error, :not_found}
      draft -> {:ok, draft}
    end
  end

  @doc false
  def save_draft(_user, _draft), do: {:error, :persistence_not_configured}

  @doc false
  def delete_draft(_user, _draft_id), do: {:error, :persistence_not_configured}

  @doc false
  def publish_draft(_user, _draft_id), do: {:error, :publish_not_configured}

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end
end
