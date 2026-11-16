defmodule Formata.NativeSchema.Parser do
  @moduledoc """
  The `Formata.NativeSchema.Parser` module is responsible for managing the state during schema validation.
  It centralizes functions to handle updating data, adding errors, and managing the path within 
  the data structure being validated.

  ## Struct
  The `Formata.NativeSchema.Parser` struct has the following fields:

  - `:data` - The current state of the data being validated.
  - `:errors` - A list of errors encountered during validation.
  - `:path` - The current path within the data structure being validated.
  """

  defstruct [
    :data,
    :root_data,
    :current_data,
    field_presence?: true,
    errors: [],
    path: [],
    ref_depth: 0
  ]

  def for_field(%__MODULE__{} = parent, key, exists?) do
    root = parent.root_data || parent.data
    current_data = parent.current_data || parent.data
    path = path(parent) ++ List.wrap(key)

    %{
      parent
      | current_data: current_data,
        root_data: root,
        field_presence?: exists?,
        path: path
    }
  end

  @doc false
  def push_field(%__MODULE__{} = parent, key, exists?, parent_path_rev) do
    root = parent.root_data || parent.data
    current_data = parent.current_data || parent.data

    %{
      parent
      | current_data: current_data,
        root_data: root,
        field_presence?: exists?,
        path: {:peri_path_rev, [key | parent_path_rev]}
    }
  end

  @doc false
  def path(%__MODULE__{path: {:peri_path_rev, path}}), do: Enum.reverse(path)
  def path(%__MODULE__{path: path}), do: List.wrap(path)

  @doc false
  def path_rev(%__MODULE__{path: {:peri_path_rev, path}}), do: path
  def path_rev(%__MODULE__{path: path}), do: Enum.reverse(List.wrap(path))

  @doc false
  def internal_path(path), do: {:peri_path_rev, path}

  @doc """
  Initializes a new `Formata.NativeSchema.Parser` struct with the given data.

  ## Parameters
  - `data` - The initial data to be validated.

  ## Examples

      iex> Formata.NativeSchema.Parser.new(%{name: "Alice"})
      %Formata.NativeSchema.Parser{data: %{name: "Alice"}, errors: [], path: []}
  """
  def new(data, root_data: root) do
    %__MODULE__{data: data, root_data: root, current_data: data, errors: [], path: []}
  end

  @doc """
  Updates the data in the parser state at the given key with the specified value.

  ## Parameters
  - `state` - The current `Formata.NativeSchema.Parser` state.
  - `key` - The key to update in the data.
  - `val` - The value to set at the specified key.

  ## Examples

      iex> state = Formata.NativeSchema.Parser.new(%{name: "Alice"})
      iex> Formata.NativeSchema.Parser.update_data(state, :age, 30)
      %Formata.NativeSchema.Parser{data: %{name: "Alice", age: 30}, errors: [], path: []}
  """
  def update_data(%__MODULE__{} = state, key, val) do
    %{state | data: Formata.NativeSchema.put_in_enum(state.data, key, val)}
  end

  @doc """
  Adds an error to the parser state's list of errors.

  ## Parameters
  - `state` - The current `Formata.NativeSchema.Parser` state.
  - `err` - The `%Formata.NativeSchema.Error{}` struct representing the error to add.

  ## Examples

      iex> state = Formata.NativeSchema.Parser.new(%{name: "Alice"})
      iex> error = %Formata.NativeSchema.Error{path: [:name], message: "is required", content: []}
      iex> Formata.NativeSchema.Parser.add_error(state, error)
      %Formata.NativeSchema.Parser{data: %{name: "Alice"}, errors: [%Formata.NativeSchema.Error{path: [:name], message: "is required", content: []}], path: []}
  """
  def add_error(%__MODULE__{} = state, %Formata.NativeSchema.Error{} = err) do
    %{state | errors: [err | state.errors]}
  end

  @doc """
  Creates a new parser for a list element, preserving the root data.

  ## Parameters
  - `element_data` - The data for the current list element.
  - `parent_parser` - The parent parser containing root data and path information.
  - `index` - The index of the element in the list.

  ## Examples

      iex> parent = Formata.NativeSchema.Parser.new(%{items: [1, 2, 3]}, root_data: %{items: [1, 2, 3]})
      iex> Formata.NativeSchema.Parser.for_list_element(1, parent, 0)
      %Formata.NativeSchema.Parser{data: 1, current_data: 1, root_data: %{items: [1, 2, 3]}, errors: [], path: [0]}
  """
  def for_list_element(element_data, %__MODULE__{} = parent_parser, index) do
    %__MODULE__{
      data: element_data,
      current_data: element_data,
      root_data: parent_parser.root_data || parent_parser.data,
      errors: [],
      path: path(parent_parser) ++ [index],
      ref_depth: parent_parser.ref_depth
    }
  end

  @doc false
  def push_list_element(element_data, %__MODULE__{} = parent_parser, index) do
    %__MODULE__{
      data: element_data,
      current_data: element_data,
      root_data: parent_parser.root_data || parent_parser.data,
      errors: [],
      path: internal_path([index | path_rev(parent_parser)]),
      ref_depth: parent_parser.ref_depth
    }
  end

  @doc """
  Increments the ref-resolution depth counter. Used by `{:ref, _}`
  directive resolution to bound recursion on cyclic data.
  """
  def bump_ref_depth(%__MODULE__{ref_depth: d} = state), do: %{state | ref_depth: d + 1}
end
