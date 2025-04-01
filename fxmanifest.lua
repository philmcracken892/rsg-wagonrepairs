fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'phil'
description 'Wagon repair system using RSGTarget and ox_lib'
version '1.0.0'

dependencies {
	'rsg-core',
    'ox_target'
    
}
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@rsg-core/shared/locale.lua',
    'client.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

lua54 'yes'

