# frozen_string_literal: true

require 'caldera/model'
require 'caldera/events'
require 'event_emitter'
require 'logging'

module Caldera
  class Player
    include EventEmitter

    # @visibility private
    LOGGER = Logging.logger[self]

    # @return [String]
    attr_reader :guild_id

    # @return [Node] The node that owns this player.
    attr_reader :node

    # @return [Client]
    attr_reader :client

    # @return [Integer]
    attr_reader :volume

    # @return [true, false]
    attr_reader :paused

    # @return [Integer]
    attr_reader :position

    # @return [Time]
    attr_reader :time

    # @return [Track]
    attr_reader :track
    alias now_playing track

    def initialize(guild_id, node, client)
      @guild_id = guild_id
      @node = node
      @client = client
      @volume = 100
      @paused = false
      @position = 0
      @time = 0

      register_node_handlers
    end

    # Play a track.
    # @param [String, Track] Either a base64 encoded track, or a {Track} object.
    # @param [Integer] start_time The time in milliseconds to begin playback at.
    # @param [Integer] end_time The time in milliseconds to end at.
    def play(track, start_time: 0, end_time: 0)
      @paused = false
      @track = track

      send_packet(:play, {
                    track: track.is_a?(Model::Track) ? track.track_data : track,
                    startTime: start_time,
                    endTime: end_time,
                    noReplace: false
                  })
    end

    # Pause playback.
    def pause
      send_packet(:pause, {
                    pause: true
                  })
    end

    # Resume the player.
    def unpause
      send_packet(:pause, {
                    pause: false
                  })
    end

    # Seek to a position in the track.
    # @param [Integer] position The position to seek to, in milliseconds.
    def seek(position)
      send_packet(:seek, {
                    position: position
                  })
    end

    # Set the volume of the player
    # @param [Integer] level A value between 0 and 1000.
    def volume=(level)
      send_packet(:volume, {
                    volume: level.clamp(0, 1000)
                  })
    end

    # Adjust the gain of bands.
    # @example
    #   player.equalizer(1 => 0.25, 5 => -0.25, 10 => 0.0)
    def equalizer(**bands)
      send_packet(:equalizer, {
                    bands: bands.collect do |band, gain|
                      { band: band.to_i, gain: gain.to_f }
                    end
                  })
    end

    # Destroy this player
    def destroy
      send_packet(:destroy)
    end

    # @visibility private
    def state=(new_state)
      @time = Time.at(new_state['time'])
      @position = new_state['position']
    end

    # See Node#load_tracks
    def load_tracks(*args, **opts)
      @node.load_tracks(*args, **opts)
    end

    private

    def send_packet(op, data = {})
      packet = { op: op, guildId: guild_id }.merge(data)
      LOGGER.debug { "Sending packet to node: #{packet}" }
      @node.send_json(packet)
    end

    def register_node_handlers
      node.on(:track_start, &method(:handle_track_start))
      node.on(:track_end, &method(:handle_track_end))
      node.on(:track_exception, &method(:handle_track_exception))
      node.on(:track_stuck, &method(:handle_track_stuck))
      node.on(:websocket_closed, &method(:handle_websocket_closed))
    end

    def handle_track_start(data)
      LOGGER.debug { "Track started for #{@guild_id}" }
      emit(:track_start, Events::TrackStart.new(data, self))
    end

    def handle_track_end(data)
      LOGGER.debug { "Track ended for #{@guild_id}" }

      @track = nil
      emit(:track_end, Events::TrackEnd.new(data, self))
    end

    def handle_track_exception(data)
      LOGGER.debug { "Track exception for #{@guild_id}" }
      @track = nil
      emit(:track_exception, Events::TrackException.new(data, self))
    end

    def handle_track_stuck(data)
      LOGGER.debug { "Track stuck for #{@guild_id}" }
      @track = nil
      emit(:track_stuck, Events::TrackStuck.new(data, self))
    end

    def handle_websocket_closed(data)
      LOGGER.warn { "WebSocket closed for #{@guild_id}" }
      @track = nil
      emit(:websocket_closed, Events::WebSocketClosed.new(data, self))
    end
  end
end
