defmodule Nicotib.Configuration do

	defmacro dns_seeds do
		['bitseed.xf2.org', 'dnsseed.bluematt.me', 'seed.bitcoin.sipa.be', 'dnsseed.bitcoin.dashjr.org', 'seed.bitcoinstats.com']
	end

	defmacro max_client_conn do
		100
	end

	defmacro port do
		8333
	end

	defmacro msg_header_length do
		24
	end

	defmacro msg_header(command, b_payload_length, payload_checksum, payload) do
		quote do
			<< 249,190,180,217, unquote(command) :: binary - size(12),
			unquote(b_payload_length) :: binary - size(4),
			unquote(payload_checksum) :: binary - size(4),
			unquote(payload) :: binary >>
		end
	end

	defmacro msg_version_header(b_payload_length, payload_checksum, version, network, timestamp, addr1, addr2, nonce, rest) do
		quote do 
			<< 249, 190, 180, 217 ,118,101,114,115,105,111,110,0,0,0,0,0,
			unquote(b_payload_length) :: binary - size(4),unquote(payload_checksum) :: binary - size(4),
			unquote(version) :: binary - size(4), unquote(network) :: binary - size(8), unquote(timestamp) :: binary - size(8),
			unquote(addr1) :: binary - size(26), unquote(addr2) :: binary - size(26), unquote(nonce) :: binary - size(8),
			unquote(rest) :: binary >>
		end
	end

	defmacro msg_verack_header(b_payload_length, payload_checksum) do
		quote do 
			<< 249, 190, 180, 217 , 118,101,114,97,99,107,0,0,0,0,0,0,
			unquote(b_payload_length) :: binary - size(4),unquote(payload_checksum) :: binary - size(4) >>
		end
	end

	defmacro msg_inv_header(b_payload_length, payload_checksum, payload) do
		quote do 
			<< 249, 190, 180, 217 , 118,101,114,97,99,107,0,0,0,0,0,0,
			unquote(b_payload_length) :: binary - size(4),unquote(payload_checksum) :: binary - size(4),
			unquote(payload) :: binary>>
		end
	end
	
	defmacro encpadl(type, size) do
		quote do
			Nicotib.Utils.pad_to_x(:binary.encode_unsigned(unquote(type), :little), unquote(size))
		end
	end

end
