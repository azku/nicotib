defmodule Nicotib.Addresses do
	use GenServer
	require Nicotib.Configuration
	alias Nicotib.Configuration, as: C

	def start_link(storage_path) do
		GenServer.start_link(__MODULE__, storage_path, name: Addresses)
	end

	def	get_list_rnd_addr(not_in_list, max) do
		GenServer.call(Addresses, {:get_list_rnd_addr, max, not_in_list})
	end

	def add_addr(addr) do
		GenServer.cast(Addresses, {:add_addr, addr})
	end

	def update_connection_try(<< ip :: binary - size(16) >>) do
		GenServer.cast(Addresses, {:update_connection_try, ip})
	end

	def update_connection_success(<< ip :: binary - size(16) >>) do
		GenServer.cast(Addresses, {:update_connection_success, ip})
	end
	
	## Callbacks
	def init(storage_path) do
		tab = case :ets.file2tab(:filename.join([storage_path, "tabpeer"])) do
						{:ok, t} -> t
						_ ->
							t = :ets.new(:peer, [:set, :protected])
							Enum.each(C.dns_seeds,
								fn(host)->
									{:ok, {:hostent, _, _, _, 4, lst_ip4}} = :inet.gethostbyname(host)
									Enum.each(lst_ip4, fn({ip3, ip2, ip1, ip0})->
										:ets.insert(t, {<<0,0,0,0,0,0,0,0,0,0, 255, 255, ip3, ip2, ip1, ip0>>,
																		%{port: 8333, tryed: 0, succeeded: 0, timestamp: 0, times_seen: 1}})
									end)
								end)
							t
					end
		{:ok, %{:tab_peer => tab}}
	end

	def handle_call({:get_list_rnd_addr, max, not_in_list}, _from,  state = %{:tab_peer => t}) do
		rnd_key_from = Enum.reduce(1..:crypto.rand_uniform(1, :ets.info(t, :size) + 1 ), :ets.first(t),
			fn(_, :'$end_of_table')-> :ets.first(t) 
				(_, acc)-> :ets.next(t, acc)
			end)
		lst_addr = get_list_addr_from(t, rnd_key_from, Enum.min([max, :ets.info(t, :size) - length(not_in_list)]), not_in_list)
		{:reply, lst_addr, state}
	end

	def handle_call(_, _from, state) do
		{:reply, :ok, state}
	end

	def handle_cast({:add_addr, %{:ip => ip, :port => port, :timestamp => timestamp}}, state = %{:tab_peer => t}) do
		
		case :ets.lookup(t, ip) do
			[] ->
				new_map = %{:port => port, :timestamp => timestamp, :tryed => 0, :succeed => 0, :times_seen => 1}
				:ets.insert(t, {ip, new_map})
			[{_, old_map = %{:timestamp => old_time_stamp, :times_seen => times_seen}}] when old_time_stamp < timestamp ->
				new_map = %{:port => port, :timestamp => timestamp, :times_seen => times_seen + 1}
				:ets.insert(t, {ip, :maps.merge(old_map, new_map)})
			[{_, old_map = %{:times_seen => times_seen}}] ->
				new_map = Dict.put_new(old_map, :times_seen, times_seen + 1)
				:ets.insert(t, {ip, new_map})
		end
		{:noreply, state}
	end

	def handle_cast({:update_connection_try, ip}, state = %{:tab_peer => t}) do
    [{_, old_map = %{:tryed => tryed}}] = :ets.lookup(t, ip)
    :ets.insert(t, {ip, :maps.merge(old_map, %{:tryed => tryed + 1})})
		{:noreply, state}		
	end

	def handle_cast({:update_connection_success, ip}, state = %{:tab_peer => t}) do
		[{_, old_map = %{:succeeded => succeeded}}] = :ets.lookup(t, ip)
    :ets.insert(t, {ip, :maps.merge(old_map, %{:succeeded => succeeded + 1})})
		{:noreply, state}		
	end
	
	def handle_cast(_, state) do
		{:noreply, state}
	end

	def get_list_addr_from(t, k, n, not_in_list) do
		get_list_addr_from(t, k, n, not_in_list, [])
	end

	def get_list_addr_from(_t, _k, 0, _not_in_list, l) do
		Enum.reverse(l)
	end
	
	def get_list_addr_from(t, :'$end_of_table', n, not_in_list, l) do
		get_list_addr_from(t, :ets.first(t), n, not_in_list, l)
	end

	def get_list_addr_from(t, k, n, not_in_list, l) do
		if Enum.member?(not_in_list, k) do
			get_list_addr_from(t, :ets.next(t, k), n, not_in_list, l)
		else
			get_list_addr_from(t, :ets.next(t, k), n - 1, not_in_list, [k | l])
		end
	end	
end
