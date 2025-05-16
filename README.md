# ContentSecurityPolicy

A library to help manage Content Security Policy headers in Phoenix applications.

This library is based on Dan Schultzer's blog post [Content Security Policy header with Phoenix LiveView](https://danschultzer.com/posts/content-security-policy-with-liveview).

## Features

- Easily set CSP headers in Phoenix applications
- Support for nonce-based inline scripts and styles
- LiveView compatible
- Simple integration with Phoenix pipelines

## Installation

Add `content_security_policy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:content_security_policy, git: "https://github.com/groupcollect/content_security_policy.git", override: true, branch: "main"}
  ]
end
```

## Setup

### 1. Configure your router

Import the CSP helpers in your router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  
  import Plug.Conn
  import Phoenix.Controller
  import ContentSecurityPolicy, only: [put_content_security_policy: 2]
  
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_content_security_policy, [
      default_src: "'self'", 
      script_src: "'self' 'nonce'",
      style_src: "'self' 'nonce'"
    ]
  end
  
  # Routes...
end
```

### 2. Configure your HTML templates

Add the nonce helpers to your templates:

```elixir
defmodule MyAppWeb do
  # ...
  
  def html do
    quote do
      use Phoenix.Component
      
      # Import CSP helpers
      import ContentSecurityPolicy, only: [get_csp_nonce: 0]
      
      # Other imports...
    end
  end
  
  # ...
end
```

### 3. Add nonce metatag to your root layout

In your `root.html.heex`, add:

```html
<meta name="csp-nonce" content={get_csp_nonce()} />
```

### 4. Pass the CSP nonce to LiveView 

In your `app.js`:

```javascript
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let cspNonce = document.querySelector("meta[name='csp-nonce']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken, _csp_nonce: cspNonce }
});
```

### 5. Set up LiveView to use the CSP nonce

```elixir
defmodule MyAppWeb do
  # ...
  
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MyAppWeb.Layouts, :app}
        
      # Add CSP on_mount callback
      on_mount ContentSecurityPolicy
      
      # Other imports...
    end
  end
  
  # ...
end
```

## Usage

Use the nonce in your inline scripts and styles:

```html
<script nonce={get_csp_nonce()}>
  // Your inline JavaScript here
</script>

<style nonce={get_csp_nonce()}>
  /* Your inline CSS here */
</style>
```

## License

MIT

