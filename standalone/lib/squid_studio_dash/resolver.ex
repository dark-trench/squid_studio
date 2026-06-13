defmodule SquidStudioDash.Resolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  alias SquidStudio.Drafts

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

  @impl true
  def resolve_drafts(_user) do
    ensure_drafts()
    |> Agent.get(&Map.values/1)
  end

  @impl true
  def load_draft(_user, draft_id) do
    ensure_drafts()
    |> Agent.get(&Map.fetch(&1, draft_id))
  end

  @impl true
  def save_draft(_user, draft) do
    with {:ok, normalized} <- Drafts.normalize(draft) do
      ensure_drafts()
      |> Agent.update(&Map.put(&1, normalized["id"], normalized))

      {:ok, normalized}
    end
  end

  @impl true
  def delete_draft(_user, draft_id) do
    ensure_drafts()
    |> Agent.update(&Map.delete(&1, draft_id))

    :ok
  end

  @impl true
  def publish_draft(_user, draft_id) do
    case load_draft(nil, draft_id) do
      {:ok, draft} ->
        {:ok,
         %{
           "id" => "#{draft["workflow"]}:published",
           "workflow" => draft["workflow"],
           "definition_version" => "published",
           "source_draft_id" => draft["id"]
         }}

      :error ->
        {:error, :not_found}
    end
  end

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end

  defp edge(source, target) do
    %{id: "#{source}-#{target}", source: source, target: target}
  end

  defp ensure_drafts do
    pid =
      case Process.whereis(__MODULE__.Drafts) do
        nil ->
          {:ok, pid} = Agent.start_link(fn -> %{} end, name: __MODULE__.Drafts)
          pid

        pid ->
          pid
      end

    Agent.update(pid, fn
      drafts when map_size(drafts) == 0 -> seed_drafts()
      drafts -> drafts
    end)

    pid
  end

  defp seed_drafts do
    resolve_workflows(nil)
    |> Drafts.from_workflows()
    |> Map.new(&{&1["id"], &1})
  end
end
