defmodule Backend.Sentry do
  def before_send(event) do
    reg = ~r/.*received unexpected message: {:(EXIT|DOWN),.*}.*/

    if !Regex.match?(reg, event.message) do
      event
    end
  end
end
