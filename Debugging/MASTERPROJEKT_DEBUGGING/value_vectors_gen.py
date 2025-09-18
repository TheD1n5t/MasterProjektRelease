import random

# Parameter für die Vektoren
vector_size = 10000   # Dimension d
num_vectors = 40     # Anzahl Levels m
bit_flips = 250       # d/m = 100

# Generiere den ersten zufälligen Vektor
def generate_random_vector(size):
    return ''.join(random.choice('01') for _ in range(size))

# Flippe exakt 'flips' verschiedene Bits
def flip_bits(vector, flips):
    vector_list = list(vector)
    positions = random.sample(range(len(vector_list)), flips)  # garantiert verschiedene Positionen
    for pos in positions:
        vector_list[pos] = '1' if vector_list[pos] == '0' else '0'
    return ''.join(vector_list)

# Speichere die Vektoren in eine Datei
with open('value_vectors.txt', 'w') as f:
    # Erzeuge den ersten Vektor
    vector = generate_random_vector(vector_size)
    f.write(vector + '\n')
    
    # Erzeuge die restlichen Vektoren
    for _ in range(1, num_vectors):
        vector = flip_bits(vector, bit_flips)
        f.write(vector + '\n')

print("Done! Results saved to value-vectors.txt.")
