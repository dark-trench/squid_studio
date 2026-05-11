import Config

config :squid_studio_dash, SquidStudioDash.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: String.duplicate("local_dev_secret_key_base_", 3),
  watchers: []

config :logger, :default_formatter, format: "[$level] $message\n"
