defmodule Nicotib.NetworkSocServer do
	use GenServer, Behaviour
	require Logger

	@callback handle_version(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_verack(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_inv(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_ping(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_addr(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_getaddr(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_getheaders(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_headers(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_reject(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_getdata(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_notfound(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_tx(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_block(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_getblocks(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_mempool(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	@callback handle_filterload(msg :: binary, state :: map, socket :: any, transport :: any) :: map
	

	def start_link([ip, port, callback_mod, address_mod]) do
		GenServer.start_link(__MODULE__, [ip, port, callback_mod, address_mod], [timeout: :infinity])
	end

	def start_link(ref, socket, transport, opts) do
		:proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
	end

	def send_msg(pid, msg) do
		GenServer.cast(pid, {:send_msg, msg})
	end

	## Callbacks
	def init([ip, port, callback_mod, address_mod]) do
		send(self(), {:start_client_soc_server, ip, port})
		{:ok, %{socket: [], callback_mod: callback_mod, transport: :gen_tcp, stream: <<>>, address_mod: address_mod}}
	end

	def init(ref, socket, transport, [callback_mod, address_mod]) do
		:proc_lib.init_ack({:ok, self()})
		:ranch.accept_ack(ref)
		transport.setopts(socket, [{:active, :once}])
		GenServer.enter_loop(__MODULE__, [], %{socket: socket, callback_mod: callback_mod, transport: transport,
																				 stream: <<>>, address_mod: address_mod})
	end

	def handle_call(_, _, state) do
		{:reply, :nothing_programmed, state}
	end

	def handle_cast({:send_msg, msg}, state = %{:socket => socket, :transport => t}) do
		t.send(socket, msg)
		{:noreply, state}
	end

	def handle_info({:start_client_soc_server, ip, port}, state) do
		case :gen_tcp.connect(ip, port, [:binary, {:active, false}, {:keepalive, true}], 1000) do
			{:ok, socket} ->
				:inet.setopts(socket, [{:active, :once}])
				{:noreply, %{state | :socket => socket}}
			{:error, _} -> {:stop, :normal, state}
		end
	end

	def handle_info({:tcp, socket, new_stream}, state = %{:stream => stream}) do
		result = consume_stream(<< stream :: binary, new_stream :: binary>>, state)
		case :inet.setopts(socket, [{:active, :once}]) do
			:ok -> result
			{:error, _} -> {:stop, :normal, state}
		end
	end

	def handle_info({:tcp_closed, _}, state) do
		{:stop, :normal, state}
	end

	def handle_info({:tcp_error, _, _ }, state) do
		{:stop, :normal, state}
	end

	def handle_info(:timeout, state) do
		{:stop, :normal, state}
	end

	def terminate(_, %{:socket => []}) do
		:ok
	end

	def terminate(_, %{:socket => socket}) do
		:gen_tcp.close(socket)
		:ok
	end

	def consume_stream(_m, state) do
		Logger.debug "consuming stream"
		{:noreply, state}
	end
end
