defmodule BackendWeb.Admin.AccountsLive do
  use BackendWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        account: nil,
        api_token: nil,
        full_width: true,
        cur_sort: %{
          cur_col: "inserted_at",
          cur_dir: "desc"
        },
        page_title: "Accounts")
      |> load_accounts()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def apply_action(socket, :free_trial_configure, params) do
    assign(socket, account: socket.assigns.accounts_by_id[params["id"]])
  end

  def apply_action(socket, _live_action, _params) do
    socket
  end


  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <h2 class="mb-3 text-3xl">Accounts</h2>
        <%= if not is_nil(@api_token) do %>
          Api token for selected account: <%= @api_token %>
          <button title="Hide" phx-click="clear-token">(×)</button>
        <% end %>

      <.modal title="Configure free trial" :if={@live_action in [:free_trial_configure]}>
        <.live_component
          module={BackendWeb.Admin.Component.FreeTrialConfigureComponent}
          id="free_trial_configure"
          account={@account}
        />
      </.modal>

      <%= show_accounts(false, @external_accounts, @cur_sort) %>
      <%= show_accounts(true, @internal_accounts, @cur_sort) %>
      </div>
    """
  end

  def show_accounts(_, [], _, _), do: ""
  def show_accounts(is_internal, list, cur_sort) do
    {label, button_label, button_action} = if is_internal do
      {"Internal", "↑", "make-external"}
    else
      {"External", "↓", "make-internal"}
    end

    assigns = %{
      label: label,
      list: list,
      is_internal: is_internal,
      button_label: button_label,
      button_action: button_action,
      cur_sort: cur_sort
    }
    ~H"""
      <h3 class="text-2xl mt-5"><%= @label %> (<%= length(@list) %>)</h3>
      <hr />

      <table class="table-auto my-4">
        <thead>
          <tr class="border-b font-semibold">
            <td class="px-2"><.sortable label="Account" col="name" {@cur_sort}/></td>
            <td class="px-2">Actions</td>
            <td class="px-2"><.sortable label="Created" col="inserted_at" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#subscriptions" col="stat_num_subscriptions" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#monitors" col="stat_num_monitors" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#users" col="stat_num_users" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#wau" col="stat_weekly_users" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#mau" col="stat_monthly_users" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#slack_alerts" col="stat_num_slack_alerts" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#slack_commands" col="stat_num_slack_commands" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="Last Login" col="stat_last_user_login" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="Last WebApp Activity" col="stat_last_webapp_activity" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="Teams?" col="stat_num_msteams" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="Slack?" col="stat_num_slack" {@cur_sort}/></td>
            <td class="px-2"><.sortable label="#freetrial_days" col="free_trial_end_time" {@cur_sort}/></td>
            <td class="px-2">tier</td>
          </tr>
        </thead>
        <tbody>
          <%= for account <- @list do %>
          <tr class="border-b border-gray-300">
            <td class="px-2">
              <%= Backend.Projections.Account.get_account_name(account) %> <span class="text-sm text-muted"><%= account.id %></span>
            </td>

            <td class="px-2">
            <div class="flex space-x-4">
              <button
                title={@button_action}
                phx-click={@button_action}
                phx-value-id={account.id}>
                <%= @button_label %>
              </button>
              <button
                title="Show or generate API token"
                phx-click="api-token"
                phx-value-id={account.id}>
                🔑
              </button>
              <button
                title="Spoof this account"
                phx-click="spoof"
                phx-value-id={account.id}
                phx-value-name={Backend.Projections.Account.get_account_name(account)}>
                👽
              </button>
              <button
                title="Edit visible monitors"
                phx-click="edit-visible-monitors"
                phx-value-id={account.id}>
                👁
              </button>
            </div>
            </td>
            <td class="px-2">
              <%= NaiveDateTime.to_date(account.inserted_at) %>
            </td>
            <td class="px-2">
              <%= account.stat_num_subscriptions %>
            </td>
            <td class="px-2">
              <%= account.stat_num_monitors %>
            </td>
            <td class="px-2">
              <%= account.stat_num_users %>
            </td>
            <td class="px-2">
              <%= account.stat_weekly_users %>
            </td>
            <td class="px-2">
              <%= account.stat_monthly_users %>
            </td>
            <td class="px-2">
              <%= account.stat_num_slack_alerts %>
            </td>
            <td class="px-2">
              <%= account.stat_num_slack_commands %>
            </td>
            <td class="px-2">
              <%= if is_nil(account.stat_last_user_login), do: "Never", else: NaiveDateTime.to_date(account.stat_last_user_login) %>
            </td>
            <td class="px-2">
              <%= if is_nil(account.stat_last_webapp_activity), do: "Never", else: NaiveDateTime.to_date(account.stat_last_webapp_activity) %>
            </td>
            <td class="px-2">
              <%= y_or_n(account.stat_num_msteams) %>
            </td>
            <td class="px-2">
              <%= y_or_n(account.stat_num_slack) %>
            </td>
            <td class="px-2 whitespace-nowrap">
            <%= if account.free_trial_end_time do %>
              <.link
                patch={Routes.accounts_path(BackendWeb.Endpoint, :free_trial_configure, account.id)}
                replace={true}
              >
                🔧
              </.link>
              <%= Domain.Account.free_trial_days_left(account.free_trial_end_time) %>
            <% else %>
              <.link
                patch={Routes.accounts_path(BackendWeb.Endpoint, :free_trial_configure, account.id)}
                replace={true}
              >
                🔧
              </.link>
              N/A
            <% end %>
            </td>
            <td class="px-2">
              <%= active_membership(account.id) %>
            </td>
          </tr>
          <% end %>
        </tbody>
    </table>
    """
  end

  @impl true
  def handle_event("make-external", %{"id" => id}, socket) do
    BackendWeb.Helpers.dispatch_with_auth_check(socket, %Domain.Account.Commands.MakeExternal{id: id})
    {:noreply, socket}
  end

  def handle_event("make-internal", %{"id" => id}, socket) do
    BackendWeb.Helpers.dispatch_with_auth_check(socket, %Domain.Account.Commands.MakeInternal{id: id})
    {:noreply, socket}
  end

  def handle_event("api-token", %{"id" => id}, socket) do
    token = case Backend.Auth.APIToken.list(id) do
      [] ->
          Backend.Auth.APIToken.generate(id, socket)
      [first | _] ->
          first
    end
    {:noreply, assign(socket, api_token: token)}
  end

  def handle_event("spoof", %{"id" => id, "name" => name}, socket) do
    {:noreply, push_navigate(socket,
        to: Routes.auth_path(BackendWeb.Endpoint, :spoof, id, name)
      )}
  end

  def handle_event("clear-token", _params, socket) do
    {:noreply, assign(socket, api_token: nil)}
  end

  def handle_event("edit-visible-monitors", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket,
        to: Routes.live_path(BackendWeb.Endpoint, BackendWeb.Admin.VisibleMonitorsLive, id))}
  end

  def handle_event("sort", %{"col" => col, "dir" => dir}, socket) do
    socket =
      socket
      |> assign(cur_sort: %{cur_col: col, cur_dir: dir})
      |> load_accounts()
    {:noreply, socket}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: Routes.accounts_path(socket, :index), replace: true)}
  end

  @impl true
  def handle_info("close_modal", socket) do
    {:noreply, push_patch(socket, to: Routes.accounts_path(socket, :index), replace: true)}
  end

  def handle_info(_msg, socket) do
    # We only subscribe to internal/external messages so for now, just
    # reload things.
    {:noreply, load_accounts(socket)}
  end

  defp load_accounts(socket) do
    cur_sort = socket.assigns.cur_sort
    accounts =
      Backend.Projections.list_accounts(sort: %{col: cur_sort.cur_col, dir: cur_sort.cur_dir}, preloads: [:original_user])

    for account <- accounts do
      Backend.PubSub.unsubscribe("Account:#{account.id}")
      Backend.PubSub.subscribe("Account:#{account.id}")
    end
    accounts_by_id = Enum.into(accounts, %{}, fn account -> {account.id, account} end)
    {internal, external} = Enum.split_with(accounts, &(&1.is_internal))
    assign(socket,
      accounts_by_id: accounts_by_id,
      internal_accounts: internal,
      external_accounts: external)
   end

  defp sortable(assigns) do
    ~H"""
    <div class="flex flex-row flex-nowrap">
      <div class="flex-auto">
        <%= @label %>
      </div>
      <div class="flex-none">
        <.sort_up col={@col} cc={@cur_col} cd={@cur_dir}/><.sort_down col={@col} cc={@cur_col} cd={@cur_dir}/>
      </div>
    </div>
    """
  end
  defp sort_up(assigns), do: sort(Map.put(assigns, :dir, "asc"))
  defp sort_down(assigns), do: sort(Map.put(assigns, :dir, "desc"))
  defp sort(assigns) do
    arrow = if assigns.dir == "desc", do: "↓", else: "↑"
    is_active? = assigns.dir == assigns.cd and assigns.col == assigns.cc

    assigns =
      assigns
      |> Map.put(:sort_attrs, %{
          "phx-value-dir" => assigns.dir,
          "phx-value-col" => assigns.col})
      |> Map.put(:arrow, arrow)
    if is_active? do
      ~H"""
      <span class="font-semibold"><%= @arrow %></span>
      """
    else
      ~H"""
      <span phx-click="sort" {@sort_attrs} class="font-light hover:cursor-pointer hover:font-extrabold"><%= @arrow %></span>
      """
    end
  end

  defp y_or_n(nil), do: "N"
  defp y_or_n(0), do: "N"
  defp y_or_n(_), do: "Y"

  defp active_membership(account_id) do
    case Backend.Projections.Membership.all_active_for_account(account_id) do
      [membership | _] -> Atom.to_string(membership.tier)
      _ -> 'free'
    end
  end
end
