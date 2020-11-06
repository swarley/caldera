# frozen_string_literal: true

module Caldera
  module Model
    # Represents the struct returned from {Client#load_tracks}
    class LoadTracks
      include Enumerable

      # @return [PlaylistInfo]
      attr_reader :playlist_info

      # @return [Array<Track>]
      attr_reader :tracks

      # @return [:TRACK_LOADED, :PLAYLIST_LOADED, :SEARCH_RESULT, :NO_MATCHES, :LOAD_FAILED]
      attr_reader :load_type

      def initialize(data)
        playlist_info = data['playlistInfo']

        @playlist_info = PlaylistInfo.new(playlist_info) if playlist_info
        @tracks = data['tracks'].collect { |track_data| Model::Track.new(track_data) }
        @load_type = data['loadType'].to_sym
      end

      # Operate on each track.
      # @yieldparam [Track]
      def each(&block)
        @tracks.each(&block)
      end
    end
  end
end
