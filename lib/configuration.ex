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

	defmacro msg_header(command, b_payload_length, payload_checksum, payload) do
		quote do
			<< 249,190,180,217, unquote(command) :: binary - size(12),
			unquote(b_payload_length) :: binary - size(4),
			unquote(payload_checksum) :: binary - size(4),
			unquote(payload) :: binary >>
		end
	end
end
