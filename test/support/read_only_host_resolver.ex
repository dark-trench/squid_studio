defmodule SquidStudio.Test.ReadOnlyHostResolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  alias SquidStudio.Test.HostResolver

  @impl true
  def resolve_user(conn), do: HostResolver.resolve_user(conn)

  @impl true
  def resolve_access(:operator), do: :read_only

  @impl true
  def resolve_workflows(user), do: HostResolver.resolve_workflows(user)

  @impl true
  def resolve_drafts(user), do: HostResolver.resolve_drafts(user)

  @impl true
  def resolve_connector_catalog(user, context),
    do: HostResolver.resolve_connector_catalog(user, context)
end
