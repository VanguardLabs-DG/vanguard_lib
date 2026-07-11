fx_version 'cerulean'
game 'gta5'
author 'Vanguard Library'
description 'Shared library for Vanguard resources - map atlas and utilities'

shared_scripts {
	'@ox_lib/init.lua',
}

client_scripts {
	'client/callbacks.lua',
	'client/geo.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/helpers.lua',
	'server/ratelimit.lua',
	'server/discord.lua',
	'server/callbacks.lua',
	'server/framework.lua',
}

files {
	'styleAtlas/**/*',
	'map/**/*',
	'js/**/*',
}

lua54 'yes'

dependencies {
	'ox_lib',
	'oxmysql',
	'qbx_core',
}
