defmodule SquidStudio.SquidieIntegrationTest do
  use ExUnit.Case, async: true

  test "can preview Squidie editor specs for Studio graph integration" do
    editor_spec = %{
      "workflow" => "demo_workflow",
      "definition_version" => "draft",
      "triggers" => [],
      "payload" => [],
      "steps" => [
        %{"name" => "load_invoice", "opts" => []},
        %{"name" => "send_reminder", "opts" => []}
      ],
      "transitions" => [
        %{"from" => "load_invoice", "on" => "ok", "to" => "send_reminder"}
      ],
      "retries" => [],
      "entry_steps" => ["load_invoice"],
      "initial_step" => "load_invoice",
      "entry_step" => "load_invoice"
    }

    assert {:ok, graph} = Squidie.Workflow.EditorSpec.preview_graph(editor_spec)

    assert %{
             "source" => "workflow_spec",
             "status" => "draft",
             "workflow" => "demo_workflow",
             "nodes" => [
               %{"id" => "load_invoice", "status" => "draft"},
               %{"id" => "send_reminder", "status" => "draft"}
             ],
             "edges" => [
               %{
                 "id" => "load_invoice:ok:send_reminder",
                 "from" => "load_invoice",
                 "to" => "send_reminder",
                 "type" => "transition",
                 "outcome" => "ok"
               }
             ]
           } = graph
  end
end
