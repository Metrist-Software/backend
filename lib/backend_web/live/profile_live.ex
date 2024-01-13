defmodule BackendWeb.ProfileLive do
  use BackendWeb, :live_view
  require Logger
  alias BackendWeb.Component

  defmodule Form do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :account_name, :string
      field :timezone, :string
      embeds_one :email_preferences, Component.EmailPreferences.Form
    end

    def changeset(form, params \\ %{}, is_read_only \\ false) do
      form
      |> cast(params, [:account_name, :timezone])
      |> cast_embed(:email_preferences, with: &Component.EmailPreferences.Form.changeset/2)
      |> validate_required([:timezone, :email_preferences])
      |> maybe_validate_account_name_required(!is_read_only)
      |> validate_inclusion(:timezone, Tzdata.zone_list(), message: "Invalid timezone")
    end

    defp maybe_validate_account_name_required(form, true), do: validate_required(form, :account_name)
    defp maybe_validate_account_name_required(form, false), do: form

  end

  @impl true
  def mount(_params, %{"current_user" => user}, socket) do
    user = Backend.Projections.get_user!(user.id)
    account = Backend.Projections.get_account!(user.account_id)

    email_preferences =
      Component.EmailPreferences.Form.get_email_preferences_form!(user.hubspot_contact_id)

    form = %Form{
      account_name: account.name,
      timezone: user.timezone || "UTC",
      email_preferences: email_preferences
    }

    {:ok,
     assign(socket,
       user_id: user.id,
       account_id: account.id,
       form: form,
       zone_list: Tzdata.zone_list(),
       changeset: Form.changeset(form),
       page_title: "Profile"
     )}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    changeset =
      socket.assigns.form
      |> Form.changeset(params, socket.assigns.current_user.is_read_only)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    changeset =
      socket.assigns.form
      |> Form.changeset(params)
      |> Map.put(:action, :insert)

    results =
      for {field, change} <- changeset.changes do
        case field do
          :account_name ->
            cmd = %Domain.Account.Commands.UpdateName{
              id: socket.assigns.account_id,
              name: change
            }
            BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)

          :timezone ->
            cmd = %Domain.User.Commands.UpdateTimezone{
              id: socket.assigns.user_id,
              timezone: change
            }

            BackendWeb.Helpers.dispatch_with_auth_check(socket, cmd)

          :email_preferences ->
            Backend.Integrations.Hubspot.update_contact(
              socket.assigns.form.email_preferences.hubspot_contact_id,
              change.changes
            )
        end
      end

    errors =
      Enum.filter(results, &match?({:error, _}, &1))
      |> Enum.map(fn {_, reason} -> reason end)

    socket =
      if length(errors) > 0 do
        Logger.error("Error while saving profile. Reason: #{inspect(errors)}")
        put_flash(socket, :info, "Failed to profile. Please try again")
      else
        put_flash(socket, :info, "Successfully updated profile")
      end

    {:noreply,
     socket
     |> assign(changeset: changeset)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2 class="text-3xl my-4">Profile</h2>
    <.form :let={f} for={@changeset}
      phx-disabled-with="Saving..."
      phx-change="validate"
      phx-submit="save">
      <div class="mb-3 flex flex-col md:flex-row ">
        <%= label f, :account_name, class: "block flex-initial w-64" %>
        <div class="flex flex-1 !w-64">
          <%= if @current_user.is_read_only do %>
            <%= input_value f, :account_name %>
          <% else %>
            <%= text_input f, :account_name %>
            <%= error_tag f, :account_name %>
          <% end %>
        </div>
      </div>
      <div class="mb-3 flex flex-col md:flex-row">
        <%= label f, :timezone, class: "block flex-initial w-64" %>
        <div class="flex flex-initial w-64">
          <%= select f, :timezone, @zone_list %>
          <%= error_tag f, :timezone %>
        </div>
      </div>
      <div class="mb-3 flex flex-col md:flex-row">
        <%= label f, :email_preferences, class: "block flex-initial w-64" %>
        <%= for f <- inputs_for(f, :email_preferences) do %>
          <Component.EmailPreferences.form form={f} class="block flex-initial !w-64"/>
        <% end %>
      </div>
      <h2 class="text-3xl my-4">API</h2>
        <%= if @current_user.is_read_only do %>
          <p class="ml-64 text-muted text-sm mb-3">
            API keys are not accessible to read-only users.
          </p>
        <% end %>
        <div class="mb-3 flex flex-col md:flex-row">
          <%= label f, :auth_Token, class: "block flex-initial w-64" %>
          <.live_component
            module={BackendWeb.Component.APIToken}
            id="auth"
            current_user={@current_user}
            value_kind="auth"
            class="flex flex-col md:flex-row flex-1 !w-64"
          />
        </div>
      <button class="btn btn-green" type="submit" disabled={!@changeset.valid?}>Save</button>
    </.form>
    """
  end
end
