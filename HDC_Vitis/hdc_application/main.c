#include <stdio.h>
#include <stdint.h>
#include "xparameters.h"
#include "xil_io.h"
#include "sleep.h"
#include <math.h>
#include "vectors_data.h"

#define HDC_BASEADDR            XPAR_HDC_CONTROLLER_AXI_WRAPPER_0_BASEADDR

#define REG_START               0x00
#define REG_FEATURE_VALUE       0x04
#define REG_EXPECTED_CLASS      0x08
#define REG_FEATURE_VALID       0x0C
#define REG_MEM_SEL             0x10
#define REG_MEM_WE              0x14
#define REG_MEM_ADDR            0x18
#define REG_MEM_DATA_IN         0x1C
#define REG_LOAD_MODE           0x20
#define REG_SIMILARITY_COUNTER  0x2C
#define REG_SIGNAL_COUNTER      0x34
#define REG_CLOSESTMEMORYINDEX  0x38   
#define REG_COMPARE_STATE       0x3C   



#define MEM_SEL_IM 0b00
#define MEM_SEL_CM 0b01
#define MEM_SEL_AM 0b10
// ARM Barrier-Makros für saubere Zeitmessung
#define DSB_SY() __asm__ volatile("dsb sy" ::: "memory")
#define ISB()    __asm__ volatile("isb" ::: "memory")


static inline uint64_t get_time_counter() {
    uint64_t val;
    asm volatile("mrs %0, cntvct_el0" : "=r"(val));
    return val;
}
static inline uint32_t get_time_freq() {
    uint32_t freq;
    asm volatile("mrs %0, cntfrq_el0" : "=r"(freq));
    return freq;
}



