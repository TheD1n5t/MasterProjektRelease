import csv
import numpy as np

def process_split(emg_file, label_file, k, skip_header=True):
    # --- EMG laden ---
    emg_data = []
    with open(emg_file, "r") as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            if skip_header and i == 0:
                continue
            emg_data.append(row[:32])  # nur die ersten 32 Zahlen
    emg_data = np.array(emg_data)

    # --- Labels laden ---
    labels = []
    with open(label_file, "r") as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            if skip_header and i == 0:
                continue
            labels.append(row[0])
    labels = np.array(labels)

    if len(labels) != len(emg_data):
        raise ValueError("Mismatch: EMG rows vs labels")

    # --- pro Klasse Samples zählen ---
    unique_labels, counts = np.unique(labels, return_counts=True)
    min_count = counts.min()
    per_class = (min_count // k) * k   # abrunden auf Vielfaches von k

    # --- ausgewählte Samples sammeln (Labels absteigend sortiert) ---
    selected = []
    try:
        # Versuche numerisch zu sortieren
        label_order = sorted(unique_labels, key=lambda x: int(x), reverse=True)
    except ValueError:
        # Fallback: lexikographisch sortieren
        label_order = sorted(unique_labels, reverse=True)

    for lab in label_order:
        idx = np.where(labels == lab)[0][:per_class]  # erste per_class Samples
        selected.extend(emg_data[idx])
    return selected


def main():
    k = 5  # Vielfaches einstellen

    # Trainingsteil
    train_samples = process_split(
        "training_emg.csv",
        "training_labels.csv",
        k=k,
        skip_header=True
    )

    # Testteil
    test_samples = process_split(
        "testing_emg.csv",
        "testing_labels.csv",
        k=k,
        skip_header=True
    )

    # Alles untereinander in eine Datei schreiben
    with open("all_numbers.txt", "w") as f:
        for sample in train_samples + test_samples:
            for value in sample:
                f.write(f"{value}\n")

    print(f"Done. {len(train_samples)} Training-Samples + {len(test_samples)} Test-Samples geschrieben.")


if __name__ == "__main__":
    main()
