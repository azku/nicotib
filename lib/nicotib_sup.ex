defmodule Nicotib.Supervisor do
	use Supervisor

	def start_link do
		Supervisor.start_link(__MODULE__, :ok, [name: Nicotib.Supervisor])
	end

	def init(:ok) do
		children = []
		supervise(children, strategy: :one_for_one)
	end
end

defmodule Nicotib.NetworkSupervisor do
	use Supervisor

	def start_link(callback_mod, address_mod) do
		Supervisor.start_link(__MODULE__, [callback_mod, address_mod], [name: Nicotib.NetworkSupervisor])
	end

	def init([callback_mod, address_mod]) do
		children = [supervisor(Nicotib.NetworkClientSupervisor, []),
								worker(Nicotib.NetworkPpool, [[callback_mod, address_mod]])]
		supervise(children, strategy: :one_for_one)
	end
end

defmodule Nicotib.NetworkClientSupervisor do
	use Supervisor

	def start_link do
		Supervisor.start_link(__MODULE__, [], [name: Nicotib.NetworkClientSupervisor])
	end

	def init([]) do
		children = [worker(Nicotib.NetworkSocServer, [], [restart: :temporary, shutdown: :infinity])]
		supervise(children, strategy: :simple_one_for_one)
	end
end
