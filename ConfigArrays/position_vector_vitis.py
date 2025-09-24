#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import re
from typing import List

def sanitize_bits(line: str) -> str:
    """Entfernt alles außer '0' und '1'."""
    return "".join(ch for ch in line if ch in "01")

def split_into_words(bitstring: str, word_size: int = 32) -> List[int]:
    """Zerlegt eine Bit-String-Sequenz in word_size breite Wörter (MSB->LSB) und gibt int-Werte zurück."""
    return [int(bitstring[i:i+word_size], 2) for i in range(0, len(bitstring), word_size)]

def make_include_guard(path: str) -> str:
    base = os.path.basename(path)
    guard = re.sub(r'[^A-Za-z0-9]', '_', base).upper()
    if not guard.endswith('_H') and not guard.endswith('_HPP'):
        guard += '_H'
    return guard

def main():
    p = argparse.ArgumentParser(description="Konvertiert 10000-Bit-Vektoren in C-Array aus 32-Bit-HEX-Wörtern.")
    p.add_argument("-i", "--input",  default="position_vectors.txt", help="Eingabedatei (eine Zeile = 10000 Bits)")
    p.add_argument("-o", "--output", default="position_vectors_array.h", help="Ausgabedatei (.h oder .c)")
    p.add_argument("--bits-per-vector", type=int, default=10000, help="Bits pro Vektor vor Padding (default: 10000)")
    p.add_argument("--pad-bits",        type=int, default=16,    help="Anzahl 0-Bits, die am Ende angehängt werden (default: 16)")
    p.add_argument("--word-size",       type=int, default=32,    help="Wortbreite in Bits (default: 32)")
    p.add_argument("--name",            default="position_vectors", help="C-Array-Name (default: position_vectors)")
    p.add_argument("--ctype",           default="uint32_t",      help="C-Typ (default: uint32_t)")
    p.add_argument("--break-every",     type=int, default=8,     help="Zeilenumbruch nach N Wörtern (default: 8)")
    args = p.parse_args()

    # Einlesen & Säubern
    with open(args.input, "r", encoding="utf-8", errors="ignore") as f:
        raw_lines = [ln.strip() for ln in f if ln.strip()]

    bit_lines = []
    wrong = []
    for idx, ln in enumerate(raw_lines, start=1):
        bits = sanitize_bits(ln)
        if len(bits) != args.bits_per_vector:
            wrong.append((idx, len(bits)))
        bit_lines.append(bits)

    if wrong:
        msg = "\n".join([f"  Zeile {i}: {l} Bits (erwartet: {args.bits_per_vector})" for i, l in wrong[:10]])
        raise ValueError(f"Einige Zeilen haben nicht genau {args.bits_per_vector} Bits:\n{msg}\n"
                         f"(insgesamt {len(wrong)} fehlerhafte Zeilen)")

    words_per_vector = (args.bits_per_vector + args.pad_bits) // args.word_size
    if (args.bits_per_vector + args.pad_bits) % args.word_size != 0:
        raise ValueError("Padding passt nicht zu Wortgröße: (bits_per_vector + pad_bits) ist nicht durch word_size teilbar.")

    vectors_words: List[List[int]] = []
    for bits in bit_lines:
        padded = bits + ("0" * args.pad_bits)  # 16 Nullen ans Ende
        words = split_into_words(padded, args.word_size)
        if len(words) != words_per_vector:
            raise AssertionError("Unerwartete Wortanzahl nach Zerlegung.")
        vectors_words.append(words)

    # Header/Source schreiben
    is_header = os.path.splitext(args.output)[1].lower() in (".h", ".hpp")
    guard = make_include_guard(args.output) if is_header else None

    with open(args.output, "w", encoding="utf-8") as out:
        if is_header:
            out.write(f"#ifndef {guard}\n#define {guard}\n\n")
        out.write("#include <stdint.h>\n\n")
        out.write(f"// Auto-generated from {os.path.basename(args.input)}\n")
        out.write(f"// Vectors: {len(vectors_words)}, Words per vector: {words_per_vector}\n\n")
        out.write(f"const {args.ctype} {args.name}[{len(vectors_words)}][{words_per_vector}] = {{\n")

        for v_idx, vec in enumerate(vectors_words):
            out.write("    {")
            for w_idx, word in enumerate(vec):
                out.write(f"0x{word:08X}")
                if w_idx < len(vec) - 1:
                    out.write(", ")
                if args.break_every and (w_idx + 1) % args.break_every == 0 and w_idx != len(vec) - 1:
                    out.write("\n     ")
            out.write("}")
            out.write(",\n" if v_idx < len(vectors_words) - 1 else "\n")
        out.write("};\n\n")
        if is_header:
            out.write(f"#endif /* {guard} */\n")

    print(f"✅ Fertig: {args.output}")
    print(f"Vektoren: {len(vectors_words)} | Wörter/Vektor: {words_per_vector}")
    print("Beispiel (Vector 0, erste 8 Wörter):",
          [f"0x{w:08X}" for w in vectors_words[0][:min(8, len(vectors_words[0]))]])

if __name__ == "__main__":
    main()
