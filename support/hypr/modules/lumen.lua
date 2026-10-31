-------------------
----   LUMEN   ----
-------------------
-- lumen, lucid's file manager, is every app's open and save dialog
-- (lucidlumen/lumen --portal). install.sh adds this module to a config that is
-- not lucid's own too, so the dialogs work the same there

-- gtk 3 apps only ask the portal for their dialogs when this is set
hl.env("GTK_USE_PORTAL", "1")

-- the dialogs come through the portal with no parent to hang off, so they
-- would tile. the window names itself "<title> — Lumen"; a browsing window never does
hl.window_rule({
    name  = "float-lumen-dialogs",
    match = { class = "^(lucid\\.lumen)$", title = "^.+ — Lumen$" },

    float  = true,
    center = true,
})
