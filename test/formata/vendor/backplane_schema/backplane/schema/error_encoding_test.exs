defmodule Formata.Vendor.BackplaneSchema.ErrorEncodingTest do
  use ExUnit.Case, async: true

  if Code.ensure_loaded?(Formata.Jason) do
    test "encodes errors with Jason when Jason is available" do
      error = %Formata.Backplane.Schema.Error{message: "invalid"}

      assert %{"message" => "invalid"} =
               error |> Formata.Jason.encode!() |> Formata.Jason.decode!()
    end
  end

  if Code.ensure_loaded?(JSON) do
    test "encodes errors with the native JSON module when available" do
      error = %Formata.Backplane.Schema.Error{message: "invalid"}

      assert %{"message" => "invalid"} = error |> JSON.encode!() |> JSON.decode!()
    end
  end
end
