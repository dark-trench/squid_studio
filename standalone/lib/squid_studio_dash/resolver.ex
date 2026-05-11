defmodule SquidStudioDash.Resolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(_conn), do: nil

  @impl true
  def resolve_access(_user), do: :all

  @impl true
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
          edge("daily_digest", "fetch_feed"),
          edge("fetch_feed", "build_digest"),
          edge("build_digest", "post_to_discord"),
          edge("post_to_discord", "complete"),
          edge("post_to_discord", "record_failed_delivery")
        ]
      }
    ]
  end

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end

  defp edge(source, target) do
    %{id: "#{source}-#{target}", source: source, target: target}
  end
end
