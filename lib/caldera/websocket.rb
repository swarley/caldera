# frozen_string_literal: true

require 'websocket/driver'
require 'permessage_deflate'
require 'socket'
require 'uri'
require 'logging'
require 'event_emitter'
require 'json'

module Caldera
  class WebSocket
    include EventEmitter

    attr_reader :thread, :uri

    LOGGER = Logging.logger[self]

    # Create a WebSocket that connects to the Lavalink server.
    # @param [URI, String] uri The URI to connect with. (ex: `"ws://localhost:8080"`)
    # @param [String] authorization Password matching the server config.
    # @param [Integer] num_shards Total number of shards your bot is operating on.
    # @param [String, Integer] user_id The user ID of the bot you are playing music with.
    # @caldera.lavalink_docs https://github.com/Frederikam/Lavalink/blob/master/IMPLEMENTATION.md#opening-a-connection
    def initialize(uri, authorization, num_shards, user_id)
      @uri = uri.is_a?(URI::Generic) ? uri : URI.parse(uri)
      @uri.scheme = 'ws'

      create_driver
      set_headers(authorization, num_shards, user_id)
      register_handlers
    end

    # Start the connection to the Lavalink server.
    def start
      LOGGER.info { "Opening connection to #{url}" }
      @tcp  = TCPSocket.new(@uri.host || localhost, @uri.port)
      @dead = false
      create_thread

      @driver.start
      LOGGER.info { 'Driver started' }
    end

    # Encode a hash to json, and send it over the websocket.
    # @param [Hash] message
    def send_json(message)
      LOGGER.debug { "Sending message: #{message.inspect}" }
      @driver.text(JSON.dump(message))
    end

    # Write data to the socket
    # @param [String] data
    def write(data)
      @tcp.write(data)
    end

    # Send a close frame
    # @param [String] message The close reason
    # @param [Integer] code The close code
    def close(message: nil, code: 1000)
      LOGGER.debug { "Sending close: (#{message.inspect}, #{code})" }
      @driver.close(reason, code)
    end

    def url
      @uri.to_s
    end

    private

    # Construct a WebSocket::Driver instance.
    def create_driver
      @driver = ::WebSocket::Driver.client(self)
      @driver.add_extension(PermessageDeflate)
    end

    # Set the relevant headers for opening a connection.
    # @param [String] authorization
    # @param [Integer] num_shards
    # @param [Integer, String] user_id
    # @caldera.lavalink_docs [Opening a connection](https://github.com/Frederikam/Lavalink/blob/master/IMPLEMENTATION.md#opening-a-connection)
    def set_headers(authorization, num_shards, user_id)
      LOGGER.debug { 'Setting connection headers' }
      @driver.set_header('Authorization', authorization)
      @driver.set_header('Num-Shards', num_shards)
      @driver.set_header('User-Id', user_id)
    end

    # Register event handlers on the driver.
    def register_handlers
      LOGGER.debug { 'Registering driver handlers' }
      @driver.on(:open, &method(:handle_open))
      @driver.on(:message, &method(:handle_message))
      @driver.on(:close, &method(:handle_close))
    end

    # Begin the thread that feeds messages to the driver.
    def create_thread
      LOGGER.debug { 'Creating read thread' }
      @thread = Thread.new do
        @driver.parse(read_data) until @dead
        LOGGER.debug { 'Read loop ending' }
      end
    end

    # Fired when the WS handshake has finished
    def handle_open(_event)
      LOGGER.info('WebSocket connected')
      emit(:open)
    end

    # Fired when a message frame has been received
    def handle_message(event)
      LOGGER.info("Received message: #{event.data.inspect}")
      parsed = JSON.parse(event.data)
      emit(parsed['op'], parsed)
    end

    # Fired when the WS connection has sent a close frame.
    def handle_close(event)
      LOGGER.warn { "Received a close frame: (#{event.reason}, #{event.code})" }
      @dead = true
      @thread.kill
      emit(:close, { reason: event.reason, code: event.code })
    end

    # Read data from the TCP socket.
    # @param [Integer] length The maximum length to read at once.
    def read_data(length = 4096)
      @tcp.readpartial(length)
    end
  end
end
