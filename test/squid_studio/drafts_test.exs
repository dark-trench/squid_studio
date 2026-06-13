defmodule SquidStudio.DraftsTest do
  use ExUnit.Case, async: true

  alias SquidStudio.Drafts

  describe "normalize/1" do
    test "keeps draft specs JSON-safe while preserving Squidie fields" do
      draft = %{
        id: :daily_digest,
        workflow: :daily_digest,
        name: "Daily RSS To Discord",
        definition_version: :draft,
        spec: %{
          workflow: :daily_digest,
          definition_version: :draft,
          steps: [%{name: :fetch_feed, opts: []}],
          transitions: []
        },
        metadata: %{source: :host}
      }

      assert {:ok, normalized} = Drafts.normalize(draft)
      assert Jason.encode!(normalized)

      assert %{
               "id" => "daily_digest",
               "workflow" => "daily_digest",
               "name" => "Daily RSS To Discord",
               "definition_version" => "draft",
               "spec" => %{
                 "workflow" => "daily_digest",
                 "definition_version" => "draft",
                 "steps" => [%{"name" => "fetch_feed", "opts" => []}],
                 "transitions" => []
               },
               "metadata" => %{"source" => "host"}
             } = normalized
    end

    test "rejects values that cannot round trip through JSON" do
      draft = %{
        id: "daily_digest",
        workflow: "daily_digest",
        name: "Daily RSS To Discord",
        definition_version: "draft",
        spec: %{"workflow" => "daily_digest", "bad" => self()}
      }

      assert {:error, {:invalid_json_value, ["spec", "bad"], pid}} = Drafts.normalize(draft)
      assert is_pid(pid)
    end
  end

  describe "normalize_many/1" do
    test "accepts nil, ok-tuples, and lists of draft maps" do
      draft = %{
        id: "daily_digest",
        workflow: "daily_digest",
        name: "Daily RSS To Discord",
        spec: %{"workflow" => "daily_digest"}
      }

      assert {:ok, []} = Drafts.normalize_many(nil)
      assert {:ok, [%{"id" => "daily_digest"}]} = Drafts.normalize_many({:ok, [draft]})
      assert {:ok, [%{"definition_version" => "draft"}]} = Drafts.normalize_many([draft])
    end

    test "rejects non-list draft collections" do
      assert {:error, {:invalid_json_value, [], "bad"}} = Drafts.normalize_many("bad")
    end
  end

  describe "from_workflows/1" do
    test "builds default draft specs from resolver workflow maps" do
      workflows = [
        %{
          id: "daily_digest",
          name: "Daily RSS To Discord",
          nodes: [%{id: "fetch_feed"}],
          edges: [%{id: "daily_digest-fetch_feed"}]
        }
      ]

      assert [
               %{
                 "id" => "daily_digest",
                 "workflow" => "daily_digest",
                 "definition_version" => "draft",
                 "spec" => %{
                   "nodes" => [%{"id" => "fetch_feed"}],
                   "edges" => [%{"id" => "daily_digest-fetch_feed"}]
                 },
                 "metadata" => %{"source" => "resolver_workflow"}
               }
             ] = Drafts.from_workflows(workflows)
    end

    test "returns an empty collection for invalid workflow collections" do
      assert [] = Drafts.from_workflows(:missing)
    end
  end
end
