defmodule Formata.Codec.EncodingKeysTest do
  use ExUnit.Case, async: true

  alias Formata.Codec.TOML.Encoder
  alias Formata.Error

  @codecs [
    toml: Encoder,
    json: Formata.Codec.JSON,
    json5: Formata.Codec.JSON5,
    yaml: Formata.Codec.YAML
  ]

  defp contexts(key) do
    [
      {%{key => 1}, []},
      {%{"table" => %{"nested" => %{key => 1}}}, ["table", "nested"]},
      {%{"tables" => [%{}, %{key => 1}]}, ["tables", 1]},
      {%{"mixed" => [1, %{"inline" => %{key => 1}}]}, ["mixed", 1, "inline"]}
    ]
  end

  test "invalid UTF-8 keys return structured errors before any encoder renders them" do
    for key <- [<<0xFF>>, <<0xC3>>, <<0xC0, 0xAF>>],
        {data, path} <- contexts(key),
        {format, codec} <- @codecs,
        encode <- [&codec.encode/1, &Formata.encode(&1, format)] do
      assert {:error, [%Error{} = error]} = encode.(data)
      assert error.kind == :encode
      assert error.code == :invalid_key
      assert error.format == format
      assert error.backend == codec
      # Key errors identify the containing map, with the offending key in details.
      assert error.path == path
      assert error.details == %{key: key}
      assert error.message =~ "not valid UTF-8"
      assert error.location == nil
    end
  end

  test "valid Unicode, empty and escaped keys survive every table layout" do
    for key <- ["雪😀", "", "a.b", "space key", "quote\"slash\\", "line\n\ttab"],
        {data, _path} <- contexts(key),
        {format, codec} <- @codecs,
        encode <- [&codec.encode/1, &Formata.encode(&1, format)] do
      assert {:ok, encoded} = encode.(data)
      assert {:ok, ^data} = Formata.decode(encoded, format)
    end
  end

  test "shared key validation retains YAML integer and boolean keys" do
    data = %{7 => %{"nested" => %{true => 1, false => 2}}}
    assert {:ok, encoded} = Formata.encode(data, :yaml)
    assert {:ok, ^data} = Formata.decode(encoded, :yaml)

    for format <- [:toml, :json, :json5] do
      assert {:error, errors} = Formata.encode(data, format)
      assert Enum.all?(errors, &match?(%Error{kind: :encode, code: :invalid_key}, &1))
    end
  end
end
