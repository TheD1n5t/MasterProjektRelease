// vectors_data.h
#ifndef VECTORS_DATA_H
#define VECTORS_DATA_H

#include <stdint.h>

#define VECTOR_BITS 10000
#define WORD_WIDTH 32
#define NUM_FEATURE_VALUES 32
#define WORDS_PER_VECTOR ((VECTOR_BITS + WORD_WIDTH - 1) / WORD_WIDTH)

extern const uint32_t value_vectors[40][WORDS_PER_VECTOR];
extern const uint32_t position_vectors[32][WORDS_PER_VECTOR];
extern const double feature_values_test[165600];

#endif
