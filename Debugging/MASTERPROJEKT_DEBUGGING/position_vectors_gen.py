import random
import numpy as np

# Parameter
D = 10000       # Dimension
N = 32          # Anzahl Positionsvektoren
NUM_SETS = 10   # Anzahl zufälliger Sets, die getestet werden

def generate_random_vector(size):
    return [random.choice("01") for _ in range(size)]

def generate_im_set(n, d):
    return ["".join(generate_random_vector(d)) for _ in range(n)]

def hamming_distance(a, b):
    return sum(x != y for x, y in zip(a, b))

def evaluate_set(vectors):
    # berechne alle Hamming-Distanzen
    min_dist = D
    max_dist = 0
    distances = []
    for i in range(len(vectors)):
        for j in range(i+1, len(vectors)):
            d = hamming_distance(vectors[i], vectors[j])
            distances.append(d)
            if d < min_dist: min_dist = d
            if d > max_dist: max_dist = d
    mean = np.mean(distances)
    std  = np.std(distances)
    return min_dist, max_dist, mean, std

best_set = None
best_score = -1
best_stats = None

for k in range(NUM_SETS):
    im_set = generate_im_set(N, D)
    min_dist, max_dist, mean, std = evaluate_set(im_set)
    
    # Score = minimaler Abstand (wir wollen möglichst große Minimaldistanz)
    if min_dist > best_score:
        best_score = min_dist
        best_set = im_set
        best_stats = (min_dist, max_dist, mean, std)

print("Bestes Set gefunden:")
print(f"MinDist = {best_stats[0]}, MaxDist = {best_stats[1]}, "
      f"Mean = {best_stats[2]:.2f}, Std = {best_stats[3]:.2f}")

# Speichere bestes Set
with open("position-vectors_best.txt", "w") as f:
    for vec in best_set:
        f.write(vec + "\n")

print("Datei geschrieben: position-vectors_best.txt")
