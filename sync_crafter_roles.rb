# Usage: ruby sync_crafter_roles.rb

require "discordrb"
require "pry"
require "octokit"
require "http"
require "json"
require "yaml"

DISCORD_SERVER_ID = "673463293901537291"

class UserProfile
  def initialize(user_profile_hash)
    @hash = user_profile_hash
  end

  def username
    @hash.fetch("username")
  end

  def github_username
    username
  end

  def completed_challenges
    @hash["events"]
      .select { |event| event["type"] == "completed-challenge" }
      .map { |event| event["challenge"] }
      .uniq
  end

  def has_completed_challenge?(challenge)
    completed_challenges.include?(challenge)
  end
end

class CodecraftersRegistry
end

class DiscordRegistry
  def roles(username)
    member_from_username(username)["role_ids"].map do |role_id| 
      role_name_from_id(role_id)
    end
  end

  private 

  def role_name_from_id(role_id)
    role_ids_to_names.fetch(role_id)
  end

  def role_ids_to_names
    @role_ids_to_names ||= JSON.parse(Discordrb::API::Server.roles(bot_token, DISCORD_SERVER_ID))
                             .map { |role| [role["id"], role["name"]] }
                             .to_h
  end

  def member_from_username(username)
    guild_members.find { |member| member["username"] == username }
  end

  def guild_members
    return @discord_guild_members unless @discord_guild_members.nil?

    puts "Reading discord members.."
    new_data = []
    after = nil
    loop do
      members_json = Discordrb::API::Server.resolve_members(bot_token, DISCORD_SERVER_ID, 200, after)
      members = JSON.parse(members_json)
      break if members.empty?
      new_data += members.map { |member|
        {
          "id" => member.fetch("user").fetch("id"),
          "username" => member.fetch("user").fetch("username"),
          "discriminator" => member.fetch("user").fetch("discriminator"),
          "nick" => member.fetch("nick"),
          "role_ids" => member.fetch("roles"),
          "joined_at" => Time.parse(member.fetch("joined_at")).round,
        }
      }
      puts "- Read #{new_data.count} members"
      after = members.last.fetch("user").fetch("id")
    end
    puts ""

    @discord_guild_members = new_data
  end

  private

  def bot_token
    bot = Discordrb::Bot.new(token: ENV.fetch("DISCORD_BOT_TOKEN")).token
  end
end

class DiscordRoleSyncer
  def sync
    puts "Updates channel ID: #{updates_channel_id}"

    user_profiles.each do |user_profile| 
      role_conditions.each do |role_name, condition| 
        role_should_exist = condition.call(user_profile)

        github_username = user_profile.github_username
        discord_username = github_discord_mapping[github_username]
        if discord_username.nil?
          puts "skip: #{github_username}, no discord mapping"
          next
        end

        existing_roles = discord_registry.roles(discord_username)

        if !role_should_exist and existing_roles.include?(role_name)
          puts "WARNING: Found #{role_name} assigned to #{discord_username}, but didn't expect it"
        end

        if role_should_exist and !existing_roles.include?(role_name)
          puts "Assigning #{role_name} to #{discord_username} (GH: #{github_username})"
        end
      end
    end
  end

  private 

  def discord_registry
    @discord_registry ||= DiscordRegistry.new
  end

  def role_conditions
    {
      "Redis Crafter" => ->(u) { u.has_completed_challenge?("redis") },
      "Docker Crafter" => ->(u) { u.has_completed_challenge?("docker") },
      "Multi Crafter" => ->(u) { u.completed_challenges.count > 1 }
    }
  end

  def updates_channel_id
    return @updates_channel_id if @updates_channel_id

    bot = Discordrb::Bot.new(token: ENV.fetch("DISCORD_BOT_TOKEN"))
    channels_resp = Discordrb::API::Server.channels(bot.token, DISCORD_SERVER_ID)
    channels = JSON.parse(channels_resp)
    @updates_channel_id = channels.find { |channel| channel["name"] == "role-updates" }["id"]
  end

  def user_profiles
    @user_profiles ||= JSON.parse(user_profiles_json).map { |h| UserProfile.new(h) }
  end

  def github_discord_mapping
    @github_discord_mapping ||= YAML.load(github_discord_mapping_yml).map { |mapping|
      [
        mapping.fetch("github_username"),
        mapping.fetch("discord_username")
      ]
    }.to_h
  end

  def github_discord_mapping_yml
    download_from_github("_data/github_discord_mapping.yml")
  end

  def user_profiles_json
    download_from_github("_data/user_profiles.json")
  end

  def download_from_github(path)
    url = Octokit.contents("codecrafters-io/alpha-landing", path: path).download_url
    HTTP.get(url).to_s
  end
end

DiscordRoleSyncer.new.sync
