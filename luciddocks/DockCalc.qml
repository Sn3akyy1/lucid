import QtQuick
pragma Singleton

QtObject {
    id: calc

    readonly property var constants: ({
        "pi": Math.PI,
        "e": Math.E
    })
    readonly property var functions: ({
        "sqrt": Math.sqrt,
        "cbrt": Math.cbrt,
        "abs": Math.abs,
        "round": Math.round,
        "floor": Math.floor,
        "ceil": Math.ceil,
        "sin": Math.sin,
        "cos": Math.cos,
        "tan": Math.tan,
        "ln": Math.log,
        "log": Math.log10,
        "exp": Math.exp
    })

    function tokenize(src) {
        var out = [];
        var i = 0;
        while (i < src.length) {
            var ch = src.charAt(i);
            if (ch === " " || ch === "\t" || ch === ",") {
                i++;
                continue;
            }
            if (ch >= "0" && ch <= "9" || ch === ".") {
                var start = i;
                while (i < src.length && (src.charAt(i) >= "0" && src.charAt(i) <= "9" || src.charAt(i) === ".")) i++;
                var num = parseFloat(src.substring(start, i));
                if (isNaN(num))
                    return null;

                out.push({
                    "t": "num",
                    "v": num
                });
                continue;
            }
            if (ch >= "a" && ch <= "z" || ch >= "A" && ch <= "Z") {
                var s2 = i;
                while (i < src.length && (src.charAt(i) >= "a" && src.charAt(i) <= "z" || src.charAt(i) >= "A" && src.charAt(i) <= "Z")) i++;
                out.push({
                    "t": "name",
                    "v": src.substring(s2, i).toLowerCase()
                });
                continue;
            }
            if ("+-*/%^()".indexOf(ch) !== -1) {
                out.push({
                    "t": ch,
                    "v": ch
                });
                i++;
                continue;
            }
            return null;
        }
        return out;
    }

    function parseExpr(tk, p) {
        var left = calc.parseTerm(tk, p);
        if (!left)
            return null;

        while (left.next < tk.length && (tk[left.next].t === "+" || tk[left.next].t === "-")) {
            var op = tk[left.next].t;
            var right = calc.parseTerm(tk, left.next + 1);
            if (!right)
                return null;

            left = {
                "value": op === "+" ? left.value + right.value : left.value - right.value,
                "next": right.next
            };
        }
        return left;
    }

    function parseTerm(tk, p) {
        var left = calc.parsePower(tk, p);
        if (!left)
            return null;

        while (left.next < tk.length && (tk[left.next].t === "*" || tk[left.next].t === "/" || tk[left.next].t === "%")) {
            var op = tk[left.next].t;
            var right = calc.parsePower(tk, left.next + 1);
            if (!right)
                return null;

            var v = op === "*" ? left.value * right.value : (op === "/" ? left.value / right.value : left.value % right.value);
            left = {
                "value": v,
                "next": right.next
            };
        }
        return left;
    }

    // right-associative, so 2^3^2 is 2^(3^2)
    function parsePower(tk, p) {
        var base = calc.parseUnary(tk, p);
        if (!base)
            return null;

        if (base.next < tk.length && tk[base.next].t === "^") {
            var exp = calc.parsePower(tk, base.next + 1);
            if (!exp)
                return null;

            return {
                "value": Math.pow(base.value, exp.value),
                "next": exp.next
            };
        }
        return base;
    }

    function parseUnary(tk, p) {
        if (p < tk.length && (tk[p].t === "-" || tk[p].t === "+")) {
            var sign = tk[p].t === "-" ? -1 : 1;
            var inner = calc.parseUnary(tk, p + 1);
            if (!inner)
                return null;

            return {
                "value": sign * inner.value,
                "next": inner.next
            };
        }
        return calc.parsePrimary(tk, p);
    }

    function parsePrimary(tk, p) {
        if (p >= tk.length)
            return null;

        var t = tk[p];
        if (t.t === "num")
            return {
                "value": t.v,
                "next": p + 1
            };

        if (t.t === "(") {
            var inner = calc.parseExpr(tk, p + 1);
            if (!inner || inner.next >= tk.length || tk[inner.next].t !== ")")
                return null;

            return {
                "value": inner.value,
                "next": inner.next + 1
            };
        }
        if (t.t === "name") {
            if (calc.constants[t.v] !== undefined)
                return {
                    "value": calc.constants[t.v],
                    "next": p + 1
                };

            var fn = calc.functions[t.v];
            if (fn === undefined || p + 1 >= tk.length || tk[p + 1].t !== "(")
                return null;

            var arg = calc.parseExpr(tk, p + 2);
            if (!arg || arg.next >= tk.length || tk[arg.next].t !== ")")
                return null;

            return {
                "value": fn(arg.value),
                "next": arg.next + 1
            };
        }
        return null;
    }

    function evaluate(src) {
        if (!src || src.trim() === "")
            return "";

        var body = src.trim();
        // a leading "=" lets a bare number through
        var forced = body.charAt(0) === "=";
        if (forced)
            body = body.substring(1).trim();

        if (body === "")
            return "";

        var tk = calc.tokenize(body);
        if (!tk || tk.length === 0)
            return "";

        if (!forced) {
            var hasOp = false;
            for (var i = 0; i < tk.length; i++) {
                if ("+-*/%^".indexOf(tk[i].t) !== -1 || tk[i].t === "name")
                    hasOp = true;

            }
            var hasNum = tk.some(function(x) {
                return x.t === "num";
            });
            if (!hasOp || !hasNum)
                return "";
        }

        var res = calc.parseExpr(tk, 0);
        if (!res || res.next !== tk.length)
            return "";

        if (typeof res.value !== "number" || !isFinite(res.value))
            return "";

        return calc.format(res.value);
    }

    function format(v) {
        if (Math.abs(v) >= 1e15 || (v !== 0 && Math.abs(v) < 1e-6))
            return v.toExponential(6).replace(/e([+-])(\d)$/, "e$10$2");

        var r = Math.round(v * 1e10) / 1e10;
        var s = r.toString();
        if (s.indexOf(".") !== -1)
            s = s.replace(/0+$/, "").replace(/\.$/, "");

        return s;
    }
}
