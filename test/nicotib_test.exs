defmodule NicotibTest do
  use ExUnit.Case


	test "pad_to_x padding binaries to bitsize x" do
		assert Nicotib.Utils.pad_to_x(<<1>>, 5) == <<1, 0, 0, 0, 0>>
		assert catch_error(Nicotib.Utils.pad_to_x(<<1>>, -5))
	end

	test "bitcoin_add_to_ip_adderss IPV4 and IPV6" do
		assert Nicotib.Utils.bitcoin_addr_to_ip_address(<<0,0,0,0,0,0,0,0,0,0,255,255,192,168,1,1>>) == {192,168,1,1}
		assert Nicotib.Utils.bitcoin_addr_to_ip_address(<<1,2,5,6,7,8,9,0,2,45,25,99,192,168,67,98>>) == {258, 1286, 1800, 2304, 557, 6499, 49320, 17250}
	end

	test "bin_to_hex binary to hexadecimal convertion" do
		assert Nicotib.Utils.bin_to_hex(<<1,2,3,10>>) == '0102030A'
		assert Nicotib.Utils.bin_to_hex(<<255,255,255,255>>) == 'FFFFFFFF'
	end

	test "hex_to_bin hexadecimal to bunary convertion" do
		assert Nicotib.Utils.hex_to_bin('0102030A') == <<1,2,3,10>>
		assert Nicotib.Utils.hex_to_bin('FFFFFFFF') == <<255,255,255,255>>
	end

	test "check_mmessage_validity for blockchain messages" do
		assert Nicotib.Protocol.check_message_validity( <<249,190,180,217,118,101,114,115,105,111,110,0,0,0,0,0,101,0,
			0,0,186,233,140,168,114,17,1,0,1,0,0,0,0,0,0,0,13,222,84,83,
			0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,0,0,0,0,
			0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,79,154,134,
			142,32,141,118,220,131,138,44,30,217,249,15,47,83,97,116,111,
			115,104,105,58,48,46,57,46,49,47,29,43,2,0,1>>) == true
				assert Nicotib.Protocol.check_message_validity( <<249,190,180,217,118,101,114,115,105,111,110,0,0,0,0,0,101,0,
			0,0,186,233,140,168,114,17,1,0,1,0,0,0,0,0,0,0,13,222,84,83,
			0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,0,0,0,0,
			0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,79,154,134,
			142,32,141,118,220,131,138,44,30,217,248,15,47,83,97,116,111,
			115,104,105,58,48,46,57,46,49,47,29,43,2,0,1>>) == false
	end

	test "Test key generation" do
		{address, priv} = Nicotib.Protocol.generate_key_pair()
		assert byte_size(address) == 34
	end

	test "Test version decoding" do
		assert %{addr1: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 0, 0, 0, 0, 0, 0>>,
             addr2: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 79, 154, 134, 142, 32, 141>>,
             command: :version, last_block: 142109,
             network: <<1, 0, 0, 0, 0, 0, 0, 0>>,
             nonce: <<118, 220, 131, 138, 44, 30, 217, 249>>, relay: 1,
             timestamp: 1398070797, user_agent: "/Satoshi:0.9.1/",
             version: 70002} ==
			Nicotib.Protocol.decode_msg(<<249,190,180,217,118,101,114,115,105,111,110,0,0,0,0,0,101,0,
																	0,0,186,233,140,168,114,17,1,0,1,0,0,0,0,0,0,0,13,222,84,83,
																	0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,0,0,0,0,
																	0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,79,154,134,
																	142,32,141,118,220,131,138,44,30,217,249,15,47,83,97,116,111,
																	115,104,105,58,48,46,57,46,49,47,29,43,2,0,1>>)
		m = <<249,190,180,217,118,101,114,115,105,111,110,0,0,0,0,0,101,0,
		0,0,186,233,140,168,114,17,1,0,1,0,0,0,0,0,0,0,13,222,84,83,
		0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,0,0,0,0,
		0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,255,255,79,154,134,
		142,32,141,118,220,131,138,44,30,217,249,15,47,83,97,116,111,
		115,104,105,58,48,46,57,46,49,47,29,43,2,0,1>>
		assert m ==Nicotib.Protocol.encode_msg(Nicotib.Protocol.decode_msg(m))
	end
	test "verack decoding" do
		assert %{command: :verack} == Nicotib.Protocol.decode_msg(<<249,190,180,217,118,101,114,97,99,107,0,0,0,0,0,0,1,2,3,4,1,2,3,4>>)
	end
	test "inv decoding" do
		assert %{command: :inv, inv_vect: []} == Nicotib.Protocol.decode_msg(<< 249,190,180,217,105,110,118,0,0,0,0,0,0,0,0,0,1,2,3,4,1,2,3,4,0>>)
	end
	test "getdata decoding" do
		assert %{command: :getdata, inv_vect: []} == Nicotib.Protocol.decode_msg(<< 249,190,180,217,103,101,116,100,97,116,97,0,0,0,0,0,1,2,3,4,1,2,3,4,0>>)
	end
end
