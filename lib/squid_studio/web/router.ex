defmodule SquidStudio.Web.Router do
  @moduledoc """
  Router macro for mounting Squid Studio inside a host Phoenix application.
  """

  alias SquidStudio.ConnectorCatalog
  alias SquidStudio.Drafts
  alias SquidStudio.Web.Resolver

  @default_opts [
    resolver: SquidStudio.Web.Resolver,
    socket_path: "/live",
    transport: "websocket"
  ]

  @transport_values ~w(longpoll websocket)

  defmacro squid_studio(path, opts \\ []) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote bind_quoted: binding() do
      prefix = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        {session_name, session_opts, route_opts} =
          SquidStudio.Web.Router.__options__(prefix, opts)

        live_session session_name, session_opts do
          get "/css-:md5", SquidStudio.Web.Assets, :css, as: :squid_studio_asset
          get "/js-:md5", SquidStudio.Web.Assets, :js, as: :squid_studio_asset

          live "/", SquidStudio.Web.WorkflowsLive, :index, route_opts
          live "/workflows", SquidStudio.Web.WorkflowsLive, :index, route_opts
          live "/workflows/:workflow_id", SquidStudio.Web.EditorLive, :show, route_opts
        end
      end
    end
  end

  @doc false
  def __options__(prefix, opts) do
    opts = Keyword.merge(@default_opts, opts)
    Enum.each(opts, &validate_opt!/1)

    on_mount = List.wrap(Keyword.get(opts, :on_mount, [])) ++ [SquidStudio.Web.Authentication]

    session_args = [
      prefix,
      opts[:resolver],
      opts[:socket_path],
      opts[:transport],
      opts[:csp_nonce_assign_key]
    ]

    session_opts = [
      on_mount: on_mount,
      session: {__MODULE__, :__session__, session_args},
      root_layout: {SquidStudio.Web.Layouts, :root}
    ]

    session_name = Keyword.get(opts, :as, :studio)

    {session_name, session_opts, as: session_name}
  end

  @doc false
  def __session__(conn, prefix, resolver, live_path, live_transport, csp_key) do
    user = Resolver.call_with_fallback(resolver, :resolve_user, [conn])
    csp_keys = expand_csp_nonce_keys(csp_key)
    {drafts, draft_error} = resolve_drafts(resolver, user)
    {connector_catalog, connector_catalog_error} = resolve_connector_catalog(resolver, user)

    %{
      "prefix" => prefix,
      "resolver" => resolver,
      "user" => user,
      "access" => Resolver.call_with_fallback(resolver, :resolve_access, [user]),
      "workflows" => Resolver.call_with_fallback(resolver, :resolve_workflows, [user]),
      "drafts" => drafts,
      "draft_error" => draft_error,
      "connector_catalog" => connector_catalog,
      "connector_catalog_error" => connector_catalog_error,
      "live_path" => live_path,
      "live_transport" => live_transport,
      "csp_nonces" => %{
        img: conn.assigns[csp_keys[:img]],
        style: conn.assigns[csp_keys[:style]],
        script: conn.assigns[csp_keys[:script]]
      }
    }
  end

  defp resolve_drafts(resolver, user) do
    resolver
    |> Resolver.call_with_fallback(:resolve_drafts, [user])
    |> Drafts.normalize_many()
    |> case do
      {:ok, drafts} -> {drafts, nil}
      {:error, reason} -> {[], reason}
    end
  end

  defp resolve_connector_catalog(resolver, user) do
    context = %{environment: Application.get_env(:squid_studio, :environment, :default)}

    connector_catalog =
      if Code.ensure_loaded?(resolver) and
           function_exported?(resolver, :resolve_connector_catalog, 2) do
        Resolver.call_with_fallback(resolver, :resolve_connector_catalog, [user, context])
      else
        []
      end

    connector_catalog
    |> ConnectorCatalog.normalize_many()
    |> case do
      {:ok, entries} -> {entries, nil}
      {:error, reason} -> {[], reason}
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias_ast, env) do
    Macro.expand(alias_ast, %{env | function: {:squid_studio, 2}})
  end

  defp expand_alias(other, _env), do: other

  defp expand_csp_nonce_keys(nil), do: %{img: nil, style: nil, script: nil}
  defp expand_csp_nonce_keys(key) when is_atom(key), do: %{img: key, style: key, script: key}
  defp expand_csp_nonce_keys(map) when is_map(map), do: map

  defp validate_opt!({:transport, transport}) do
    unless transport in @transport_values do
      raise ArgumentError, """
      invalid :transport, expected one of #{inspect(@transport_values)},
      got #{inspect(transport)}
      """
    end
  end

  defp validate_opt!({:socket_path, path}) do
    unless is_binary(path) and byte_size(path) > 0 do
      raise ArgumentError, """
      invalid :socket_path, expected a binary URL, got: #{inspect(path)}
      """
    end
  end

  defp validate_opt!({:resolver, resolver}) do
    unless is_atom(resolver) and not is_nil(resolver) do
      raise ArgumentError, """
      invalid :resolver, expected a module implementing SquidStudio.Web.Resolver,
      got: #{inspect(resolver)}
      """
    end
  end

  defp validate_opt!({:csp_nonce_assign_key, key}) do
    unless is_nil(key) or is_atom(key) or is_map(key) do
      raise ArgumentError, """
      invalid :csp_nonce_assign_key, expected nil, atom, or map with atom keys,
      got #{inspect(key)}
      """
    end
  end

  defp validate_opt!(_option), do: :ok
end
