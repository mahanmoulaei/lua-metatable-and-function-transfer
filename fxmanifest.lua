fx_version "cerulean"
use_experimental_fxv2_oal "yes"
lua54 "yes"
game "gta5"

files {
    "files/*",
    "exports/*.lua"
}

shared_scripts {
    "@ox_lib/init.lua",
    "@es_extended/imports.lua",
    "shared/*.lua"
}

server_scripts {
    "server/*.lua"
}

client_scripts {
    "client/*.lua",
}

-- data_file "FIVEM_LOVES_YOU_4B38E96CC036038F" "files/events.meta"
-- data_file "FIVEM_LOVES_YOU_341B23A2F0E0F131" "files/popgroups.ymt"
