defmodule Formata.ImageInfo do
  @moduledoc """
  Inspects image binaries for their format, MIME type, variant, and pixel dimensions.

  The supported formats are listed in `t:image_format/0`. The one-argument
  functions detect the format automatically. Pass a format as the second
  argument to select a specific parser.

  Detection reads image signatures and metadata. A match can come from a
  partial image binary, including a header with enough bytes to determine
  the dimensions.

  ## Examples

      iex> header = <<137, "PNG", 13, 10, 26, 10, 13::32, "IHDR", 640::32, 480::32>>
      iex> Formata.ImageInfo.seems?(header)
      :png
      iex> Formata.ImageInfo.type(header, :png)
      {"image/png", "PNG"}
      iex> Formata.ImageInfo.info(header)
      {"image/png", 640, 480, "PNG"}
  """
  alias Formata.ImageInfo.Types.AVIF
  alias Formata.ImageInfo.Types.BMP
  alias Formata.ImageInfo.Types.GIF
  alias Formata.ImageInfo.Types.HEIC
  alias Formata.ImageInfo.Types.HEIF
  alias Formata.ImageInfo.Types.ICO
  alias Formata.ImageInfo.Types.JP2
  alias Formata.ImageInfo.Types.JPEG
  alias Formata.ImageInfo.Types.PNG
  alias Formata.ImageInfo.Types.PNM
  alias Formata.ImageInfo.Types.PSD
  alias Formata.ImageInfo.Types.TIFF
  alias Formata.ImageInfo.Types.WEBP

  # Guessing function ordered by global usage
  # https://w3techs.com/technologies/overview/image_format/all
  # Balancing speed of detection and frequency of encounters in real-world scenarios (popularity)
  @types [
    :jpeg,
    :png,
    :webp,
    :avif,
    :gif,
    :heic,
    :heif,
    :bmp,
    :ico,
    :tiff,
    :psd,
    :jp2,
    :pnm
  ]

  @typedoc "Supported image format types."
  @type image_format ::
          :jpeg
          | :jpg
          | :png
          | :webp
          | :avif
          | :gif
          | :heic
          | :heif
          | :bmp
          | :ico
          | :tiff
          | :psd
          | :jp2
          | :pnm

  @doc """
  Checks whether the binary appears to be in the given image format.
  """
  @spec seems?(binary, format :: image_format()) :: boolean
  def seems?(binary, format)
  def seems?(binary, :png), do: PNG.seems?(binary)
  def seems?(binary, :gif), do: GIF.seems?(binary)
  def seems?(binary, :jpeg), do: JPEG.seems?(binary)
  def seems?(binary, :jpg), do: JPEG.seems?(binary)
  def seems?(binary, :bmp), do: BMP.seems?(binary)
  def seems?(binary, :tiff), do: TIFF.seems?(binary)
  def seems?(binary, :webp), do: WEBP.seems?(binary)
  def seems?(binary, :psd), do: PSD.seems?(binary)
  def seems?(binary, :jp2), do: JP2.seems?(binary)
  def seems?(binary, :pnm), do: PNM.seems?(binary)
  def seems?(binary, :ico), do: ICO.seems?(binary)
  def seems?(binary, :avif), do: AVIF.seems?(binary)
  def seems?(binary, :heic), do: HEIC.seems?(binary)
  def seems?(binary, :heif), do: HEIF.seems?(binary)

  @doc """
  Detects the apparent image format, returning its atom or `nil`.
  """
  @spec seems?(binary) :: image_format() | nil
  def seems?(binary), do: try_seems?(binary, @types)

  @doc """
  Returns `{mime_type, variant}` for the given format, or `nil` if it cannot be read.
  """
  @spec type(binary, format :: image_format()) ::
          {mimetype :: String.t(), variant :: String.t()} | nil
  def type(binary, format)
  def type(binary, :png), do: PNG.type(binary)
  def type(binary, :gif), do: GIF.type(binary)
  def type(binary, :jpeg), do: JPEG.type(binary)
  def type(binary, :jpg), do: JPEG.type(binary)
  def type(binary, :bmp), do: BMP.type(binary)
  def type(binary, :tiff), do: TIFF.type(binary)
  def type(binary, :webp), do: WEBP.type(binary)
  def type(binary, :psd), do: PSD.type(binary)
  def type(binary, :jp2), do: JP2.type(binary)
  def type(binary, :pnm), do: PNM.type(binary)
  def type(binary, :ico), do: ICO.type(binary)
  def type(binary, :avif), do: AVIF.type(binary)
  def type(binary, :heic), do: HEIC.type(binary)
  def type(binary, :heif), do: HEIF.type(binary)

  @doc """
  Detects the image format and returns `{mime_type, variant}` or `nil`.
  """
  @spec type(binary) :: {mimetype :: String.t(), variant :: String.t()} | nil
  def type(binary), do: try_type(binary, @types)

  @doc """
  Returns `{mime_type, width, height, variant}` for the given image format,
  or `nil` if the dimensions cannot be read.

  For ICO, the dimensions are for the largest image. For AVIF, HEIC, and
  HEIF, they are for the primary image.
  """
  @spec info(binary, format :: image_format()) ::
          {mimetype :: String.t(), width :: integer(), height :: integer(), variant :: String.t()}
          | nil
  def info(binary, format)
  def info(binary, :png), do: PNG.info(binary)
  def info(binary, :gif), do: GIF.info(binary)
  def info(binary, :jpeg), do: JPEG.info(binary)
  def info(binary, :jpg), do: JPEG.info(binary)
  def info(binary, :bmp), do: BMP.info(binary)
  def info(binary, :tiff), do: TIFF.info(binary)
  def info(binary, :webp), do: WEBP.info(binary)
  def info(binary, :psd), do: PSD.info(binary)
  def info(binary, :jp2), do: JP2.info(binary)
  def info(binary, :pnm), do: PNM.info(binary)
  def info(binary, :ico), do: ICO.info(binary)
  def info(binary, :avif), do: AVIF.info(binary)
  def info(binary, :heic), do: HEIC.info(binary)
  def info(binary, :heif), do: HEIF.info(binary)

  @doc """
  Detects the image format and returns the result of `info/2` or `nil`.
  """
  @spec info(binary) ::
          {mimetype :: String.t(), width :: integer(), height :: integer(), variant :: String.t()}
          | nil
  def info(binary), do: try_info(binary, @types)

  defp try_seems?(_binary, []), do: nil

  defp try_seems?(binary, [type | types]) do
    if seems?(binary, type), do: type, else: try_seems?(binary, types)
  end

  defp try_type(_binary, []), do: nil

  defp try_type(binary, [type | types]) do
    case type(binary, type) do
      type_t when is_tuple(type_t) -> type_t
      _ -> try_type(binary, types)
    end
  end

  defp try_info(_binary, []), do: nil

  defp try_info(binary, [type | types]) do
    case info(binary, type) do
      info_t when is_tuple(info_t) -> info_t
      _ -> try_info(binary, types)
    end
  end
end
