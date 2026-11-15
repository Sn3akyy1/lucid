import QtQuick
import QtTest
import "../../../I18nCore.js" as Core

TestCase {
    name: "I18nCore"

    function test_lookup_missing() {
        compare(Core.tr({}, "Battery", []), "Battery");
        compare(Core.tr({ "Battery": "" }, "Battery", []), "Battery");
        compare(Core.tr({ "Battery": "Batería" }, "Battery", []), "Batería");
    }

    function test_format_order() {
        compare(Core.tr({ "%1 of %2": "%2 de %1" }, "%1 of %2", [3, 5]), "5 de 3");
    }

    function test_format_percent() {
        compare(Core.format("100%", []), "100%");
        compare(Core.format("%1%", [40]), "40%");
        compare(Core.format("%1 and %2", [1]), "1 and %2");
    }

    function test_plural() {
        var s = { "%1 update": { "one": "%1 actualización", "other": "%1 actualizaciones" } };
        compare(Core.trn(s, "%1 update", "%1 updates", 1, []), "1 actualización");
        compare(Core.trn(s, "%1 update", "%1 updates", 0, []), "0 actualizaciones");
        compare(Core.trn(s, "%1 update", "%1 updates", 2, []), "2 actualizaciones");
        compare(Core.trn({}, "%1 update", "%1 updates", 2, []), "2 updates");
    }

    function test_context() {
        compare(Core.trc({ "verb|Open": "Abrir" }, "verb", "Open", []), "Abrir");
        compare(Core.trc({}, "verb", "Open", []), "Open");
    }

    function test_resolve_region() {
        compare(Core.resolve("auto", "es_MX", ["es"]), "es");
        compare(Core.resolve("auto", "es_MX", ["es", "es_MX"]), "es_MX");
        compare(Core.resolve("auto", "fr_FR", ["es"]), "en");
        compare(Core.resolve("en", "es_MX", ["es"]), "en");
        compare(Core.resolve("es", "", ["es"]), "es");
        compare(Core.resolve("de", "es_MX", ["es"]), "en");
    }

    function test_resolve_env() {
        compare(Core.envLocale("", "", "es_MX.UTF-8"), "es_MX");
        compare(Core.envLocale("C.UTF-8", "", "es_MX.UTF-8"), "");
        compare(Core.envLocale("", "de_DE.UTF-8@euro", "es_MX.UTF-8"), "de_DE");
        compare(Core.envLocale("", "", ""), "");
        compare(Core.envLocale("", "", "POSIX"), "");
    }

    function test_candidates() {
        compare(Core.candidates("es_MX"), ["es_MX", "es"]);
        compare(Core.candidates("es"), ["es"]);
        compare(Core.candidates(""), []);
    }
}
