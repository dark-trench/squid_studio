defmodule SquidStudio.EditorGraphTest do
  use ExUnit.Case, async: true

  alias SquidStudio.EditorGraph

  test "update_step_properties preserves untouched opts and metadata" do
    spec = %{
      "workflow" => "restricted_issue_flow",
      "definition_version" => "draft",
      "steps" => [
        %{
          "name" => "open_issue",
          "action" => "create_issue",
          "opts" => %{
            "title" => "Escalate invoice review",
            "input" => %{
              "title" => ["payload", "invoice_id"],
              "body" => ["payload", "summary"]
            },
            "output" => "issue_result",
            "retry" => %{
              "max_attempts" => 3,
              "backoff" => %{"type" => "exponential", "min" => 5, "max" => 60}
            },
            "compensatable" => true
          },
          "metadata" => %{
            "notes" => "Escalate unresolved invoice review failures.",
            "owner" => "risk_ops"
          }
        }
      ],
      "transitions" => [],
      "retries" => [],
      "entry_steps" => ["open_issue"],
      "initial_step" => "open_issue",
      "entry_step" => "open_issue",
      "editor" => %{
        "nodes" => %{
          "open_issue" => %{
            "label" => "Open restricted issue",
            "type" => "action",
            "x" => 332,
            "y" => 168
          }
        }
      }
    }

    attrs = %{
      "name" => "open_issue",
      "label" => "Open restricted issue",
      "action" => "create_issue",
      "input_mapping" => "issue_title=payload.invoice_id\nissue_body=payload.summary",
      "output_key" => "created_issue",
      "retry_max_attempts" => "5",
      "retry_backoff_min" => "10",
      "retry_backoff_max" => "120",
      "notes" => "Escalate after validation and capture the issue URL."
    }

    connector = %{
      "provider" => "github",
      "display_name" => "Create issue",
      "input_contract" => %{"title" => "string"},
      "output_contract" => %{"issue_url" => "string"},
      "credential_requirements" => [%{"key" => "github_app", "label" => "GitHub app"}]
    }

    updated = EditorGraph.update_step_properties(spec, "open_issue", attrs, connector)

    assert %{
             "steps" => [
               %{
                 "name" => "open_issue",
                 "opts" => opts,
                 "metadata" => metadata
               }
             ]
           } = updated

    assert opts["title"] == "Escalate invoice review"

    assert opts["input"] == %{
             "issue_title" => ["payload", "invoice_id"],
             "issue_body" => ["payload", "summary"]
           }

    assert opts["output"] == "created_issue"

    assert opts["retry"] == %{
             "max_attempts" => 5,
             "backoff" => %{"type" => "exponential", "min" => 10, "max" => 120}
           }

    assert opts["compensatable"] == true
    assert metadata["notes"] == "Escalate after validation and capture the issue URL."
    assert metadata["owner"] == "risk_ops"
    assert metadata["provider"] == "github"
    assert metadata["display_name"] == "Create issue"
  end

  test "update_step_properties can persist compensatable false from the default state" do
    spec = %{
      "steps" => [
        %{
          "name" => "review_invoice",
          "opts" => %{"title" => "Review invoice draft"},
          "metadata" => %{}
        }
      ],
      "transitions" => [],
      "retries" => [],
      "entry_steps" => ["review_invoice"],
      "initial_step" => "review_invoice",
      "entry_step" => "review_invoice"
    }

    updated =
      EditorGraph.update_step_properties(
        spec,
        "review_invoice",
        %{
          "name" => "review_invoice",
          "label" => "Review invoice draft",
          "compensatable" => "false"
        }
      )

    assert %{
             "steps" => [
               %{
                 "opts" => %{
                   "title" => "Review invoice draft",
                   "compensatable" => false
                 }
               }
             ]
           } = updated
  end
end
