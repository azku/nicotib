defmodule Nicotib.NetworkPpool do
	use GenServer
	require Nicotib.Configuration
	alias Nicotib.Configuration, as: C
	require Logger

	def start_link([callback_mod, address_mod]) do
		GenServer.start_link(__MODULE__, [callback_mod, address_mod], [timeout: :infinity, name: :network_ppool])
	end

	def open_new_client_con(n_con, f_handshake) do
		GenServer.cast(:network_ppool, {:open_new_client_con, n_con, f_handshake})
	end

	def count_open_connections do
		GenServer.call(:network_ppool, :count_open_connections)
	end

	def start_server(port) do
		GenServer.cast(:network_ppool, {:start_server, port})
	end

	def send_msg_client(msg) do
		GenServer.cast(:network_ppool, {:send_msg_client, msg})
	end

	def broadcast_msg(msg) do
		GenServer.cast(:network_ppool, {:broadcast_msg, msg})
	end

	def stopping do
		GenServer.call(:network_ppool, :stopping)
	end

	def get_and_store_nonce do
		GenServer.call(:network_ppool, :get_and_store_nonce)
	end

	def is_nonce_used(nonce) do
		GenServer.call(:network_ppool, {:is_nonce_used, nonce})
	end

	## Callbacks
	def init([callback_mod, address_mod]) do
		{:ok, %{client_lst: [], server_lst: [], callback_mod: callback_mod, used_nonces: HashDict.new(),
		address_mod: address_mod, state: :started, f_handshake: :none}}
	end

	def handle_call(:count_open_connections, _, state = %{:client_lst => c_lst}) do
		{:reply, length(c_lst), state}
	end
	def handle_call(:stopping, _, state) do
		{:reply, :ok, %{state | :state => :closing}}
	end
	def handle_call(:get_and_store_nonce, _, state = %{:used_nonces => dict}) do
		rnd = :crypto.rand_bytes(8)
		{:reply, rnd, %{state | :used_nonces => Dict.put(dict, rnd, [])}}
	end
	def handle_call({:is_nonce_used, nonce}, _, state = %{:used_nonces => dict}) do
		{:reply, Dict.has_key(dict, nonce), state}
	end

	def handle_cast({:open_new_client_con, _, _}, state = %{:client_lst => c_lst}) when length(c_lst)> C.max_client_conn do
		{:noreply, state}
	end
	def handle_cast({:open_new_client_con, n_con, f_handshake}, state = %{:client_lst => c_lst, :callback_mod => callback_mod,
																																				:used_nonces => dict, :address_mod => address_mod}) do

		rnd = :crypto.rand_bytes(8)
 		cl = (for {_, a_bip} <- c_lst, do: a_bip)
		|> address_mod.get_list_rnd_addr(Enum.min([C.max_client_conn - length(c_lst), n_con]))
		|> Enum.map(fn(bipv6)->
			ip = Nicotib.Utils.bitcoin_addr_to_ip_address(bipv6)
			address_mod.update_connection_try(bipv6)
			{:ok, pid} = Supervisor.start_child(Nicotib.NetworkClientSupervisor, [[ip, C.port, callback_mod, address_mod]])
			f_handshake.(pid, bipv6, rnd)
			Process.monitor(pid)
			{pid, bipv6}
		end)

		{:noreply, %{state | :client_lst => cl ++ c_lst, :f_handshake => f_handshake, :used_nonces => Dict.put(dict, rnd, [])}}
		
	end
	def handle_cast({:start_server, port}, state = %{:server_lst => s_lst, :callback_mod => callback_mod, :address_mod => address_mod}) do
		{:ok, pid} = :ranch.start_listener(:nicotib_ranch_server, 5, :ranch_tcp, [{:port, port}],
																			 Nicotib.NetworkSocServer, [callback_mod, address_mod])
		{:noreply, %{state | :server_lst => [pid | s_lst]}}
	end
	
	def handle_info(_, state = %{:state => :closing}) do
		##Catch all messages when closing
		{:noreply, state}
	end
	def handle_info({:DOWN, _, :process, pid, _}, state = %{:client_lst => c_lst, :f_handshake => f_handshake}) do
		open_new_client_con(1, f_handshake)
		{:noreply, %{state | :client_lst => List.keydelete(c_lst, pid, 1)} }
	end
	def handle_info(_msg, state) do
		{:noreply, state}
	end
end
