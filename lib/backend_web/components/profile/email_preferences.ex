defmodule BackendWeb.Component.EmailPreferences do
  @doc """
  Email preferences component, driven from Hubspot properties. Note that functions
  in here are re-used in the signup flow.
  """

  use BackendWeb, :component
  alias Backend.Integrations.Hubspot

  defmodule Form do
    use Ecto.Schema
    import Ecto.Changeset
    @hubspot_fields [:receive_company_news, :receive_product_updates_email, :receive_weekly_report]

    embedded_schema do
      field :hubspot_contact_id, :string
      field :receive_company_news, :boolean
      field :receive_product_updates_email, :boolean
      field :receive_weekly_report, :boolean
    end

    def changeset(form, params \\ %{}) do
      form
      |> cast(params, [:hubspot_contact_id | @hubspot_fields])
    end

    def hubspot_fields() do
      @hubspot_fields
    end

    def take_hubspot_fields(form) do
      Map.take(form, @hubspot_fields)
    end

    def get_email_preferences_form!(hubspot_contact_id) do
      case Hubspot.get_contact_properties(hubspot_contact_id, Form.hubspot_fields()) do
        {:ok, properties} ->
          %Form{hubspot_contact_id: hubspot_contact_id}
          |> Form.changeset(properties)
          |> apply_changes()

        {:error, reason} ->
          raise "Failed to get hubspot contact properties. Reason: #{reason}"
      end
    end
  end

  def form(assigns) do
    assigns = assign_new(assigns, :class, fn -> nil end)

    ~H"""
    <div class={@class}>
      <%= hidden_input @form, :hubspot_contact_id %>
      <div class="mb-3">
        <%= checkbox @form, :receive_company_news %>
        <%= label @form, :receive_company_news, "Company News" %>
        <%= error_tag @form, :receive_company_news %>
      </div>
      <div class="mb-3">
        <%= checkbox @form, :receive_product_updates_email %>
        <%= label @form, :receive_product_updates_email, "Product Updates" %>
        <%= error_tag @form, :receive_product_updates_email %>
      </div>
      <div class="mb-3">
        <%= checkbox @form, :receive_weekly_report %>
        <%= label @form, :receive_weekly_report, "Weekly Report" %>
        <%= error_tag @form, :receive_weekly_report %>
      </div>
    </div>
    """
  end
end
