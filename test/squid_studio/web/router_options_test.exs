defmodule SquidStudio.Web.RouterOptionsTest do
  use ExUnit.Case, async: true

  alias SquidStudio.Web.Resolver
  alias SquidStudio.Web.Router

  test "rejects unsupported live transport values" do
    assert_raise ArgumentError, ~r/invalid :transport/, fn ->
      Router.__options__("/studio", transport: "ftp")
    end
  end

  test "accepts custom resolver modules" do
    assert {_session_name, session_opts, [as: :studio]} =
             Router.__options__("/studio", resolver: SquidStudio.Web.Resolver)

    assert Keyword.fetch!(session_opts, :root_layout) == {SquidStudio.Web.Layouts, :root}
  end

  test "rejects invalid socket paths" do
    assert_raise ArgumentError, ~r/invalid :socket_path/, fn ->
      Router.__options__("/studio", socket_path: nil)
    end
  end

  test "rejects invalid resolver modules" do
    assert_raise ArgumentError, ~r/invalid :resolver/, fn ->
      Router.__options__("/studio", resolver: nil)
    end
  end

  test "rejects invalid CSP nonce key options" do
    assert_raise ArgumentError, ~r/invalid :csp_nonce_assign_key/, fn ->
      Router.__options__("/studio", csp_nonce_assign_key: "nonce")
    end
  end

  test "builds live session options with custom names and on_mount hooks" do
    assert {:operations, session_opts, [as: :operations]} =
             Router.__options__("/studio",
               as: :operations,
               on_mount: [SquidStudio.TestAuth],
               socket_path: "/socket",
               transport: "longpoll"
             )

    assert [SquidStudio.TestAuth, SquidStudio.Web.Authentication] =
             Keyword.fetch!(session_opts, :on_mount)

    assert {Router, :__session__, ["/studio", Resolver, "/socket", "longpoll", nil]} =
             Keyword.fetch!(session_opts, :session)
  end

  test "builds live session data with resolver output and CSP nonces" do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.assign(:img_nonce, "img-token")
      |> Plug.Conn.assign(:style_nonce, "style-token")
      |> Plug.Conn.assign(:script_nonce, "script-token")

    session =
      Router.__session__(
        conn,
        "/studio",
        Resolver,
        "/socket",
        "longpoll",
        %{img: :img_nonce, style: :style_nonce, script: :script_nonce}
      )

    assert %{
             "prefix" => "/studio",
             "resolver" => Resolver,
             "user" => nil,
             "access" => :all,
             "live_path" => "/socket",
             "live_transport" => "longpoll",
             "csp_nonces" => %{
               img: "img-token",
               style: "style-token",
               script: "script-token"
             }
           } = session

    assert [%{id: "daily_digest"}] = session["workflows"]
  end
end
