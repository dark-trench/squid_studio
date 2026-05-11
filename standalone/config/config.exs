import Config

config :squid_studio_dash, SquidStudioDash.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [view: SquidStudioDash.ErrorHTML, accepts: ~w(html json), layout: false],
  pubsub_server: SquidStudioDash.PubSub,
  live_view: [signing_salt: "squid_studio_dash"]

import_config "#{config_env()}.exs"
