defmodule Nicotib.NetworkSocServer do
	use GenServer, Behaviour
	require Logger
	require Nicotib.Configuration
	alias Nicotib.Configuration, as: C

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
		{:ok, %{socket: [], callback_mod: callback_mod, transport: :gen_tcp, stream: <<>>, address_mod: address_mod, listener: false}}
	end

	def init(ref, socket, transport, [callback_mod, address_mod]) do
		:proc_lib.init_ack({:ok, self()})
		:ranch.accept_ack(ref)
		transport.setopts(socket, [{:active, :once}])
		GenServer.enter_loop(__MODULE__, [], %{socket: socket, callback_mod: callback_mod, transport: transport,
																				 stream: <<>>, address_mod: address_mod, listener: true})
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
	def terminate(_, _) do
		:ok
	end

	def consume_stream(m = C.msg_header(_, b_payload_length, _, payload) , state) do
		payload_length = :binary.decode_unsigned(b_payload_length, :little)
		case (byte_size(payload) - payload_length) do
			0 -> {:noreply, handle_message(m, %{ state | :stream => <<>>}), 60 * 1000 * 2}
			i when i > 0 ->
				handle_message(:binary.part(m, {0, C.msg_header_length + payload_length}), state)
				consume_stream(:binary.part(m, {C.msg_header_length + payload_length, byte_size(m) - (C.msg_header_length + payload_length)}), state)
			_ -> ##Not enough bytes
			{:noreply, %{ state | :stream => m}, 60 * 1000 * 2}
		end
	end
	def consume_stream(<<_, rest :: binary>>, state) do
		consume_stream(rest, state)
	end
	def consume_stream(<<>>, state) do
		{:noreply, %{ state | :stream => <<>>}, 1000*60*2}
	end

	def handle_message(msg, state = %{:socket => socket}) do
		if Nicotib.Protocol.check_message_validity(msg) do
			fm(Nicotib.Protocol.decode_msg(msg), state, socket)
		else
			##todo
			Logger.error "Payload  checksum invalid. Message should be rejected"
			state
		end
	end

	def fm(decoded_msg = %{:command => :version}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_version(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :verack}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_verack(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :inv}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_inv(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :ping}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_ping(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :addr}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_addr(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :getaddr}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_getaddr(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :getheaders}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_getheaders(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :headers}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_headers(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :reject}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_reject(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :getdata}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_getdata(decoded_msg, state, socket, t)
	end

	def fm(decoded_msg = %{:command => :notfound}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_notfound(decoded_msg, state, socket, t)
	end

	def fm(decoded_msg = %{:command => :block}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_block(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :tx}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_tx(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :getblocks}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_getblocks(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :mempool}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_mempool(decoded_msg, state, socket, t)
	end
	def fm(decoded_msg = %{:command => :filterload}, state = %{:transport => t, :callback_mod => m}, socket) do
		m.handle_filterload(decoded_msg, state, socket, t)
	end
	
end
