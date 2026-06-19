defmodule SquidStudio.Test.ErrorStateHostResolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(_conn), do: :operator

  @impl true
  def resolve_access(:operator), do: :all

  @impl true
  def resolve_workflows(:operator) do
    raise "resolver exploded with secret=abc123"
  end

  @impl true
  def resolve_drafts(:operator), do: {:error, :unauthorized}

  @impl true
  def resolve_connector_catalog(:operator, _context), do: {:error, :unsupported_capability}
end
