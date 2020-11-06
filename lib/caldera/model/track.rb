# frozen_string_literal: true

require 'base64'

module Caldera
  module Model
    class Track
      # @param [String] Base64 representation of the track
      attr_reader :track_data

      # @param [String] The track identifier
      attr_reader :identifier

      # @param [true, false]
      attr_reader :seekable

      # @param [String] The track author.
      attr_reader :author

      # @param [Integer] Length in milliseconds.
      attr_reader :length

      # @param [true, false]
      attr_reader :stream

      # @param [Integer] The current position in milliseconds.
      attr_reader :position

      # @param [String] The track title.
      attr_reader :title

      # @param [String] The URI to the track source.
      attr_reader :uri

      def initialize(data)
        # track_data could maybe use a better name. It's
        # a base64 representation of a binary data representation
        # of a track=
        @track_data = data['track']

        info = data['info']
        @identifier = info['identifier']
        @seekable = info['isSeekable']
        @author = info['author']
        @length = info['length']
        @stream = info['isStream']
        @position = info['position']
        @title = info['title']
        @uri = info['uri']
        @source = info['source']
      end

      # Decode a track from base64 track data.
      # @param [String] b64_data Base64 encoded track data, recieved from the Lavalink server.
      def self.from_b64(b64_data)
        data = Base64.decode64(b64_data)
        flags, version = data.unpack('NC')

        raise 'Unsupported track data' if (flags >> 30) != 1

        # This is gross but it's easier than not doing it
        case version
        when 1
          title, author, length, identifier, is_stream, source = data.unpack('@7Z*xZ*Q>xZ*CxZ*')
          Track.new(
            'track' => b64_data,
            'info' => {
              'title' => title,
              'author' => author,
              'length' => length,
              'identifier' => identifier,
              'isStream' => is_stream == 1,
              'source' => source
            }
          )
        when 2
          title, author, length, identifier, is_stream, uri, source = data.unpack('@7Z*xZ*Q>xZ*CxxZ*xZ*xZ*')
          Track.new(
            'track' => b64_data,
            'info' => {
              'title' => title,
              'author' => author,
              'length' => length,
              'identifier' => identifier,
              'isStream' => is_stream == 1,
              'source' => source,
              'uri' => uri
            }
          )
        else
          raise 'Unsupported track version'
        end
      end
    end
  end
end
