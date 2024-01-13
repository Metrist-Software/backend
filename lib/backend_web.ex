defmodule BackendWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BackendWeb, :controller
      use BackendWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: BackendWeb

      import Plug.Conn
      import BackendWeb.Gettext
      alias BackendWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/backend_web/templates",
        namespace: BackendWeb

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
        layout: {BackendWeb.LayoutView, :live}

      on_mount BackendWeb.AccountActivityTracker

      unquote(view_helpers())

      defp limit_memory do
        # Size in words, which normally is 4 bytes per word.
        :erlang.process_flag(:max_heap_size, 25 * 1024 * 1024)
      end
    end
  end

  def blank_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BackendWeb.LayoutView, :live_blank}

      on_mount BackendWeb.AccountActivityTracker

      unquote(view_helpers())
    end
  end

  def dd_live_view do
    quote do
      use Phoenix.LiveView,
        layout: {BackendWeb.LayoutView, :live_dd}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

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
      import BackendWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      use PetalComponents

      # Import LiveView helpers
      import Phoenix.Component

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import BackendWeb.ErrorHelpers
      import BackendWeb.Gettext
      import BackendWeb.I18n
      import BackendWeb.Helpers
      import BackendWeb.Helpers.Svg

      alias BackendWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmodule AccountActivityTracker do
    @moduledoc """
    If we're logged in, update the last active timestamp in account.
    """

    def on_mount(:default, _params, %{"current_user" => user}, socket) do
      if Phoenix.LiveView.connected?(socket) and not socket.assigns.spoofing? do
        Backend.Projections.register_account_activity(user.account_id)
      end
      {:cont, socket}
    end
    def on_mount(_arg, _params, _session, socket) do
      {:cont, socket}
    end
  end
end
