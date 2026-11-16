defmodule Formata.Codec.YAMLConformanceTest do
  use ExUnit.Case, async: true

  alias Formata.Error

  @root Path.expand("../../fixtures/yaml-test-suite", __DIR__)
  # Discover leaf cases, including numbered subtests (9MQT/00 and 9MQT/01).
  @inputs @root |> Path.join("**/in.yaml") |> Path.wildcard() |> Enum.sort()
  @policy_errors %{
    "2JQS" => {:parse, :duplicate_key},
    "4FJ6" => {:unsupported, :unsupported_key},
    "6BFJ" => {:unsupported, :unsupported_key},
    "NKF9" => {:parse, :multiple_documents}
  }

  for input <- @inputs do
    @external_resource input
    name = input |> Path.dirname() |> Path.relative_to(@root)
    error_marker = Path.join(Path.dirname(input), "error")
    expected = Path.join(Path.dirname(input), "in.json")

    cond do
      Map.has_key?(@policy_errors, name) ->
        {kind, code} = Map.fetch!(@policy_errors, name)

        test "documented profile rejection: #{name}" do
          assert {:error, [%Error{kind: unquote(kind), code: unquote(code)}]} =
                   Formata.decode(File.read!(unquote(input)), :yaml)
        end

      File.exists?(error_marker) ->
        test "official invalid input: #{name}" do
          assert {:error, [%Error{kind: :parse, code: :syntax}]} =
                   Formata.decode(File.read!(unquote(input)), :yaml)
        end

      true ->
        @external_resource expected

        test "official semantic input and emission: #{name}" do
          expected = unquote(expected) |> File.read!() |> Formata.JSON.Backend.decode!()
          assert {:ok, ^expected} = Formata.decode(File.read!(unquote(input)), :yaml)
          assert {:ok, yaml} = Formata.encode(expected, :yaml)
          assert {:ok, ^expected} = Formata.decode(yaml, :yaml)
        end
    end
  end
end
