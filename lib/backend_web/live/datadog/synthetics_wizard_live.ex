defmodule BackendWeb.Datadog.SyntheticsWizardLive do
  @moduledoc """
  Runs a wizard as a widget in a DD app that can setup synthetics quickly.
  """

  @test_config_region "us-west-2"
  @test_config_bucket "metrist-private-assets"

  use BackendWeb, :dd_live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Install synthetics",
        synthetic_configs: [],
        existing_configs: [],
        current_synthetic_index: 0,
        variable_values: %{},
        selected_monitors: [],
        step_contents: nil,
        allow_continue: false,
        errors: [],
        use_password_input: true
        )


    {
      :ok,
      socket
      |> load_synthetic_configs()
    }
  end

  @impl true
  def handle_params(_params, _uri, socket)
    when length(socket.assigns.selected_monitors) == 0
    and socket.assigns.live_action != :start
    and socket.assigns.live_action != :complete do
    {
      :noreply,
      socket
      |> redirect(to: Routes.synthetics_wizard_path(socket, :start))
    }
  end

  def handle_params(_params, _uri, socket) do
    {
      :noreply,
      socket
      |> assign_step_contents()
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="synthetics-wizard" phx-hook="DatadogSyntheticsWizard" class="w-4/5 min-w-fit m-5">
      <.alert :for={error <- @errors} color="danger" label={error} />

      <%= @step_contents.(assigns) %>
    </div>
    """
  end

  @impl true
  def handle_event("submit-configuration", value, %{ assigns: assigns } = socket) do
    all_config_values =
      assigns.variable_values
      |> Map.put(assigns.current_synthetic_index, value)

    case validate(value) do
      :invalid ->
        {
          :noreply,
          socket
          |> assign(
            errors: ["Please provide a value for all config options"],
            form: to_form(value))
          |> assign_step_contents()
        }
      :valid ->
        socket
        |> assign(
          variable_values: all_config_values,
          form: nil)
        |> do_submit()
    end
  end

  def handle_event("configuration-change", value, socket) do
    {
      :noreply,
      socket
      |> assign(form: to_form(value))
    }
  end

  def handle_event("go-back", _value, %{ assigns: %{ current_synthetic_index: current_synthetic_index } } = socket) when current_synthetic_index == 0 do
    {
      :noreply,
      socket
      |> assign(
        form: nil
      )
      |> push_patch(to: Routes.synthetics_wizard_path(socket, :start))
    }
  end

  def handle_event("go-back", _value, %{ assigns: %{ current_synthetic_index: current_synthetic_index } } = socket) do
    {
      :noreply,
      socket
      |> assign(current_synthetic_index: current_synthetic_index - 1, form: nil)
      |> assign_step_contents()
    }
  end

  def handle_event("datadog-initialized", %{ "tests" => tests }, socket) do
    {
      :noreply,
      socket
      |> assign(
        existing_configs: tests,
        allow_continue: true
      )
      |> assign_step_contents()
    }
  end

  def handle_event("creation-complete", value, socket) when value == %{} do
    {
      :noreply,
      socket
      |> assign(
        current_synthetic_index: 0,
        variable_values: %{},
        selected_monitors: []
      )
      |> push_patch(to: Routes.synthetics_wizard_path(socket, :complete))
    }
  end

  def handle_event("complete-choose-monitors", value, socket) when value == %{} do
    {
      :noreply,
      socket
      |> assign(errors: ["At least one monitor must be selected"])
      |> assign_step_contents()
    }
  end

  def handle_event("complete-choose-monitors", value, socket) do
    selected_indices = Enum.map(value, fn {k,_v} ->
      {val, _rem} = Integer.parse(k)
      val
    end)
    {
      :noreply,
      socket
      |> assign(selected_monitors: selected_indices, errors: [])
      |> push_patch(to: Routes.synthetics_wizard_path(socket, :configure_monitors))
    }
  end

  def handle_event("toggle-password", _, socket) do
    {
      :noreply,
      socket
      |> assign(:use_password_input, !socket.assigns.use_password_input)
    }
  end

  def handle_event("close_sidepanel", _, socket) do
    {
      :noreply,
      push_event(socket, "close_side_panel", %{})
    }
  end

  defp assign_step_contents(%Phoenix.LiveView.Socket{assigns: assigns} = socket) do
    assign(socket, :step_contents, step_contents(assigns.live_action))
  end

  defp step_contents(live_action) do
    case live_action do
      :start -> &render_choose_monitors/1
      :configure_monitors -> &render_monitor_configuration/1
      :creating -> &render_creating/1
      :complete -> &render_complete/1
    end
  end

  defp render_monitor_configuration(assigns) do
    assigns = assign(assigns,
      current_config: get_current_config(assigns)
    )

    # Need this to reload current value if someone is moving back and forward through the wizard
    current_values =
      Map.get(assigns.variable_values, assigns.current_synthetic_index, %{})

    # Bit of a hack to get initial assigns for the current step. Expects the
    # :form key to be cleared between steps
    assigns = if Map.get(assigns, :form) do
      assigns
    else
      form_data = Map.get(assigns.current_config.config, :configVariables, [])
      |> Enum.into(%{}, fn var -> {var.name, Map.get(current_values, var.name, "")} end)
      |> to_form()

      assign(assigns, form: form_data)
    end

    ~H"""
      <div class="mb-5">Configure <span class="font-bold"><%= @current_config.name %></span></div>
      <.form for={@form} phx-submit="submit-configuration" phx-change="configuration-change">

        <%= if Enum.empty?(Map.get(@current_config.config, :configVariables, [])) do %>
          <div class="mt-5">There are no configuration variables to configure for this monitor</div>
        <% else %>
          <.button icon={if @use_password_input, do: :eye_slash, else: :eye} size="sm" color="white" phx-click="toggle-password" type="button" />

          <%= for config_value <- Map.get(@current_config.config, :configVariables, []) do %>
            <.config_parameter config_value={config_value} form={@form} use_password_input={@use_password_input}  />
          <% end %>
        <% end %>

        <div class="mt-2">
          <.button
            :if={@current_synthetic_index != 0}
            type="button"
            color="white"
            phx-click="go-back"
            label="Back"
          />

          <.button
            type="submit"
            color="info"
            label={get_next_button_text(assigns)}
          />

          <.button
            link_type="live_redirect"
            to={Routes.synthetics_wizard_path(@socket, :start)}
            color="white"
            label="Start Over"
          />
        </div>
      </.form>

      <p class="mt-3 text-sm text-red-500">Note: All config values will be stored as hidden and obfuscated variables</p>
    """
  end

  defp config_parameter(assigns) do
    assigns = assign(assigns,
      field: String.to_atom(assigns.config_value.name),
      description: Map.get(assigns.config_value, :description),
      existing_value: assigns.form.params[assigns.config_value.name],
      display_name: Map.get(assigns.config_value, :displayName, assigns.config_value.name)
    )
    ~H"""
      <.form_label form={@form} field={@field} label={@display_name} class="mb-0 mt-2" />
      <span class="text-xs text-muted block"><%= @description %></span>
      <%!-- Need to explicitly set value for password fields so that it doesn't get cleared between submit attempts --%>
      <%= if @use_password_input do %>
        <.password_input form={@form} field={@field} value={@existing_value} />
      <% else %>
        <.text_input form={@form} field={@field} value={@existing_value} />
      <% end %>
      <.form_field_error form={@form} field={@field} class="mt-1" />
    """
  end

  defp get_current_config(%{ synthetic_configs: synthetic_configs, selected_monitors: selected_monitors, current_synthetic_index: current_synthetic_index }) do
    Enum.at(synthetic_configs,
      Enum.at(selected_monitors, current_synthetic_index)
    )
  end

  defp render_creating(assigns) do
    ~H"""
      Please wait while we create or update your synthetic tests....
    """
  end

  defp render_complete(assigns) do
    ~H"""
    <div class="text-center">
      <p>Your synthetics have been created and/or updated successfully.</p>
      <p class="mt-3 mb-3">All newly created synthetics were created in a <strong>paused</strong> state with <strong>N. California (AWS)</strong> as the location they run from. You will need to enable scheduling on those from within Datadog when ready.</p>
      <p class="mt-3 mb-3">You can change all test parameters including which locations they execute from as well as their frequency directly within Datadog. To do this, click on the "View your Metrist synthetics" button below and then click on a specific synthetic test or click on a synthetic test on the Metrist health dashboard.</p>
      <div>
        <.button type="button" id="ddMonitorsButton" color="white" label="View your Metrist synthetics" />
        <.button link_type="live_redirect" to={Routes.synthetics_wizard_path(@socket, :start)} color="white" label="Start Over" />
        <.button phx-click="close_sidepanel" label="Close" />
      </div>
    </div>
    """
  end

  defp render_choose_monitors(%{ allow_continue: false } = assigns) do
    ~H"""
    """
  end

  defp render_choose_monitors(assigns) do
    grouped_configs =
      assigns.synthetic_configs
      |> group_configs_by_existing(assigns.existing_configs)

    assigns = assign(assigns,
      existing_configs: Map.get(grouped_configs, :existing_configs, []),
      new_configs: Map.get(grouped_configs, :new_configs, [])
    )

    ~H"""
    Which synthetic tests would you like to setup?
    <form phx-submit="complete-choose-monitors" class="mt-2 w-fit">
      <%= for {config,i} <- @new_configs do %>
        <%= render_monitor_select(config, i) %>
      <% end %>

      <%= if not Enum.empty?(@existing_configs) do %>
        <div class="font-bold">The following synthetic tests already exists and will be updated if chosen.</div>
        <%= for {config,i} <- @existing_configs do %>
          <%= render_monitor_select(config, i) %>
        <% end %>
      <% end %>

      <.button color="info" label="Next" class="mt-2" />
    </form>
    """
  end

  defp render_monitor_select(config, index) do
    assigns = %{config: config, index: index}
    ~H"""
        <div class="ml-5 w-fit">
        <input
            type="checkbox"
            name={"#{@index}"}
            id={"toggle-#{@index}"}
            class="checkbox-lg"
        />
        <label for={"toggle-#{@index}"} class="cursor-pointer"><%= @config.name %></label>
        </div>
    """
  end

  defp group_configs_by_existing(configs, existing_configs) do
    existing_configs_by_index =
      existing_configs_by_index(configs, existing_configs)

    configs
    |> Enum.with_index()
    |> Enum.group_by(fn {_config, index} ->
      case Map.has_key?(existing_configs_by_index, index) do
        true ->
          :existing_configs
        false ->
          :new_configs
      end
    end)
  end

  defp get_postable_config(config, config_variable_values, existing_config \\ nil)
  defp get_postable_config(config, config_variable_values, nil) do
    updated_configVariables =
      Map.get(config.config, :configVariables, [])
      |> Enum.map(fn config_var ->
        config_var
        |> maybe_set_pattern_on_config_var(config_variable_values)
        |> maybe_set_example_on_config_var
        |> maybe_remove_metrist_only_properties_on_config_var
      end)

    # Remove values that should not be there for create if present, tag, ensure paused, and update config values
    config
    |> Map.drop([:public_id, :created_at, :modified_at, :monitor_id, :creator])
    |> Map.put(:tags, ["metrist-created" | config.tags])
    |> Map.put(:status, "paused")
    |> put_in([:config, :configVariables], updated_configVariables)
  end
  defp get_postable_config(config, config_variable_values, existing_config) do
    # We use the existing configs public_id, status, and locations when updating.
    get_postable_config(config, config_variable_values)
      |> Map.put(:public_id, Map.get(existing_config, "public_id"))
      |> Map.put(:status, Map.get(existing_config, "status"))
      |> Map.put(:locations, Map.get(existing_config, "locations"))
  end

  # Oddly enough you set pattern to set the value
  defp maybe_set_pattern_on_config_var(config_var, values) when is_map_key(values, config_var.name) do
    Map.put(config_var, :pattern, values[config_var.name])
  end
  defp maybe_set_pattern_on_config_var(config_var, _values), do: config_var

  # Datadog support has come back and told us that "example" needs to be included for validation to always work correctly....
  # It's a little silly as if it's a subtype multi this isn't needed but for a single step API test it is
  # It is also not noted as required at all in their docs.. If we don't have example, simply set example
  # to the name of the variable always...
  defp maybe_set_example_on_config_var(config_var) when is_map_key(config_var, :example), do: config_var
  defp maybe_set_example_on_config_var(config_var), do: Map.put(config_var, :example, config_var.name)

  defp get_next_button_text(%{ selected_monitors: selected_monitors, current_synthetic_index: current_synthetic_index}) do
    if is_last_config(selected_monitors, current_synthetic_index) do
      "Complete"
    else
      "Next"
    end
  end

  #description and displayName are fields that were added by us to facilitate a more pleasant wizard experience.
  #They are not officially supported by the datadog synthetics API so remove them if they are there before posting.
  defp maybe_remove_metrist_only_properties_on_config_var(config_var) when is_map_key(config_var, :description) or is_map_key(config_var, :displayName) do
    config_var
    |> Map.drop([:description, :displayName])
  end
  defp maybe_remove_metrist_only_properties_on_config_var(config_var), do: config_var

  defp is_last_config(selected_monitors, current_synthetic_index)
    when current_synthetic_index == length(selected_monitors) - 1, do: true
  defp is_last_config(_selected_monitors, _current_synthetic_index), do: false

  defp validate(value) do
    if Enum.any?(value, fn {_k, v} -> v == "" end) do
      :invalid
    else
      :valid
    end
  end

  defp do_submit(%{ assigns: %{ selected_monitors: selected_monitors, current_synthetic_index: current_synthetic_index} } = socket) do
    case is_last_config(selected_monitors, current_synthetic_index) do
      true -> do_final_submit(socket)
      false -> do_interim_submit(socket)
    end
  end

  defp do_final_submit(%{ assigns: assigns} = socket) do
    existing_configs_by_index =
      existing_configs_by_index(assigns.synthetic_configs, assigns.existing_configs)

    submission_configs =
      for {selected_monitor, i} <- Enum.with_index(assigns.selected_monitors) do
        get_postable_config(Enum.at(assigns.synthetic_configs, selected_monitor), Map.get(assigns.variable_values, i), Map.get(existing_configs_by_index, selected_monitor))
      end


      {:noreply,
        socket
        |> assign(errors: [])
        |> push_event("create_tests", %{
          new_configs: submission_configs |> Enum.filter(&(not Map.has_key?(&1, :public_id))),
          existing_configs: submission_configs |> Enum.filter(&(Map.has_key?(&1, :public_id)))
        })
        |> push_patch(to: Routes.synthetics_wizard_path(socket, :creating))
      }
  end

  defp existing_configs_by_index(synthetic_configs, existing_configs) do
    synthetic_configs
    |> Enum.with_index()
    |> Enum.map(fn {config, index} ->
      identifier = Enum.find(config.tags, fn tag -> String.starts_with?(tag, "metrist-identifier:") end)
      {
        index,
        existing_configs
        |> Enum.find(fn existing -> identifier in Map.get(existing, "tags") end)
      }
    end)
    |> Enum.reject(fn {_index, config} -> is_nil(config) end)
    |> Map.new()
  end

  defp do_interim_submit(%{ assigns: assigns} = socket) do
    {
      :noreply,
      socket
      |> assign(
        current_synthetic_index: assigns.current_synthetic_index + 1,
        errors: []
      )
      |> assign_step_contents()
    }
  end

  defp get_test_config_file_for_env() do
    if Backend.Application.is_prod?() do
      "datadog/datadog-synthetics.json"
    else
      "datadog/datadog-synthetics-preview.json"
    end
  end

  defp load_synthetic_configs(socket) do
    { :ok, %{body: body, status_code: 200} }=
      ExAws.S3.get_object(@test_config_bucket, get_test_config_file_for_env())
      |> ExAws.request(region: @test_config_region)

    socket
    |> assign(synthetic_configs: Jason.decode!(body, keys: :atoms) |> Enum.sort_by(&(&1.name)))
  end
end
