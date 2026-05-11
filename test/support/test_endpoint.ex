defmodule SquidStudio.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :squid_studio

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Session,
    store: :cookie,
    key: "_squid_studio_test_key",
    signing_salt: "test_salt"
  )

  plug(SquidStudio.Test.Router)
end
