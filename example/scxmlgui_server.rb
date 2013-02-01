require 'sinatra'
require 'socket'
require_relative '../lib/rxsc'

sc = RXSC.Machine(IO.read('dashboard.scxml'))
events = sc.events.sort
puts events

__END__
server = TCPServer.open(2000)  # Socket to listen on port 2000
loop {                         # Servers run forever
  client = server.accept       # Wait for a client to connect
  client.puts(Time.now.ctime)  # Send the time to the client
  client.puts "Closing the connection. Bye!"
  client.close                 # Disconnect from the client
}