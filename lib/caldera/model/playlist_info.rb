# frozen_string_literal: true

module Caldera
  module Model
    # Information about a playlist loaded through {Client#load_tracks}
    class PlaylistInfo
      # @return [String]
      attr_reader :name

      # @return [Integer]
      attr_reader :selected_track

      def initialize(data)
        @selected_track = data['selectedTrack']
        @name = data['name']
      end
    end
  end
end
