defmodule Nicotib.Configuration do

	defmacro dns_seeds do
		['bitseed.xf2.org', 'dnsseed.bluematt.me', 'seed.bitcoin.sipa.be', 'dnsseed.bitcoin.dashjr.org', 'seed.bitcoinstats.com']
	end
	defmacro max_client_conn, do: 100
	defmacro node_network, do: 1
	defmacro port, do: 8333
	defmacro msg_header_length, do:	24
	defmacro command(:version), do: << 118,101,114,115,105,111,110,0,0,0,0,0 >>
	defmacro command(:verack), do: << 118,101,114,97,99,107,0,0,0,0,0,0 >>
	defmacro command(:addr), do: << 97,100,100,114,0,0,0,0,0,0,0,0 >>
	defmacro command(:inv), do: << 105,110,118,0,0,0,0,0,0,0,0,0 >>
	defmacro command(:getdata), do: << 103,101,116,100,97,116,97,0,0,0,0,0 >>
	defmacro command(:getblocks), do: << 103,101,116,98,108,111,99,107,115,0,0,0 >>
	defmacro command(:getheaders), do: << 103,101,116,104,101,97,100,101,114,115,0,0 >>
	defmacro command(:headers), do: << 104,101,97,100, 101,114,115,0,0,0,0,0 >>
	defmacro command(:block), do: << 98,108,111,99,107,0,0,0,0,0,0,0 >>
	defmacro command(:ping), do: << 112,105,110,103,0,0,0,0,0,0,0,0 >>
	defmacro command(:pong), do: << 112,111,110,103,0,0,0,0,0,0,0,0 >>
	defmacro command(:tx), do: << 116,120,0,0,0,0,0,0,0,0,0,0 >>
	defmacro command(:getaddr), do: << 103,101,116,97,100,100,114,0,0,0,0,0 >>
	defmacro command(:reject), do: << 114,101,106,101,99,116,0,0,0,0,0,0 >>
	defmacro command(:notfound), do: << 110,111,116,102,111,117,110,100,0,0,0,0 >>
	defmacro command(:filterload), do: << 102,105,108,116,101,114,108,111,97,100,0,0 >>
	defmacro command(:mempool), do: << 109,101,109,112,111,111,108,0,0,0,0,0 >>
	
	defmacro msg_header(b_payload_length, payload_checksum,  payload) do
		quote do 
			<< 249, 190, 180, 217, _ :: binary - size(12) ,	unquote(b_payload_length) :: binary - size(4),
			unquote(payload_checksum)  :: binary - size(4),	unquote(payload) :: binary>>
		end
	end
	defmacro msg_header(command, b_payload_length, payload_checksum, payload) do
		quote do 
			<< 249, 190, 180, 217, Nicotib.Configuration.command(unquote(command)) ,
			unquote(b_payload_length) :: binary - size(4),unquote(payload_checksum) :: binary - size(4),
			unquote(payload) :: binary>>
		end
	end

	defmacro version_payload(version, network, timestamp, addr1, addr2, nonce, rest) do
		quote do
			<< unquote(version) :: binary - size(4), unquote(network) :: binary - size(8), unquote(timestamp) :: binary - size(8),
			unquote(addr1) :: binary - size(26), unquote(addr2) :: binary - size(26), unquote(nonce) :: binary - size(8),
			unquote(rest) :: binary >>
		end
	end
	
	defmacro encpadl(type, size) do
		quote do
			Nicotib.Utils.pad_to_x(:binary.encode_unsigned(unquote(type), :little), unquote(size))
		end
	end
	defmacro encpadb(type, size) do
		quote do
			Nicotib.Utils.pad_to_x(:binary.encode_unsigned(unquote(type), :big), unquote(size))
		end
	end


end
