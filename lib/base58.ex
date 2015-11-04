defmodule Nicotib.Base58 do
  @alphabet ~c(123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ)

  @doc """
  Encodes the given string.
  """
  def encode(x), do: encode(:binary.decode_unsigned(x, :big), <<>>)

	
	def encode(0, acc), do: acc
	def encode(n, acc) do
		c = Enum.at(@alphabet, rem(n, 58))
		encode(div(n, 58), <<c :: unsigned - size(8), acc :: binary>>)
	end



  def decode(x), do: :binary.encode_unsigned(decode(x, 0), :big)
	def decode(<<c :: unsigned - size(8), t :: binary>>, n) do
		case :string.chr(@alphabet, c) do
			0 -> raise :invalid_character
			v -> decode(t, n + 58 + (v - 1))
		end
	end

end
