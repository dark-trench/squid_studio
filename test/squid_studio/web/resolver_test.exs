defmodule SquidStudio.Web.ResolverTest do
  use ExUnit.Case, async: true

  alias SquidStudio.Web.Resolver

  test "default draft callbacks expose sample drafts without choosing host storage" do
    drafts = Resolver.resolve_drafts(nil)
    draft_ids = Enum.map(drafts, & &1["id"])

    assert draft_ids == [
             "daily_digest",
             "approval_saga",
             "dynamic_fanout",
             "bedrock_dispatch",
             "runtime_authored_spec"
           ]

    assert Enum.all?(drafts, &(&1["definition_version"] == "draft"))
    assert {:ok, %{"id" => "daily_digest"}} = Resolver.load_draft(nil, "daily_digest")
    assert {:error, :not_found} = Resolver.load_draft(nil, "missing")
    assert {:error, :persistence_not_configured} = Resolver.save_draft(nil, %{})
    assert {:error, :persistence_not_configured} = Resolver.delete_draft(nil, "daily_digest")
    assert {:error, :publish_not_configured} = Resolver.publish_draft(nil, "daily_digest")
  end

  test "call_with_fallback uses host callbacks when available" do
    assert [%{id: "invoice_review"}] =
             Resolver.call_with_fallback(SquidStudio.Test.HostResolver, :resolve_workflows, [
               :operator
             ])

    assert {:ok, %{"id" => "invoice_review:published"}} =
             Resolver.call_with_fallback(SquidStudio.Test.HostResolver, :publish_draft, [
               :operator,
               "invoice_review"
             ])
  end
end
