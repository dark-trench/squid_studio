defmodule SquidStudio.Web.Layouts do
  @moduledoc false

  use SquidStudio.Web, :html

  alias SquidStudio.Web.Assets

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="studio-app">
      <main class="studio-main">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" aria-live="polite" class="fixed right-4 top-4 z-50 space-y-2">
      <div
        :for={{kind, message} <- @flash}
        class={[
          "rounded-md border px-4 py-3 text-sm shadow-sm",
          kind == "error" && "border-red-200 bg-red-50 text-red-800",
          kind != "error" && "border-emerald-200 bg-emerald-50 text-emerald-800"
        ]}
      >
        {message}
      </div>
    </div>
    """
  end

  defp asset_path(conn, asset) when asset in [:css, :js] do
    hash = Assets.current_hash(asset)
    {_live, _routing, meta} = conn.private.phoenix_live_view
    prefix = get_in(meta, [:extra, :session, Access.elem(2), Access.at(0)])

    path = SquidStudio.Web.Helpers.prefixed_path(prefix, "#{asset}-#{hash}")

    Phoenix.VerifiedRoutes.unverified_path(conn, conn.private.phoenix_router, path)
  end
end
