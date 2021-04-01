#!/usr/bin/env ruby

require 'socket' # Provides TCPServer and TCPSocket classes

# Initialize a TCPServer object that will listen
# on localhost:2345 for incoming connections.
server = TCPServer.new('0.0.0.0', 2345)

file = File.open("app/LFS.img", "r")

# loop infinitely, processing one incoming
# connection at a time.
loop do

  # Wait until a client connects, then return a TCPSocket
  # that can be used in a similar fashion to other Ruby
  # I/O objects. (In fact, TCPSocket is a subclass of IO.)
  socket = server.accept

  STDERR.puts "new connection"

  file.seek(0)

  # Read the first line of the request (the Request-Line)
  request = socket.gets

  # Log the request to the console for debugging
  STDERR.puts request

  # We need to include the Content-Type and Content-Length headers
  # to let the client know the size and type of data
  # contained in the response. Note that HTTP is whitespace
  # sensitive, and expects each header line to end with CRLF (i.e. "\r\n")
  socket.write "HTTP/1.1 200 OK\r\n" +
               "Content-Type: text/plain\r\n" +
               "Content-Length: #{file.size}\r\n" +
               "Connection: close\r\n\r\n"

  loop do
    line = file.read(1024)
    break if line.nil?
    socket.write(line)
  end

  # Close the socket, terminating the connection
  socket.flush
  socket.close
end
