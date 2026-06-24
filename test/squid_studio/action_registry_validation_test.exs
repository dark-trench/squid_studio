defmodule SquidStudio.ActionRegistryValidationTest do
  use ExUnit.Case, async: true

  alias SquidStudio.ActionRegistryValidation

  test "accepts actions that remain available in the host catalog" do
    spec = %{
      "steps" => [
        %{"name" => "post_message", "action" => "post_message"}
      ]
    }

    catalog = [
      %{"action_key" => "post_message", "enabled" => true, "authorized" => true}
    ]

    assert ActionRegistryValidation.validate(spec, catalog) == []
  end

  test "rejects hidden or disabled catalog actions" do
    spec = %{
      "steps" => [
        %{"name" => "open_issue", "action" => "create_issue"}
      ]
    }

    catalog = [
      %{"action_key" => "create_issue", "enabled" => false, "authorized" => false}
    ]

    assert ActionRegistryValidation.validate(spec, catalog) == [
             %{
               "path" => ["steps", "0", "action"],
               "message" => "action create_issue is not available for this user"
             }
           ]
  end

  test "rejects unknown action keys" do
    spec = %{
      "steps" => [
        %{"name" => "custom_step", "action" => "unknown_action"}
      ]
    }

    assert ActionRegistryValidation.validate(spec, []) == [
             %{
               "path" => ["steps", "0", "action"],
               "message" => "unknown action unknown_action"
             }
           ]
  end
end
