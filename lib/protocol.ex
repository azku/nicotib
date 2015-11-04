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
    Base58.encode(<<v_byte :: binary, ripem160 :: binary, c1, c2, c3, c4>>)
	end
	
	def script_pub_key_to_address(script_pubKey) do
    v_byte = Nicotib.Utils.hex_to_bin('00')
    ex_sha256 = :crypto.hash(:sha256, << v_byte :: binary, script_pubKey :: binary>>)
    << c1, c2, c3, c4, _ :: binary >> = :crypto.hash(:sha256, ex_sha256)
    Base58.encode(<< v_byte :: binary, script_pubKey :: binary, c1, c2, c3, c4>>)
	end

	def private_to_wif(k) when is_binary(k) do
    prefix = Nicotib.Utils.hex_to_bin('80')
    hash = :crypto.hash(:sha256, << prefix :: binary, k :: binary>>)
    <<c1,c2,c3,c4, _ :: binary>> = :crypto.hash(:sha256, hash)
    Base58.encode(<< prefix :: binary, k :: binary, c1,c2,c3,c4>>)
	end
end
