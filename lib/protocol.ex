defmodule Nicotib.Protocol do
	require Nicotib.Configuration
	alias Nicotib.Configuration, as: C
	@doc ~S"""
	Provides access to and from bitcoin protocol binaries
"""

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
	defmacrop wrap_header(command, payload) do
		quote do
			{b_length, b_checksum} = length_and_checksum([unquote(payload)])
			C.msg_header(unquote(command), b_length, b_checksum, unquote(payload))
		end
	end
	defmacrop inv_vector_encoding(inv_vect) do
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
		{_, ua, <<last_block :: binary - size(4), relay :: binary>>} = variable_length_string(rest)
		%{command: :version, version: :binary.decode_unsigned(version, :little),
		  network: <<network :: binary>>, nonce: nonce,
      timestamp:  :binary.decode_unsigned(timestamp, :little),
      addr1:  addr1, addr2: addr2, user_agent: ua,
      last_block:  :binary.decode_unsigned(last_block, :little), relay: <<relay :: binary>>}
	end
	def decode_msg(C.msg_header(:verack, _, _, _)), do:		%{ command: :verack}
	def decode_msg(C.msg_header(:inv, _, _, payload)), do:	inv_vector_decoding(:inv, payload)
	def decode_msg(C.msg_header(:getdata, _, _, payload)), do:	inv_vector_decoding(:getdata, payload)
	def decode_msg(C.msg_header(:notfound, _, _, payload)), do:	inv_vector_decoding(:notfound, payload)
	def decode_msg(C.msg_header(:getblocks, _, _, payload)), do:	decode_getheaders_or_blocks(:getblocks, payload)
	def decode_msg(C.msg_header(:getheaders, _, _, payload)), do:	decode_getheaders_or_blocks(:getheaders, payload)
	#def decode_msg(C.msg_header(:tx, _, _, payload)), do: decode_tx(payload)
	#def decode_msg(C.msg_header(:block, _, _, payload)), do: decode_block(payload)
	def decode_msg(C.msg_header(:getaddr, _, _, _)), do:		%{ command: :getaddr}
	def decode_msg(C.msg_header(:ping, _, _, payload)), do:		%{ command: :ping, nonce: payload}
	def decode_msg(C.msg_header(:pong, _, _, payload)), do:		%{ command: :pong, nonce: payload}
	def decode_msg(C.msg_header(:mempool, _, _, <<>>)), do:		%{ command: :mempool}
	def decode_msg(C.msg_header(:reject, _, _, payload)) do
		{command_length, _, b_command} = variable_length_integer(payload)
		<<command :: binary - size(command_length), code :: binary - size(1), b_reason :: binary>> = b_command
		{reason_length, _, b_reason} = variable_length_integer(b_reason)
		<<reason :: binary - size(reason_length), extra :: binary>> = b_reason
		%{command: :reject, rejected_command: command, code: code, reason: reason, extra: extra}
	end
	def decode_msg(C.msg_header(:filterload, _, _, payload)) do
		filter = :binary.part(payload, 0, byte_size(payload) - 1 - 4 - 4)
		<<n_hash_funcs :: binary - size(4), n_tweak :: binary - size(4), n_flash :: binary - size(1) >> = :binary.part(payload, byte_size(payload), -9)
		%{command: :filterload, n_hash_funcs: :binary.decode_unsigned(n_hash_funcs, :little), n_tweak: :binary.decode_unsigned(n_tweak, :little),
		 filter: filter, n_flash: :binary.decode_unsigned(n_flash, :little)}
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
	def encode_msg(%{:command => :verack}), do: 		wrap_header(:verack, <<>>)
	def encode_msg(%{:command => :inv, :inv_vect => inv_vect}), do: wrap_header(:inv, inv_vector_encoding(inv_vect))
	def encode_msg(%{:command => :getdata, :inv_vect => inv_vect}), do: wrap_header(:getdata, inv_vector_encoding(inv_vect))
	def encode_msg(%{:command => :notfound, :inv_vect => inv_vect}), do: wrap_header(:notfound, inv_vector_encoding(inv_vect))
	def encode_msg(%{:command => :ping, :nonce => nonce}), do: wrap_header(:ping, nonce)
	def encode_msg(%{:command => :pong, :nonce => nonce}), do: wrap_header(:pong, nonce)
	def encode_msg(%{:command => :getaddr}), do: wrap_header(:getaddr, <<>>)
	def encode_msg(%{:command => :mempool}), do: wrap_header(:mempool, <<>>)
	def encode_msg(%{:command => :getblocks, :version => version, :lst_blocklocator => lst_block, :hashstop => hash_stop}) do
		payload = :erlang.list_to_binary([C.encpadl(version, 4), integer_to_variable_length(length(lst_block)),
																			lst_block, hash_stop])
		wrap_header(:getblocks, payload)
	end
	def encode_msg(%{:command => :getheaders, :version => version, :lst_blocklocator => lst_block, :hashstop => hash_stop}) do
		payload = :erlang.list_to_binary([C.encpadl(version, 4), integer_to_variable_length(length(lst_block)),
																			lst_block, hash_stop])
		wrap_header(:getheaders, payload)
	end
	#def encode_msg(%{:command => :reject, rejected_command: command, code: code, reason: reason, extra: extra})
	#def encode_msg(%{:command => :filterload,})
	#def encode_msg(%{:command => :tx,})
	#def encode_msg(%{:command => :block,})
	
	defp decode_getheaders_or_blocks(command, << version :: binary - size(4), rest :: binary >>) do
		{hash_count, _, b_hashes} = variable_length_integer(rest)
		b_cocator_bytes = hash_count * 32
		<< b_block_locators :: binary - size(b_cocator_bytes), hash_stop :: binary - size(32)>> = b_hashes
		block_locators = for  <<h :: binary - size(32) <- b_block_locators>>, do: h
	  %{command: command, version: :binary.decode_unsigned(version, :little), lst_blocklocator: block_locators,
			hashstop: hash_stop}		
	end
	def length_and_checksum(lst) do
		payload = :erlang.list_to_binary(lst)
		payload_length = Nicotib.Utils.pad_to_x(:binary.encode_unsigned(byte_size(payload), :little), 4)
		<< payload_checksum :: binary - size(4), _ :: binary >> = :crypto.hash(:sha256, :crypto.hash(:sha256, payload))
		{payload_length,  payload_checksum}
	end


	defp variable_length_string(b) do
		{n, h, t} = variable_length_integer(b)
		<< var_string :: binary - size(n), rest :: binary >> = t
		{h, var_string, rest}
	end
	defp string_to_variable_length(s) when is_binary(s) do
    :erlang.list_to_binary([integer_to_variable_length(byte_size(s)), s])
	end
	defp	string_to_variable_length(s) when is_list(s) do
    :erlang.list_to_binary([integer_to_variable_length(length(s)), s])
	end
			
	defp variable_length_integer(<< f, rest :: binary >>) when f < 253 do
		{f, <<f>>, rest}
	end
	defp variable_length_integer(<< f, rest :: binary >> ) do
		variable_length_integer(f, <<rest :: binary>>)
	end

	defp variable_length_integer(253, << n :: binary - size(2), rest :: binary>>) do
		{:binary.decode_unsigned(n, :little), <<253, n :: binary>>, rest}
	end
	defp variable_length_integer(254, << n :: binary - size(4), rest :: binary>>) do
		{:binary.decode_unsigned(n, :little), <<254, n :: binary>>, rest}
	end
	defp variable_length_integer(255, << n :: binary - size(8), rest :: binary>>) do
		{:binary.decode_unsigned(n, :little), <<255, n :: binary>>, rest}
	end

	defp integer_to_variable_length(i) when i<253 do
    <<i>>
	end
	defp integer_to_variable_length(i) when i<65536 do
    b = C.encpadl(i, 2)
    <<253, b :: binary>>
	end
	defp integer_to_variable_length(i) when i<4294967296 do
    b = C.encpadl(i, 4)
    <<254, b :: binary>>
	end
	defp integer_to_variable_length(i) when i<18446744073709551616 do
    b = C.encpadl(i, 8)
    <<255, b :: binary>>
	end		
end
