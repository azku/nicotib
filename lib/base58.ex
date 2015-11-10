defmodule Nicotib.Base58 do
  @alphabet ~c(123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz)

  @doc """
  Encodes the given string.
  """
	def encode(<<0, t :: binary>>) do
		t_enc = encode(t)
		<<?1, t_enc :: binary>>
	end
  def encode(x), do: encode(:binary.decode_unsigned(x, :big), <<>>)

	
	def encode(0, acc), do: acc
	def encode(n, acc) do
		c = Enum.at(@alphabet, rem(n, 58))
		encode(div(n, 58), <<c :: unsigned - size(8), acc :: binary>>)
	end


	def decode(<<?1, t :: binary>>) do
		t_dec = decode(t)
		<<0, t_dec :: binary>>
	end
	def decode(<<>>), do: <<>>
  def decode(x), do: :binary.encode_unsigned(decode(x, 0), :big)
	def decode(<<>>, n), do: n
	def decode(<<c :: unsigned - size(8), t :: binary>>, n) do
		decode(t, n * 58 + Enum.find_index(@alphabet, &(&1 ==  c)))
	end

end
