# frozen_string_literal: true

require 'vox/gateway/client'
require 'vox/http/client'
require 'caldera/client'

Vox.setup_default_logger(root_level: :debug)
Logging.logger.root.level = :warn

caldera = Caldera::Client.new(num_shards: 1, user_id: 507_628_595_880_001_556)
caldera.add_node(uri: 'http://localhost:2333', authorization: 'admin')

# TODO: Make this more generic
gateway = Vox::Gateway::Client.new(token: ENV['DAB_O_TRON_TOKEN'], url: 'wss://gateway.discord.gg')
rest = Vox::HTTP::Client.new(ENV['DAB_O_TRON_TOKEN'])

gateway.on :VOICE_SERVER_UPDATE do |data|
  caldera.update_voice_state(data[:guild_id], event: data)
end

gateway.on :VOICE_STATE_UPDATE do |data|
  next unless data[:session_id]

  caldera.update_voice_state(data[:guild_id], session_id: data[:session_id])
end

gateway.on :MESSAGE_CREATE do |data|
  cmd, *args = data[:content].split
  guild_id = data[:guild_id]

  case cmd
  when 'ino.join'
    gateway.voice_state_update(guild_id, args[0])
  when 'ino.play'
    track_info = caldera.best_node.load_tracks(args.join)
    rest.create_message(data[:channel_id], content: "Playing `#{track_info.first.title}`")
    caldera.get_player(guild_id).play(track_info.first)
  when 'ino.disconnect'
    caldera.get_player(guild_id).destroy
  end
end

gateway.connect
