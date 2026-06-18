defmodule SquidStudio.Test.Router do
  use Phoenix.Router, helpers: false

  import Phoenix.LiveView.Router
  import SquidStudio.Web.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:browser)

    squid_studio("/studio")
    squid_studio("/host-studio", as: :host_studio, resolver: SquidStudio.Test.HostResolver)

    squid_studio("/read-only-studio",
      as: :read_only_studio,
      resolver: SquidStudio.Test.ReadOnlyHostResolver
    )
  end
end
