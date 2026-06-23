import Config

config :squid_studio, environment: :test

config :squid_studio_dash, SquidStudioDash.Endpoint,
  secret_key_base: String.duplicate("test_secret_key_base_", 4)

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
