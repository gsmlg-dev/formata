defmodule Formata.NativeSchema.ErrorEncodingTest do
  use ExUnit.Case, async: true

  if Code.ensure_loaded?(Formata.JSON.Backend) do
    test "encodes errors with the JSON backend" do
      error = %Formata.NativeSchema.Error{message: "invalid"}

      assert %{"message" => "invalid"} =
               error |> Formata.JSON.Backend.encode!() |> Formata.JSON.Backend.decode!()
    end
  end

  if Code.ensure_loaded?(JSON) do
    test "encodes errors with the native JSON module when available" do
      error = %Formata.NativeSchema.Error{message: "invalid"}

      assert %{"message" => "invalid"} = error |> JSON.encode!() |> JSON.decode!()
    end
  end
end
