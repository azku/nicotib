Nicotib
=======

Nicotib is an application written in Elixir which aims to provide
a medium to interact with the block chain and the bitcoin network.

By providing a plugable callback system, any type of client/server
can be implemented on top off it.

Essentially it aims not to provide a specific implementation of client/server
but to allow the community to play with any usage the block chain and the
network might provide.

Getting started
---------------

Nicotib it's aimed at providing an OTP base for the interaction
with the block chain. In this regard, it will most likely be
used as a dependency inside another application.

How can I use nicotib from my project?

Just add the dependency to nicotib and then call:

     nicotib:start_btc_interaction(CallbackModule, DataStoragePath)

CallbackModule is the module to which nicotib will delegate
all the received messages after validating and decoding them.

The data storage path is used to store the peer address lists.
In order to bootstrap to the network, the addresses of the peers
have to be found and maintained. Nicotib takes care of this so
you can concentrate on playing with the messages.


Support
-------
 * Check out the [documentation](http://zebixe.com/nicotib).
 * Email to asier@zebixe.com