defmodule Formata.JSONPointer.Compiled do
  @moduledoc """
  Opaque parsed representation returned by `Formata.JSONPointer.compile/1`.

  Values of this type must be created through `Formata.JSONPointer.compile/1`; its
  internal fields are not part of the public API and may change between releases.
  """

  @enforce_keys [:tokens]
  defstruct [:tokens]

  @opaque t :: %__MODULE__{tokens: [String.t()]}
end
