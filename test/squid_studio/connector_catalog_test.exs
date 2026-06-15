defmodule SquidStudio.ConnectorCatalogTest do
  use ExUnit.Case, async: true

  alias SquidStudio.ConnectorCatalog

  test "normalizes connector entries and strips credential values" do
    assert {:ok, [entry]} =
             ConnectorCatalog.normalize_many([
               %{
                 provider: :slack,
                 category: :messaging,
                 action_key: :post_message,
                 display_name: "Post message",
                 description: "Send a Slack message",
                 input_contract: %{channel: :string, text: :string},
                 output_contract: %{message_id: :string},
                 credential_requirements: [
                   %{key: :bot_token, label: "Bot token", value: "placeholder-value"}
                 ],
                 enabled: true
               }
             ])

    assert entry == %{
             "provider" => "slack",
             "category" => "messaging",
             "action_key" => "post_message",
             "display_name" => "Post message",
             "description" => "Send a Slack message",
             "input_contract" => %{"channel" => "string", "text" => "string"},
             "output_contract" => %{"message_id" => "string"},
             "credential_requirements" => [
               %{"key" => "bot_token", "label" => "Bot token", "required" => true}
             ],
             "enabled" => true,
             "authorized" => true,
             "disabled_reason" => nil
           }
  end

  test "rejects non-json-safe connector metadata" do
    date = ~D[2026-06-15]

    assert {:error, {:invalid_json_value, ["input_contract", "seen_at"], %Date{}}} =
             ConnectorCatalog.normalize(%{
               provider: "calendar",
               category: "scheduling",
               action_key: "create_event",
               display_name: "Create event",
               input_contract: %{seen_at: date},
               output_contract: %{},
               credential_requirements: []
             })
  end

  test "rejects map keys that cannot be converted without crashing" do
    ref = make_ref()

    assert {:error, {:invalid_json_value, ["input_contract"], ^ref}} =
             ConnectorCatalog.normalize(%{
               provider: "calendar",
               category: "scheduling",
               action_key: "create_event",
               display_name: "Create event",
               input_contract: %{ref => "string"},
               output_contract: %{},
               credential_requirements: []
             })
  end

  test "preserves host resolver catalog errors" do
    assert {:error, :catalog_unavailable} =
             ConnectorCatalog.normalize_many({:error, :catalog_unavailable})
  end

  test "groups catalog entries by category with unavailable entries retained" do
    {:ok, entries} =
      ConnectorCatalog.normalize_many([
        %{
          provider: "slack",
          category: "Messaging",
          action_key: "post_message",
          display_name: "Post message",
          description: "Send a Slack message",
          input_contract: %{},
          output_contract: %{},
          credential_requirements: [],
          enabled: true
        },
        %{
          provider: "github",
          category: "Code",
          action_key: "create_issue",
          display_name: "Create issue",
          description: "Open an issue",
          input_contract: %{},
          output_contract: %{},
          credential_requirements: [],
          enabled: false,
          authorized: false,
          disabled_reason: "Production only"
        }
      ])

    assert [
             %{
               category: "Code",
               entries: [%{"action_key" => "create_issue", "authorized" => false}]
             },
             %{
               category: "Messaging",
               entries: [%{"action_key" => "post_message", "enabled" => true}]
             }
           ] = ConnectorCatalog.group_by_category(entries)
  end
end
