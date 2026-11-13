defmodule Formata.Test.JSONDerived do
  @moduledoc false
  # Compiled with the test support files (before protocol consolidation), so
  # its derived JSON.Encoder implementation is visible to the tests.
  @derive JSON.Encoder
  defstruct [:id, :name]
end
