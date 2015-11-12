defmodule Nicotib.Protocol do
	require Nicotib.Configuration
	alias Nicotib.Configuration, as: C

	defmacrop inv_vector_decoding(command, payload) do
		quote do
			{count,_ , b_inv_vector} = variable_length_integer(unquote(payload))
			inv_vector = for << type :: binary - size(4), hash :: binary - size(32) <- b_inv_vector>> do
																																		 %{type: :binary.decode_unsigned(type, :little),
																																			 hash: hash}
			end
			true = count == length(inv_vector)
			%{command: unquote(command), inv_vect: inv_vector}
		end
	end
	defmacro inv_vector_encoding(inv_vect) do
		quote do
			:erlang.list_to_binary([integer_to_variable_length(length(unquote(inv_vect))),
														 (for %{:type => type, :hash => hash} <- unquote(inv_vect), do: [C.encpadl(type, 4), hash])])
		end
	end
	
	def check_message_validity(C.msg_header( _, pl_checksum, pl)) do
		<< calculated_checksum :: binary - size(4), _ :: binary >> = :crypto.hash(:sha256, :crypto.hash(:sha256, pl))
		pl_checksum == calculated_checksum
	end


	def generate_key_pair do
    {pub, priv} = :crypto.generate_key(:ecdh, :secp256k1)
    {public_to_address(pub), private_to_wif(priv)}
	end

	def public_to_address(pub) do
    ##https://en.bitcoin.it/wiki/Technical_background_of_Bitcoin_addresses
    prefix = Nicotib.Utils.hex_to_bin('04')
    sha256 = :crypto.hash(:sha256, << prefix :: binary, pub :: binary >>)
    ripem160 = :crypto.hash(:ripemd160, sha256)
    v_byte = Nicotib.Utils.hex_to_bin('00')
    ex_sha256 = :crypto.hash(:sha256, << v_byte :: binary, ripem160 :: binary >>)
    << c1, c2, c3, c4, _ :: binary>> = :crypto.hash(:sha256, ex_sha256)
    Nicotib.Base58.encode(<<v_byte :: binary, ripem160 :: binary, c1, c2, c3, c4>>)
	end
	
	def script_pub_key_to_address(script_pubKey) do
    v_byte = Nicotib.Utils.hex_to_bin('00')
    ex_sha256 = :crypto.hash(:sha256, << v_byte :: binary, script_pubKey :: binary>>)
    << c1, c2, c3, c4, _ :: binary >> = :crypto.hash(:sha256, ex_sha256)
    Nicotib.Base58.encode(<< v_byte :: binary, script_pubKey :: binary, c1, c2, c3, c4>>)
	end

	def private_to_wif(k) when is_binary(k) do
    prefix = Nicotib.Utils.hex_to_bin('80')
    hash = :crypto.hash(:sha256, << prefix :: binary, k :: binary>>)
    <<c1,c2,c3,c4, _ :: binary>> = :crypto.hash(:sha256, hash)
    Nicotib.Base58.encode(<< prefix :: binary, k :: binary, c1,c2,c3,c4>>)
	end

	def wif_to_private(wifi_key) do
    << b1 :: size(264), _ ,_ ,_ ,_ >> = Nicotib.Base58.decode(wifi_key)
    << _ , b2 :: binary>> = <<b1 :: size(264) >>
    b2
	end

	def decode_msg(C.msg_header(:version, _, _, C.version_payload(version, network, timestamp, addr1, addr2, nonce, rest))) do
		{_, ua, <<last_block :: binary - size(4), relay>>} = variable_length_string(rest)
		%{command: :version, version: :binary.decode_unsigned(version, :little),
		  network: <<network :: binary>>, nonce: nonce,
      timestamp:  :binary.decode_unsigned(timestamp, :little),
      addr1:  addr1, addr2: addr2, user_agent: ua,
      last_block:  :binary.decode_unsigned(last_block, :little), relay: <<relay>>}
	end
	def decode_msg(C.msg_header(:verack, _, _, _)) do
		%{ command: :verack}
	end
	def decode_msg(C.msg_header(:inv, _, _, payload)) do
		inv_vector_decoding(:inv, payload)
	end
	def decode_msg(C.msg_header(:getdata, _, _, payload)) do
		inv_vector_decoding(:getdata, payload)
	end
	def decode_msg(C.msg_header(:notfound, _, _, payload)) do
		inv_vector_decoding(:notfound, payload)
	end
	def decode_msg(C.msg_header(:getblocks, _, _, payload)) do
		<<version :: binary - size(4), rest :: binary>> = payload
		{hash_count, _, b_hashes} = variable_length_integer(rest)
		b_cocator_bytes = hash_count * 32
		<< b_block_locators :: binary - size(b_cocator_bytes), hash_stop :: binary - size(32)>> = b_hashes
		block_locators = for  <<h :: binary - size(32) <- b_block_locators>>, do: h
	  %{command: :getblocks, version: :binary.decode_unsigned(version, :little), lst_blocklocator: block_locators,
			hashstop: hash_stop}
	end

	def encode_msg(m =%{:addr1 => {p3, p2, p1, p0}}) do
		encode_msg(%{m | :addr1 => << C.encpadl(C.node_network,8) :: binary,0 :: size(80), 255, 255, p3,p2,p1,p0,C.encpadb(C.port,2) :: binary>>})
	end
	def encode_msg(m =%{:addr2 => {p3, p2, p1, p0}}) do
		encode_msg(%{m | :addr2 => << C.encpadl(C.node_network,8) :: binary,0 :: size(80), 255, 255, p3,p2,p1,p0,C.encpadb(C.port,2) :: binary>>})
	end
	def encode_msg(%{:command => :version, :version => version, :network => network, :timestamp => timestamp,
									 :addr1 => addr1, :addr2 => addr2, :nonce => nonce, :user_agent =>  ua, :last_block => lb,
									 :relay => rl}) do
		{b_length, b_checksum} = length_and_checksum([C.encpadl(version, 4), network,C.encpadl(timestamp, 8),
																									addr1, addr2, nonce, string_to_variable_length(ua),
																									C.encpadl(lb, 4),rl])
		C.msg_header(:version,b_length, b_checksum,
								 C.version_payload(
									 C.encpadl(version, 4), network,C.encpadl(timestamp, 8),
									 addr1, addr2, nonce,
									 <<string_to_variable_length(ua) :: binary, C.encpadl(lb, 4) :: binary, rl ::binary >>))
	end
	def encode_msg(%{:command => :verack}) do
		{b_length, b_checksum} = length_and_checksum([<<>>])
		C.msg_header(:verack, b_length, b_checksum, <<>>)
	end
	def encode_msg(%{:command => :inv, :inv_vect => inv_vect}) do
		payload = inv_vector_encoding(inv_vect)
		{b_length, b_checksum} = length_and_checksum([payload])
		C.msg_header(:inv, b_length, b_checksum, payload)
	end
	def encode_msg(%{:command => :getdata, :inv_vect => inv_vect}) do
		payload = inv_vector_encoding(inv_vect)
		{b_length, b_checksum} = length_and_checksum([payload])
		C.msg_header(:getdata, b_length, b_checksum, payload)
	end
	def encode_msg(%{:command => :notfound, :inv_vect => inv_vect}) do
		payload = inv_vector_encoding(inv_vect)
		{b_length, b_checksum} = length_and_checksum([payload])
		C.msg_header(:notfound, b_length, b_checksum, payload)
	end
	def encode_msg(%{:command => :getblocks, :version => version, :lst_blocklocator => lst_block, :hashstop => hash_stop}) do
		payload = :erlang.list_to_binary([C.encpadl(version, 4), integer_to_variable_length(length(lst_block)),
																			lst_block, hash_stop])
		{b_length, b_checksum} = length_and_checksum([payload])
		C.msg_header(:getblocks, b_length, b_checksum, payload)
	end

	def length_and_checksum(lst) do
		payload = :erlang.list_to_binary(lst)
		payload_length = Nicotib.Utils.pad_to_x(:binary.encode_unsigned(byte_size(payload), :little), 4)
		<< payload_checksum :: binary - size(4), _ :: binary >> = :crypto.hash(:sha256, :crypto.hash(:sha256, payload))
		{payload_length,  payload_checksum}
	end


	def variable_length_string(b) do
		{n, h, t} = variable_length_integer(b)
		<< var_string :: binary - size(n), rest :: binary >> = t
		{h, var_string, rest}
	end
	def string_to_variable_length(s) when is_binary(s) do
    :erlang.list_to_binary([integer_to_variable_length(byte_size(s)), s])
	end
	def	string_to_variable_length(s) when is_list(s) do
    :erlang.list_to_binary([integer_to_variable_length(length(s)), s])
	end
			
	def variable_length_integer(<< f, rest :: binary >>) when f < 253 do
		{f, <<f>>, rest}
	end
	def variable_length_integer(<< f, rest :: binary >> ) do
		variable_length_integer(f, <<rest :: binary>>)
	end

	def variable_length_integer(253, << n :: binary - size(2), rest :: binary>>) do
		{:binary.decode_unsigned(n, :little), <<253, n :: binary>>, rest}
	end
	def variable_length_integer(254, << n :: binary - size(4), rest :: binary>>) do
		{:binary.decode_unsigned(n, :little), <<254, n :: binary>>, rest}
	end
	def variable_length_integer(255, << n :: binary - size(8), rest :: binary>>) do
		{:binary.decode_unsigned(n, :little), <<255, n :: binary>>, rest}
	end

	def integer_to_variable_length(i) when i<253 do
    <<i>>
	end
	def integer_to_variable_length(i) when i<65536 do
    b = C.encpadl(i, 2)
    <<253, b :: binary>>
	end
	def integer_to_variable_length(i) when i<4294967296 do
    b = C.encpadl(i, 4)
    <<254, b :: binary>>
	end
	def integer_to_variable_length(i) when i<18446744073709551616 do
    b = C.encpadl(i, 8)
    <<255, b :: binary>>
	end		
end
