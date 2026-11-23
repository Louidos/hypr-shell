.pragma library

// Rechner für den Starter: "=12*8" → "96". Eigener kleiner Parser (kein eval): + - * / % ^,
// Klammern, Dezimalpunkt oder -komma, Konstanten pi und e, Funktionen sqrt, abs, round, floor,
// ceil, sin, cos, tan, log (Basis 10), ln. Ungültige Eingabe ergibt "".

const FUNKTIONEN = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, log: Math.log10, ln: Math.log
}
const KONSTANTEN = { pi: Math.PI, e: Math.E }

function zerlege(text) {
    const t = []
    let i = 0
    while (i < text.length) {
        const c = text[i]
        if (c === " " || c === "\t") { i++; continue }
        if ("+-*/%^()".indexOf(c) >= 0) { t.push({ art: "op", wert: c }); i++; continue }
        if (c === "×") { t.push({ art: "op", wert: "*" }); i++; continue }
        if (c === "÷") { t.push({ art: "op", wert: "/" }); i++; continue }
        if (/[0-9.,]/.test(c)) {
            let j = i
            while (j < text.length && /[0-9.,]/.test(text[j])) j++
            const zahl = Number(text.slice(i, j).replace(",", "."))
            if (isNaN(zahl)) throw "zahl"
            t.push({ art: "zahl", wert: zahl }); i = j; continue
        }
        if (/[a-z]/i.test(c)) {
            let j = i
            while (j < text.length && /[a-z]/i.test(text[j])) j++
            t.push({ art: "name", wert: text.slice(i, j).toLowerCase() }); i = j; continue
        }
        throw "zeichen"
    }
    return t
}

function berechne(text) {
    const t = zerlege(text)
    let p = 0
    const ist = w => p < t.length && t[p].art === "op" && t[p].wert === w
    function summe() {
        let v = produkt()
        while (ist("+") || ist("-")) { const o = t[p++].wert; const r = produkt(); v = o === "+" ? v + r : v - r }
        return v
    }
    function produkt() {
        let v = vorzeichen()
        while (ist("*") || ist("/") || ist("%")) {
            const o = t[p++].wert; const r = vorzeichen()
            v = o === "*" ? v * r : o === "/" ? v / r : v % r
        }
        return v
    }
    // Vorzeichen bindet schwächer als ^ (-3^2 = -9), der Exponent darf eins haben (2^-1)
    function vorzeichen() {
        if (ist("-")) { p++; return -vorzeichen() }
        if (ist("+")) { p++; return vorzeichen() }
        return potenz()
    }
    function potenz() {
        const b = wert()
        if (ist("^")) { p++; return Math.pow(b, vorzeichen()) }
        return b
    }
    function wert() {
        if (p >= t.length) throw "ende"
        const x = t[p++]
        if (x.art === "zahl") return x.wert
        if (x.art === "op" && x.wert === "(") { const v = summe(); if (!ist(")")) throw "klammer"; p++; return v }
        if (x.art === "name") {
            if (FUNKTIONEN[x.wert] !== undefined) {
                if (!ist("(")) throw "klammer"
                p++
                const v = summe()
                if (!ist(")")) throw "klammer"
                p++
                return FUNKTIONEN[x.wert](v)
            }
            if (KONSTANTEN[x.wert] !== undefined) return KONSTANTEN[x.wert]
        }
        throw "unbekannt"
    }
    const v = summe()
    if (p !== t.length) throw "rest"
    return v
}

// "=12*8" oder "12*8" → "96"; "" bei Fehler
function rechne(eingabe) {
    let s = String(eingabe || "").trim()
    if (s.indexOf("=") === 0) s = s.slice(1)
    if (s.trim() === "") return ""
    try {
        const v = berechne(s)
        if (typeof v !== "number" || !isFinite(v)) return ""
        return String(Number(v.toPrecision(12)))
    } catch (e) {
        return ""
    }
}
