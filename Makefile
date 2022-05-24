notification_message:
	bundle exec ruby ea_notification_message.rb <your_channel>

sync_roles:
	echo $DISCORD_BOT_TOKEN | base64
	bundle exec ruby sync_crafter_roles.rb
