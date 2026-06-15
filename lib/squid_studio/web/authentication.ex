defmodule SquidStudio.Web.Authentication do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, session, socket) do
    Process.put(:squid_studio_routing, {socket, session["prefix"]})

    socket =
      socket
      |> assign(:access, session["access"])
      |> assign(:user, session["user"])
      |> assign(:resolver, session["resolver"])
      |> assign(:prefix, session["prefix"])
      |> assign(:live_path, session["live_path"])
      |> assign(:live_transport, session["live_transport"])
      |> assign(:workflows, session["workflows"])
      |> assign(:drafts, session["drafts"])
      |> assign(:draft_error, session["draft_error"])
      |> assign(:connector_catalog, session["connector_catalog"])
      |> assign(:connector_catalog_error, session["connector_catalog_error"])
      |> assign(:csp_nonces, session["csp_nonces"])

    {:cont, socket}
  end
end
