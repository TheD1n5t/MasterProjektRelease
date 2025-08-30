import os
import numpy as np
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from sklearn.utils import resample

def level_recommendations(file_path, max_K=50, sample_size=5000):
    # Daten laden
    values = np.loadtxt(file_path, delimiter=",").flatten()
    values = values[(values >= -1) & (values <= 1)]
    n = len(values)

    # -------------------
    # Freedman–Diaconis
    # -------------------
    IQR = np.percentile(values, 75) - np.percentile(values, 25)
    h_fd = 2 * IQR / (n ** (1/3))
    if h_fd <= 0:
        K_fd = 10  # fallback
    else:
        K_fd = int(np.ceil((values.max() - values.min()) / h_fd))

    # -------------------
    # K-Means + Silhouette
    # -------------------
    sil_scores = []
    Ks = list(range(2, max_K))  # nicht zu groß -> sonst langsam

    # ggf. sampeln für Speed
    sample = values
    if len(values) > sample_size:
        sample = resample(values, n_samples=sample_size, random_state=0)

    for K in Ks:
        km = KMeans(n_clusters=K, n_init=10, random_state=0)
        labels = km.fit_predict(sample.reshape(-1, 1))
        score = silhouette_score(sample.reshape(-1, 1), labels)
        sil_scores.append((K, score))

    best_K_sil = max(sil_scores, key=lambda x: x[1])[0]

    return K_fd, best_K_sil, sil_scores


if __name__ == "__main__":
    base_path = "DataSets"
    results = []

    for i in range(4):
        file_path = os.path.join("training_emg.csv")
        K_fd, best_K_sil, sil_scores = level_recommendations(file_path)

        results.append((i, K_fd, best_K_sil))

    # -------------------
    # Ergebnis-Tabelle
    # -------------------
    print("\nEmpfohlene Level-Bereiche:\n")
    print("Datensatz | Mindest-Level (FD) | Natürliche Cluster (Silhouette)")
    print("--------------------------------------------------------------")
    for ds, fd, sil in results:
        print(f"Data{ds:1d}    | {fd:17d} | {sil:29d}")
