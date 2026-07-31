fx_version "cerulean"
game "gta5"
lua54 "yes"
author "Davistk"

ui_page "web/index.html"

files {
    "audio/alarm.mp3",
    "web/index.html",
    "web/app.js"
}

shared_scripts {
    "@ox_lib/init.lua",
    "shared-side/00_compat.lua",
    "shared-side/*"
}

client_scripts {
    "client-side/framework.lua",
    "client-side/core.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server-side/framework.lua",
    "server-side/core.lua"
}

dependencies {
    "bob74_ipl",
    "qbx_core",
    "ox_lib",
    "ox_inventory",
    "oxmysql",
    "rhd_garage",
    "mri_supreme_bridge",
    "illenium-clothing"
}