int main() {
   
    printf("Drücke ENTER zum Start...\n");
    getchar();
    printf("GO...\n");
    Xil_Out32(HDC_BASEADDR + REG_EXPECTED_CLASS, 4 << 8);
    for (volatile int d = 0; d < 100; ++d);
    // === Load Mode aktivieren ===
    Xil_Out32(HDC_BASEADDR + REG_LOAD_MODE, 1);
    for (volatile int d = 0; d < 100; ++d);

    
    // === AM-Befüllung ===
    // for (int class_index = 0; class_index < 5; ++class_index) {
    //     for (int word = 0; word < 313; ++word) {
    //         uint32_t addr = class_index * 313 + word;
    //         uint32_t data = compare_values[class_index][word];
    //         Xil_Out32(HDC_BASEADDR + REG_MEM_ADDR, addr);
    //         for (volatile int d = 0; d < 10; ++d);
    //         Xil_Out32(HDC_BASEADDR + REG_MEM_DATA_IN, data);
    //         for (volatile int d = 0; d < 10; ++d);
    //         Xil_Out32(HDC_BASEADDR + REG_MEM_SEL, MEM_SEL_AM); // <- wichtig!
    //         for (volatile int d = 0; d < 10; ++d);
    //         Xil_Out32(HDC_BASEADDR + REG_MEM_WE, 1);
    //         for (volatile int d = 0; d < 10; ++d);
    //         Xil_Out32(HDC_BASEADDR + REG_MEM_WE, 0);
    //         for (volatile int d = 0; d < 10; ++d);
    //     }
    // }
    // === IM-Befüllung ===
    for (int feature = 0; feature < 32; ++feature) {
        for (int word = 0; word < 313; ++word) {
            uint32_t addr = feature * 313 + word;
            uint32_t data = position_vectors[feature][word];
            Xil_Out32(HDC_BASEADDR + REG_MEM_ADDR, addr);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_DATA_IN, data);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_SEL, MEM_SEL_IM);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_WE, 1);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_WE, 0);
            for (volatile int d = 0; d < 10; ++d);
        }
    }

    // === CM-Befüllung ===
    for (int feature = 0; feature < 40; ++feature) {
        for (int word = 0; word < 313; ++word) {
            uint32_t addr = feature * 313 + word;
            uint32_t data = value_vectors[feature][word];
            Xil_Out32(HDC_BASEADDR + REG_MEM_ADDR, addr);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_DATA_IN, data);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_SEL, MEM_SEL_CM);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_WE, 1);
            for (volatile int d = 0; d < 10; ++d);
            Xil_Out32(HDC_BASEADDR + REG_MEM_WE, 0);
            for (volatile int d = 0; d < 10; ++d);
        }
    }
    
    // === Deaktiviere load_mode ===
    Xil_Out32(HDC_BASEADDR + REG_LOAD_MODE, 0);
    for (volatile int d = 0; d < 100; ++d);
    
  // Vor der Schleife einmalig:
    uint32_t freq = get_time_freq();
    double   inv_freq = 1.0 / (double)freq;

    uint64_t total_cycles = 0;
    uint64_t min_cycles   = (uint64_t)-1;
    uint64_t max_cycles   = 0;

    uint64_t t_all_start = get_time_counter();
   int class_results[5] = {0};
   for (int batch = 0; batch < 5176; ++batch) {
    // === 32 Features nacheinander senden ===
    
    for (int i = 0; i < 32; ++i) {
        int idx = batch * 32 + i;
        double value = feature_values_test[idx];
        double scaled_double = value * 10000.0 + 10000.0;

        // Benutzerdefiniertes Runden
        int32_t scaled;
        double frac_part = scaled_double - (int32_t)scaled_double;
        if (frac_part < 0.5) {
            scaled = (int32_t)scaled_double; // abrunden
        } else {
            scaled = (int32_t)scaled_double + 1; // aufrunden
        }
        if (scaled >= 55000) scaled = 55000;
        Xil_Out32(HDC_BASEADDR + REG_FEATURE_VALUE, (uint32_t)scaled);
        for (volatile int d = 0; d < 10; ++d);
        Xil_Out32(HDC_BASEADDR + REG_FEATURE_VALID, 1);
        for (volatile int d = 0; d < 10; ++d);
        Xil_Out32(HDC_BASEADDR + REG_FEATURE_VALID, 0);
        for (volatile int d = 0; d < 10; ++d);
    }
    
    
    DSB_SY(); ISB();
    uint64_t start = get_time_counter();
    // Start-Puls setzen
    Xil_Out32(HDC_BASEADDR + REG_START, 1);
    DSB_SY(); ISB();
    uint32_t prev_counter = Xil_In32(HDC_BASEADDR + REG_SIGNAL_COUNTER);
    while (Xil_In32(HDC_BASEADDR + REG_SIGNAL_COUNTER) == prev_counter) {
        
    }
    Xil_Out32(HDC_BASEADDR + REG_START, 0);
    DSB_SY(); ISB();
    uint64_t end = get_time_counter();
    uint64_t cycles = end - start;
    double   secs   = (double)cycles * inv_freq;

    total_cycles += cycles;
    if (cycles < min_cycles) min_cycles = cycles;
    if (cycles > max_cycles) max_cycles = cycles;

    if ((batch % 500) == 0) {
        printf("[Batch %5d] %llu cycles (%.6f s)\n",
               batch, (unsigned long long)cycles, secs);
    }
    // === alle 5 Batches: Closest Memory Index auslesen ===
    if ((batch+1) % 5 == 0 && batch > 4324) {
        uint32_t closest = Xil_In32(HDC_BASEADDR + REG_CLOSESTMEMORYINDEX);
        if (closest < 5) {
            class_results[closest]++;   // Zähler hochzählen
        }
        
        
    }
        
}
    
    printf("END...\n");
    printf("####################################\n");
    uint64_t t_all_end = get_time_counter();
    uint64_t all_cycles = t_all_end - t_all_start;
    double   all_secs   = (double)all_cycles * inv_freq;

    double avg_cycles = (double)total_cycles / 5176.0;
    printf("\n=== Performance-Report ===\n");
    printf("Timer-Frequenz: %u Hz\n", freq);
    printf("Pro Batch: min %llu, avg %.0f, max %llu cycles\n",
        (unsigned long long)min_cycles,
        avg_cycles,
        (unsigned long long)max_cycles);
    printf("Pro Batch: min %.6f s, avg %.6f s, max %.6f s\n",
        (double)min_cycles * inv_freq,
        avg_cycles * inv_freq,
        (double)max_cycles * inv_freq);
    printf("Gesamt: %llu cycles, %.6f s für 5176 Batches\n",
        (unsigned long long)all_cycles, all_secs);
    uint32_t sim_count = Xil_In32(HDC_BASEADDR + REG_SIMILARITY_COUNTER);
    printf("Similarity Counter (debug): %u\n", sim_count);
    uint32_t sig_count = Xil_In32(HDC_BASEADDR + REG_SIGNAL_COUNTER);
    printf("Signal Counter (debug): %u\n", sig_count);
    // Nach allen Batches: Ergebnisse ausgeben
    printf("\nErgebnisse pro Klasse:\n");
    for (int c = 0; c < 5; ++c) {
        printf("Klasse %d wurde %d Mal gewählt\n", c, class_results[c]);
    }
    
    return 0;
}