defmodule BackendWeb.I18n do

  # Cheapest way from A->B, borrow the old Vue translations file.
  @external_resource "priv/en.json"

  @en "priv/en.json"
  |> File.read!()
  |> Jason.decode!()

  def str(s) do
    get_in(@en, String.split(s, "."))
  end
end
