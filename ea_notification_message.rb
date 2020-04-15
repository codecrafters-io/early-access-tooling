# Usage: ruby ea_notification_message.rb early-access-11

require "discordrb"
require "pry"

server_id = "673463293901537291"
channel_name = ARGV[0]

bot = Discordrb::Bot.new(token: ENV.fetch("DISCORD_BOT_TOKEN"))
channels_resp = Discordrb::API::Server.channels(bot.token, server_id)
channels = JSON.parse(channels_resp)
channel_id = channels.find { |channel| channel["name"] == channel_name}["id"]

messages_resp = Discordrb::API::Channel.messages(bot.token, channel_id, 100)
message = JSON.parse(messages_resp).last
message_id = message.fetch("id")

reactions_resp = Discordrb::API::Channel.get_reactions(bot.token, channel_id, message_id, "👍")
users = JSON.parse(reactions_resp)
message = users
            .map { |user| "<@#{user.fetch("id")}>" }
            .join(" ")

puts "Found #{users.count} user(s) to notify. Proceed?"
STDIN.gets

Discordrb::API::Channel.create_message(
  bot.token,
  channel_id,
  message,
)
