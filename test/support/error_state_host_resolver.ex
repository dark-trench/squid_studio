defmodule SquidStudio.Test.ErrorStateHostResolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(_conn), do: :operator

  @impl true
  def resolve_access(:operator), do: :all

  @impl true
  def resolve_workflows(:operator) do
    if System.get_env("SQUID_STUDIO_ERROR_STATE_ALLOW_WORKFLOWS") == "1" do
      []
    else
      raise "resolver exploded with secret=abc123"
    end
  end

  @impl true
  def resolve_drafts(:operator), do: {:error, :unauthorized}

  @impl true
  def resolve_connector_catalog(:operator, _context), do: {:error, :unsupported_capability}
end
