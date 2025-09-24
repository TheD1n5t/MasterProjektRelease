import re

# Eingabedatei
input_file = "feature_valuesDataSet1.txt"
# Ausgabedatei
output_file = "feature_values_array.c"

# Dateiinhalt einlesen
with open(input_file, "r") as f:
    text = f.read()

# Alle Floats extrahieren
values = re.findall(r"[-+]?\d*\.\d+|\d+", text)
values = [float(v) for v in values]

# In C-Array-Datei schreiben
with open(output_file, "w") as f:
    f.write(f"const double feature_values_test[{len(values)}] = {{\n")
    for i, value in enumerate(values):
        f.write(f"  {value:.6f},")
        if (i + 1) % 8 == 0:  # 8 Werte pro Zeile
            f.write("\n")
    f.seek(f.tell() - 1, 0)  # letztes Komma entfernen
    f.write("\n};\n")

print(f"Export fertig! Datei gespeichert als: {output_file}")
