defmodule TuneWeb do
  @moduledoc false
  @local_ip "192.168.15.5"

  def subscribe(channel) do
    Phoenix.PubSub.subscribe(Tune.PubSub, channel)
  end

  def broadcast(channel, event, payload) do
    Phoenix.PubSub.broadcast(Tune.PubSub, channel, {event, payload})
  end

  def session_qr_code(socket_or_conn, session_id) do
    socket_or_conn
    |> TuneWeb.Router.Helpers.live_url(TuneWeb.SessionLive, session_id)
    |> String.replace("localhost", @local_ip)
    |> EQRCode.encode()
    |> EQRCode.svg(width: 270)
  end

  def controller do
    quote do
      use Phoenix.Controller, namespace: TuneWeb

      import Plug.Conn
      import Tune.Gettext
      alias TuneWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/tune_web/templates",
        namespace: TuneWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {TuneWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import Tune.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import TuneWeb.ErrorHelpers
      import Tune.Gettext
      alias TuneWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
