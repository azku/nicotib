defmodule Nicotib.Protocol do
	require Nicotib.Configuration
	alias Nicotib.Configuration, as: C

	def check_message_validity(C.msg_header(_, _, pl_checksum, pl)) do
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

	def decode_msg(C.msg_version_header(_, _, version, network, timestamp, addr1, addr2, nonce, rest)) do
		{_, ua, <<last_block :: binary - size(4), relay>>} = variable_length_string(rest)
		%{command: :version, version: :binary.decode_unsigned(version, :little),
		  network: <<network :: binary>>, nonce: nonce,
      timestamp:  :binary.decode_unsigned(timestamp, :little),
      addr1:  addr1, addr2: addr2, user_agent: ua,
      last_block:  :binary.decode_unsigned(last_block, :little), relay: relay}
	end
	def decode_msg(C.msg_verack_header(_, _)) do
		%{ command: :verack}
	end

	def encode_msg(%{:command => :version, :version => version, :network => network, :timestamp => timestamp,
									 :addr1 => addr1, :addr2 => addr2, :nonce => nonce, :user_agent =>  ua, :last_block => lb,
									 :relay => rl}) do
		{b_length, b_checksum} = length_and_checksum([C.encpadl(version, 4), network,C.encpadl(timestamp, 8),
																									addr1, addr2, nonce, string_to_variable_length(ua),
																									C.encpadl(lb, 4),rl])
		C.msg_version_header(b_length, b_checksum,
												 C.encpadl(version, 4), network,C.encpadl(timestamp, 8),
												 addr1, addr2, nonce,
												 <<string_to_variable_length(ua) :: binary, C.encpadl(lb, 4) :: binary, rl ::binary >>)
	end
	def encode_msg(%{:command => :verack}) do
		{b_length, b_checksum} = length_and_checksum([<<>>])
		C.msg_verack_header(b_length, b_checksum)
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
    :erlang.list_to_binary([integer_to_variable_length(:erlang.byte_size(s)), s])
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
