fx_version 'cerulean'
game 'gta5'
author 'Vanguard Library'
description 'Shared library for Vanguard resources - map atlas and utilities'

shared_scripts {
	'@ox_lib/init.lua',
	'init.lua',
}

client_scripts {
	'client/callbacks.lua',
	'client/geo.lua',
	'client/state.lua',
	'client/security_token.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/helpers.lua',
	'server/ratelimit.lua',
	'server/discord.lua',
	'server/discord_queue.lua',
	'server/callbacks.lua',
	'server/framework.lua',
	'server/transaction.lua',
	'server/state.lua',
	'server/security_token.lua',
	'server/guard_config.lua',
	'server/guard.lua',
}

files {
	'init.lua',
	'types/**/*',
	'styleAtlas/**/*',
	'map/**/*',
	'js/**/*',
	'vendor/**/*',
}

lua54 'yes'

dependencies {
	'ox_lib',
	'oxmysql',
	'qbx_core',
}
