defmodule Nicotib do
	use Application
	
	def start(__type, __args) do
		Nicotib.Supervisor.start_link
	end

	def start_btc_interaction(network_callback, storage_path) do
		{:ok, [[_home_path]]} = :init.get_argument(:home)

		:ok = :filelib.ensure_dir(storage_path)
    :file.make_dir(storage_path)
		Supervisor.start_child(Nicotib.Supervisor, Supervisor.Spec.worker(Nicotib.Addresses, [storage_path]))
		Supervisor.start_child(Nicotib.Supervisor, Supervisor.Spec.supervisor(Nicotib.NetworkSupervisor, [Nicotib.NetworkCallback, Nicotib.Addresses]))
	end
end
