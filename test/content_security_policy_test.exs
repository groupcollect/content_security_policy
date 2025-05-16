defmodule ContentSecurityPolicyTest do
  use ContentSecurityPolicy.ConnCase

  alias ContentSecurityPolicy, as: CSP

  describe "put_content_security_policy/2" do
    test "sets default CSP header", %{conn: conn} do
      conn = CSP.put_content_security_policy(conn, [])

      assert get_resp_header(conn, "content-security-policy") == ["default-src 'self';"]
    end

    test "with options", %{conn: conn} do
      conn = CSP.put_content_security_policy(conn, img_src: "'self' data:")

      assert get_resp_header(conn, "content-security-policy") == [
               "default-src 'self';img-src 'self' data:;"
             ]
    end

    test "with list of sources", %{conn: conn} do
      conn = CSP.put_content_security_policy(conn, default_src: ["'self'", "data:"])

      assert get_resp_header(conn, "content-security-policy") == ["default-src 'self' data:;"]
    end

    test "with duplicate directives", %{conn: conn} do
      conn = CSP.put_content_security_policy(conn, default_src: "'self'", default_src: "data:")

      assert get_resp_header(conn, "content-security-policy") == ["default-src 'self' data:;"]
    end

    test "with duplicate sources", %{conn: conn} do
      conn =
        CSP.put_content_security_policy(conn,
          default_src: ["'self'", "data:"],
          default_src: "data:"
        )

      assert get_resp_header(conn, "content-security-policy") == ["default-src 'self' data:;"]
    end

    test "with nonce source", %{conn: conn} do
      conn = CSP.put_content_security_policy(conn, default_src: "'self' 'nonce'")

      assert ["default-src 'self' 'nonce-" <> _nonce] =
               get_resp_header(conn, "content-security-policy")
    end

    defp my_function(conn) do
      [
        default_src: conn.host
      ]
    end

    test "with function", %{conn: conn} do
      conn = CSP.put_content_security_policy(conn, &my_function/1)

      assert get_resp_header(conn, "content-security-policy") == ["default-src #{conn.host};"]
    end
  end

  describe "get_csp_nonce/0" do
    test "token has no padding" do
      refute CSP.get_csp_nonce() =~ "="
    end

    test "token is stored in process dictionary" do
      assert CSP.get_csp_nonce() == CSP.get_csp_nonce()

      token = CSP.get_csp_nonce()
      Process.delete(:plug_csp_nonce)
      assert token != CSP.get_csp_nonce()
    end
  end
end
