Application.put_env(:squid_studio, SquidStudio.Test.Endpoint,
  check_origin: false,
  http: [port: 4002],
  live_view: [signing_salt: "test_signing_salt"],
  render_errors: [formats: [html: SquidStudio.Test.ErrorHTML], layout: false],
  secret_key_base: String.duplicate("a", 64),
  server: false,
  url: [host: "localhost"]
)

SquidStudio.Test.Endpoint.start_link()

ExUnit.start()
