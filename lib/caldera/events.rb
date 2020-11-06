# frozen_string_literal: true

require 'caldera/model'

module Caldera
  module Events
    class TrackStart
      attr_reader :track, :player

      def initialize(data, player)
        @player = player
        @track = Caldera::Model::Track.from_b64(data['track'])
      end
    end

    class TrackEnd
      attr_reader :reason, :guild_id, :track, :player

      def initialize(data, player)
        @player = player
        @reason = data['reason'].to_sym
        @guild_id = data['guildId']
        @track = Caldera::Model::Track.from_b64(data['track'])
      end
    end

    class TrackException
      attr_reader :player, :error, :track

      def initialize(data, player)
        @player = player
        @error = data['error']
        @track = Caldera::Model::Track.from_b64(data['track'])
      end
    end

    class TrackStuck
      attr_reader :player, :threshold, :track

      def initialize(data, player)
        @player = player
        @threshold = data['thresholdMs']
        @track = Caldera::Model::Track.from_b64(data['track'])
      end
    end

    class WebSocketClosed
      # @returns [String]
      attr_reader :guild_id

      # @returns [Integer]
      attr_reader :code

      # @returns [String]
      attr_reader :reason

      # @returns [true, false]
      attr_reader :by_remote
      alias by_remote? by_remote

      def initialize(data, _player)
        @guild_id = data['guildId']
        @code = data['code']
        @reason = data['reason']
        @by_remote = data['byRemote']
      end
    end

    class StatsEvent
      Memory = Struct.new('Memory', :reservable, :used, :free, :allocated, keyword_init: true)
      Cpu = Struct.new('Cpu', :cores, :system_load, :lavalink_load, :uptime, keyword_init: true)

      attr_reader :playing_players, :memory, :cpu, :uptime

      def initialize(data, _node)
        @playing_players = data['playingPlayers']
        @memory = Memory.new(**data['memory'])

        cpu_data = data['cpu']
        snake_case_data = {
          cores: cpu_data['cores'],
          system_load: cpu_data['systemLoad'],
          lavalink_load: cpu_data['lavalinkLoad']
        }
        @cpu = Cpu.new(**snake_case_data)
        @uptime = data['uptime']
      end
    end

    class PlayerUpdateEvent
      attr_reader :player, :time, :position

      def initialize(data, player)
        @player = player
        @time = Time.at(data['time'])
        @position = data['position']
      end
    end
  end
end
