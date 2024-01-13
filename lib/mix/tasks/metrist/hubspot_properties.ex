defmodule Mix.Tasks.Metrist.HubspotCreateEmailPreference do
  use Mix.Task
  alias Backend.Integrations.Hubspot
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @opts [
    :env,
    {:label, nil, :string, :mandatory, "A human readable label (e.g. 'Product Updates')"},
    {:name, nil, :string, :mandatory, "An internal name (e.g. `'receive_product_updates_email'`)"},
    {:group, nil, :string, :mandatory, "Group name the property belongs to"}
  ]
  @shortdoc "Creates a Hubspot email preference property"

  @moduledoc """
  Creates a Hubspot email preference property

      mix metrist.hubspot_create_email_preference --name receive_product_updates_email --label "Product Updates" --env local

  This task creates a hubspot boolean property which we can use to create an [Active List](https://knowledge.hubspot.com/lists/create-active-or-static-lists).
  Active List is useful for sending marketing emails based on each contact's properties.

  #{Helpers.gen_command_line_docs(@opts)}

  #{Helpers.mix_env_notice()}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    Helpers.configure(opts.env)
    Mix.Task.run("app.config")
    Backend.Application.configure_hubspot()
    Application.ensure_all_started(:hackney)
    label = opts.label
    name = opts.name
    group = opts.group

    params = %{
      name: name,
      label: label,
      type: "enumeration",
      fieldType: "booleancheckbox",
      groupName: group,
      options: [
        %{
          label: "Yes",
          value: "true",
          displayOrder: 0,
          hidden: false
        },
        %{
          label: "No",
          value: "false",
          displayOrder: 1,
          hidden: false
        }
      ]
    }

    case Hubspot.create_property(params, "contact") do
      {:ok, _} -> Logger.info("Successfully created #{name}")
      {:error, reason} -> Logger.error("Failed to create property #{name}. #{reason}")
    end
  end
end

defmodule Mix.Tasks.Metrist.HubspotCreatePropertyGroup do
  use Mix.Task
  alias Backend.Integrations.Hubspot
  alias Mix.Tasks.Metrist.Helpers

  require Logger

  @opts [
    :env,
    {:label, nil, :string, :mandatory, "A human readable label (e.g. 'Product Updates')"},
    {:name, nil, :string, :mandatory, "An internal name (e.g. `'receive_product_updates_email'`)"},
  ]

  @shortdoc "Creates a Hubspot property group"

  @moduledoc """
  Create a hubspot property group

      mix metrist.hubspot_create_property_group --name general_email_subscriptions --label "General Email Subscriptions" --env local

  #{Helpers.gen_command_line_docs(@opts)}
  """

  def run(args) do
    opts = Helpers.parse_args(@opts, args)

    Helpers.configure(opts.env)
    Mix.Task.run("app.config")
    Backend.Application.configure_hubspot()
    Application.ensure_all_started(:hackney)

    label = opts.label
    name = opts.name

    params = %{
      name: name,
      label: label,
      displayOrder: -1
    }

    case Hubspot.create_property_groups(params, "contact") do
      {:ok, _} -> Logger.info("Successfully created #{name}")
      {:error, reason} -> Logger.error("Failed to create property group #{name}. #{reason}")
    end
  end
end
