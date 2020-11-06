# frozen_string_literal: true

require 'caldera/model'
require 'caldera/player'
require 'caldera/websocket'
require 'event_emitter'
require 'net/http'

module Caldera
  class Node
    LOGGER = Logging.logger[self]

    include EventEmitter

    # @return [Caldera::Client]
    attr_reader :client

    # @return [Caldera::WebSocket]
    attr_reader :websocket

    # @return [Net::HTTP]
    attr_reader :http

    # @return [Caldera::Model::Stats]
    attr_reader :stats

    def initialize(rest_uri, ws_uri, auth, client)
      @client = client
      @authorization = auth
      @websocket = WebSocket.new(ws_uri, auth, @client.num_shards, @client.user_id)
      register_handlers
      @stats = nil
      @available = false
      @http = Net::HTTP.new(rest_uri.host, rest_uri.port)
    end

    def start
      LOGGER.info { "Connecting to #{@websocket.url}" }
      @websocket.start
    end

    def stop
      LOGGER.info { "Disconnecting from #{@websocket.url}" }
      @websocket.close
    end

    def create_player(guild_id, session_id, event)
      LOGGER.info { "Creating player for #{guild_id}" }
      @websocket.send_json({
                             op: :voiceUpdate,
                             guildId: guild_id,
                             sessionId: session_id,
                             event: event
                           })

      player = Player.new(guild_id, self, client)
      @client.players[guild_id] = player
    end

    def load_tracks(id)
      resp = get('/loadtracks', query: { identifier: id })
      Model::LoadTracks.new(resp)
    end

    def youtube_search(search_string)
      load_tracks("ytsearch:#{search_string}")
    end

    def soundcloud_search(search_string)
      load_tracks("scsearch:#{search_string}")
    end

    def send_json(data)
      @websocket.send_json(data)
    end

    private

    def register_handlers
      @websocket.on(:playerUpdate, &method(:handle_player_update))
      @websocket.on(:stats, &method(:handle_stats))
      @websocket.on(:event, &method(:handle_event))
      @websocket.on(:open) { @available = true }
      @websocket.on(:close) { @available = false }
    end

    def handle_player_update(data)
      @client.get_player(data['guildId']).state = data['state']
    end

    def handle_stats(data)
      data_without_op = data.clone
      data_without_op.delete('op')
      @stats = data_without_op

      emit(:stats_update, Events::StatsEvent.new(data, self))
    end

    def handle_event(data)
      type = transform_type(data['type'])
      emit(type, data)
    end

    def transform_type(type)
      (type[0] + type[1..-1].sub(/Event$/, '').gsub(/([A-Z])/, '_\1')).downcase
    end

    def get(path, query: {})
      req_path = "#{path}?#{URI.encode_www_form(query)}"
      resp = @http.get(req_path, { Authorization: @authorization })

      case resp.code.to_i
      when 200...300
        JSON.parse(resp.body)
      else
        # TODO
        resp.error!
      end
    end
  end
end
