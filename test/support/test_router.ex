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
  end
end
