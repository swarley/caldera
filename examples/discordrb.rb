# frozen_string_literal: true

require 'caldera'
require 'discordrb'

bot = Discordrb::Commands::CommandBot.new(token: ENV['DAB_O_TRON_TOKEN'], prefix: 'ino.')

caldera = Caldera::Client.new(num_shards: 1, user_id: 507_628_595_880_001_556, connect: lambda { |gid, cid|
  bot.gateway.send_voice_state_update(gid, cid, false, false)
})
caldera.add_node(uri: 'http://localhost:2333', authorization: 'admin')

bot.voice_state_update from: bot.bot_app.id do |event|
  caldera.update_voice_state(event.server.id, session_id: event.session_id)
end

bot.voice_server_update do |event|
  server_id = event.server.id.to_s
  caldera.update_voice_state(server_id, event: {
                               token: event.token, guild_id: server_id, endpoint: event.endpoint
                             })
end

bot.command :connect do |event, id|
  return 'Please provide a channel ID' if id.nil?

  begin
    caldera.connect(event.server.id, id, timeout: 10)
    'Connected'
  rescue Timeout::Error
    'Failed to connect'
  end
end

bot.command :play do |event, *args|
  player = caldera.get_player(event.server.id)

  begin
    player ||= caldera.connect(event.server.id, event.author.voice_channel.id, timeout: 10)
  rescue Timeout::Error
    return 'Failed to connect to channel'
  end

  track_info = player.load_tracks(args.join(' '))
  player.play(track_info.first)

  "Playing `#{track_info.first.title}`"
end

bot.command :quit do |event|
  caldera.get_player(event.server.id)&.destroy
  bot.voice_state_update(event.server.id, nil, false, false)
end

bot.run
