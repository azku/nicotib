defmodule Nicotib.Utils do
	@doc ~S"""
	Small independent functions used by Nicotib
"""

	def pad_to_x(bin, x) do
		b_size = (x - :erlang.size(bin)) * 8
		<<bin :: binary, 0 :: size(b_size)>>
	end

	def bitcoin_addr_to_ip_address(<< 0 :: size(80), 255, 255, ip3, ip2, ip1, ip0 >>) do
		{ip3, ip2, ip1, ip0}
	end
	def bitcoin_addr_to_ip_address(<< ip7 :: size(16), ip6 :: size(16), ip5 :: size(16), ip4 :: size(16),
																 ip3 :: size(16), ip2 :: size(16), ip1 :: size(16), ip0 :: size(16) >>) do
		{ip7, ip6, ip5, ip4, ip3, ip2, ip1, ip0}
	end

	def bin_to_hex(bin) do
		for <<i::4 <- bin >>, do: hd(Integer.to_char_list(i, 16))
	end

	def hex_to_bin(str) do
		(for h <- str, do: << String.to_integer(to_string([h]), 16) ::4 >>)
		|> Enum.reduce(fn(<<a::size(4)>>,<<b::bitstring>>)-> << b::bitstring, a::size(4) >>  end)
	end

	def unix_time do
		:erlang.system_time(:seconds)
	end
end
