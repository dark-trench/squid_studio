defmodule SquidStudioDash.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :squid_studio_dash

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Session,
    store: :cookie,
    key: "_squid_studio_dash_key",
    signing_salt: "squid_studio_dashboard"
  )

  plug(SquidStudioDash.Router)
end
