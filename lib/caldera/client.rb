# frozen_string_literal: true

require 'caldera/node'
require 'logging'
require 'timeout'

module Caldera
  class Client
    LOGGER = Logging.logger[self]

    # @return [String]
    attr_reader :num_shards

    # @return [String]
    attr_reader :user_id

    # @return [Array<Player>]
    attr_reader :players

    # @return [Array<Node>]
    attr_reader :nodes

    # @param [Integer, String] num_shards
    # @param [Integer, String] user_id
    # @param [Proc<String, String>] connect
    def initialize(num_shards:, user_id:, connect: nil)
      @num_shards = num_shards.to_s
      @user_id = user_id.to_s
      @players = {}
      @connect_proc = connect
      @nodes = []
      @voice_state_mutex = Mutex.new
      @voice_states = Hash.new { |h, guild_id| h[guild_id] = {} }
    end

    # @param [Integer, String] guild_id
    # @param [Integer, String] channel_id
    # @param [Number] timeout
    # @return [Caldera::Player]
    def connect(guild_id, channel_id, timeout: nil)
      return Timeout.timeout(timeout) { connect(guild_id, channel_id) } if timeout

      gid = guild_id.to_s

      return @players[gid] if @players[gid]

      @connect_proc.call(gid, channel_id.to_s)
      sleep 0.05 until @players[gid]

      @players[gid]
    end

    def update_voice_state(guild_id, session_id: nil, event: nil)
      guild_id = guild_id.to_s
      @voice_state_mutex.synchronize do
        @voice_states[guild_id][:session_id] = session_id if session_id
        @voice_states[guild_id][:event] = event if event
      end

      state = @voice_states[guild_id]

      if state[:session_id] && state[:event]
        LOGGER.info { "Creating player for #{guild_id}" }
        best_node.create_player(guild_id, state[:session_id], state[:event])
        @voice_states.delete(guild_id)
      else
        LOGGER.debug { "Recieved partial info for creating player for #{guild_id}: #{state}" }
      end
    end

    def add_node(authorization:, uri: nil, rest_uri: nil, ws_uri: nil)
      uri = URI(uri) unless uri.is_a?(URI::Generic)
      rest_uri ||= uri.clone.tap { |u| u.scheme = 'http' }
      ws_uri ||= uri.clone.tap { |u| u.scheme = 'ws' }

      new_node = Node.new(rest_uri, ws_uri, authorization, self)
      new_node.start

      @nodes << new_node
    end

    def remove_node(node)
      @nodes.delete(node)
      node.stop
    end

    def best_node
      @nodes.min { |n| n.stats['cpu']['systemLoad'] }
    end

    def get_player(guild_id)
      @players[guild_id.to_s]
    end

    # TODO: load balacing stuff
  end
end
