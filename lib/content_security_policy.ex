defmodule ContentSecurityPolicy do
  @moduledoc """
  Module that includes Plug and LiveView helpers to handle Content Security
  Policy header.

  For inline `<style>` and `<script>` tags, nonce should be used. When the REST
  request is processed a nonce is added to the process dictionary. This ensures
  the nonce stays the same throughout the call, as the nonce in the tags must
  match the nonce in the header.

  To allow for inline `<style>` and/or `<script>` tag you must set a `'nonce'`
  source.

  ## Set up

  To set up MyAppWeb.CSP in your app you must:

  ### 1) Configure `lib/my_app_web.ex`

  Ensure you import the helpers in `MyAppWeb`.

    def router do
      quote do
        use Phoenix.Router, helpers: false

        # Import common connection and controller functions to use in pipelines
        import Plug.Conn
        import Phoenix.Controller
        import Phoenix.LiveView.Router

        import MyAppWeb.CSP, only: [put_content_security_policy: 2]
      end
    end

    # ...

    def html do
      quote do
        use Phoenix.Component

        import MyAppWeb.CldrHelpers

        # Import convenience functions from controllers
        import Phoenix.Controller,
          only: [get_csrf_token: 0, view_module: 1, view_template: 1]

        import MyAppWeb.CSP,
          only: [get_csp_nonce: 0]

        # Include general helpers for rendering HTML
        unquote(html_helpers())
      end
    end

    # ...

    def live_view do
      quote do
        use Phoenix.LiveView,
          layout: {MyAppWeb.Layouts, :app}

        on_mount MyAppWeb.CSP

        unquote(html_helpers())
      end
    end

  ### 2) Add nonce metatag to the HTML document

  Add the following metatag head to
  `lib/my_app_web/components/layouts/root.html.heex`.

    <meta name="csp-nonce" content={get_csp_nonce()} />

  ### 3) Pass the CSP nonce to the LiveView socket

  Ensure you pass on the CSP nonce to the LiveView socket in
  `assets/js/app.js`.

    let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
    let cspNonce = document.querySelector("meta[name='csp-nonce']").getAttribute("content")
    let liveSocket = new LiveSocket("/live", Socket, {
      longPollFallbackMs: 2500,
      params: { _csrf_token: csrfToken, _csp_nonce: cspNonce }
    })

  ## Usage

  If you got inline `<style>` or script tags you must set the nonce attribute:

      <style nonce={get_csp_nonce()}>
        // ...
      </style>
  """
  import Plug.Conn

  require Logger

  @doc """
  Sets a content security policy header.

  By default the policy is `default-src 'self'`. `'nonce'` source will be
  expanded with an auto-generated nonce that is persisted in the process
  dictionary.

  The options can be a function or a keyword list. Sources can be a binary
  or list of binaries. Duplicate directives will be merged together.

  ## Example

    plug :put_content_security_policy,
      img_src: "'self' data:`,
      style_src: "'self' 'nonce'"

    plug :put_content_security_policy,
      img_src: [
        "'self'",
        "data:"
      ]

    plug :put_content_security_policy, &MyAppWeb.CSPPolicy.opts/1
  """
  @spec put_content_security_policy(Plug.Conn.t(), list()) :: Plug.Conn.t()
  def put_content_security_policy(conn, fun) when is_function(fun, 1) do
    put_content_security_policy(conn, fun.(conn))
  end

  def put_content_security_policy(conn, opts) when is_list(opts) do
    csp =
      opts
      |> Keyword.put_new(:default_src, "'self'")
      |> Enum.reduce([], fn {name, sources}, acc ->
        sources = List.wrap(sources)

        Keyword.update(acc, name, sources, &(&1 ++ sources))
      end)
      |> Enum.reduce("", fn {name, sources}, acc ->
        name = String.replace(to_string(name), "_", "-")

        sources =
          sources
          |> Enum.uniq()
          |> Enum.join(" ")
          |> String.replace("'nonce'", "'nonce-#{get_csp_nonce()}'")

        "#{acc}#{name} #{sources};"
      end)

    put_resp_header(conn, "content-security-policy", csp)
  end

  @doc """
  Gets the CSP nonce.

  Generates a nonce and stores it in the process dictionary if one does not exist.
  """
  @spec get_csp_nonce() :: String.t()
  def get_csp_nonce do
    if nonce = Process.get(:plug_csp_nonce) do
      nonce
    else
      nonce = csp_nonce()
      Process.put(:plug_csp_nonce, nonce)
      nonce
    end
  end

  defp csp_nonce do
    24
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end

  @doc """
  Loads the CSP nonce into the LiveView process.
  """
  @spec on_mount(any(), any(), any(), any()) :: {:cont, any()}
  def on_mount(
        :default,
        _params,
        _session,
        %{private: %{connect_params: %{"_csp_nonce" => nonce}}} = socket
      ) do
    Process.put(:plug_csp_nonce, nonce)

    {:cont, socket}
  end

  def on_mount(:default, _params, _session, socket) do
    unless Process.get(:plug_csp_nonce) do
      Logger.debug("""
      LiveView session was misconfigured.

      1) Ensure the `put_content_security_policy` plug is in your router pipeline:

          plug :put_content_security_policy

      2) Define the CSRF meta tag inside the `<head>` tag in your layout:

          <meta name="csp-nonce" content={MyAppWeb.CSP.get_csp_nonce()} />

      3) Pass it forward in your app.js:

          let csrfToken = document.querySelector("meta[name='csp-nonce']").getAttribute("content");
          let liveSocket = new LiveSocket("/live", Socket, {params: {_csp_nonce: cspNonce}});
      """)
    end

    {:cont, socket}
  end
end
