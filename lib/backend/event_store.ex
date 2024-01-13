defmodule Backend.EventStore do
  use EventStore,
    otp_app: :backend,
    serializer: Commanded.Serialization.JsonSerializer,
    column_data_type: "jsonb"
end

defmodule Backend.EventStore.Migration do
  use EventStore,
    otp_app: :backend,
    serializer: Commanded.Serialization.JsonSerializer,
    column_data_type: "jsonb"
end
