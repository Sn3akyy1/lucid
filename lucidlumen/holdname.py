#!/usr/bin/env python3
# holds lumen's portal name while lumen starts. xdg-desktop-portal starts lumen
# when it starts, and answers nobody until the name is taken, qt's own start in
# lumen included, so the two would wait on each other. this takes the name at
# once and lets go as soon as lumend asks for it
import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

NAME = "org.freedesktop.impl.portal.desktop.lucid"

loop = GLib.MainLoop()
Gio.bus_own_name(Gio.BusType.SESSION, NAME,
                 Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT | Gio.BusNameOwnerFlags.DO_NOT_QUEUE,
                 None, None, lambda *_: loop.quit())
# an lumen that never comes up gets the name back to d-bus, which starts it again
GLib.timeout_add_seconds(60, loop.quit)
loop.run()
