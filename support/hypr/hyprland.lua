------------------
---- MONITORS ----
------------------
require("modules.monitors")
-------------------
---- AUTOSTART ----
-------------------
require("modules.autostart")
-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
require("modules.env")
-- what Settings > Startup sets: variables, apps opened at login, XDG autostart
require("modules.startup")
-----------------------
---- LOOK AND FEEL ----
-----------------------
require("modules.decorations")
require("modules.animations")
----------------
----  MISC  ----
----------------
require("modules.misc")
---------------
---- INPUT ----
---------------
require("modules.input")
require("modules.layout")
require("modules.gestures")
---------------------
---- KEYBINDINGS ----
---------------------
require("modules.binds")
--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
require("modules.windowrules")
require("modules.layerrules")
-- lumen's file dialogs: the variable gtk 3 needs to ask for them, and their rule
require("modules.lumen")
require("modules.glass")
-- plugin options; each block only applies while its plugin is loaded
require("modules.plugins")
-------------------------------
---- SETTINGS FROM LUCID   ----
-------------------------------
-- what Settings > Windows changes; anything required after this line wins
require("modules.settings")