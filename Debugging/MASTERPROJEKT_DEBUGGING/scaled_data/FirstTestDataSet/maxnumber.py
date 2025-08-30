import csv

# Pfad zur .csv-Datei
file_path = 'D:/Documents/FAU/MASTERPROJEKT/TestData/Dataexplained/scaled_data/testing_emg.csv'

# Variablen zum Speichern der maximalen und minimalen Zahl
max_number = float('-inf')  # Startwert für maximale Zahl
min_number = float('inf')   # Startwert für minimale Zahl

# Datei öffnen und lesen
with open(file_path, "r") as file:
    csv_reader = csv.reader(file)
    # Erste Zeile (Header) überspringen
    next(csv_reader, None)
    # Alle weiteren Zeilen und Werte durchgehen
    for row in csv_reader:
        for value in row:  # Jede Zelle der aktuellen Zeile durchgehen
            try:
                # Zahl aus der Zelle extrahieren und als float lesen
                number = float(value.strip())
                # Maximalwert aktualisieren
                if number > max_number:
                    max_number = number
                # Minimalwert aktualisieren
                if number < min_number:
                    min_number = number
            except ValueError:
                # Falls eine Zelle keine Zahl enthält, überspringen
                pass

print(f"Die maximale Zahl in der .csv-Datei ist: {max_number}")
print(f"Die minimale Zahl in der .csv-Datei ist: {min_number}")
