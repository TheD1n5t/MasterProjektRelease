#include "xil_printf.h"
#include "xil_io.h"
#include "xparameters.h"

// Basisadresse deines AXI-Wrappers
#define HDC_CONTROLLER_BASE XPAR_HDC_CONTROLLER_AXI_W_0_BASEADDR

// Register Offsets
#define REG_CTRL             0x00
#define REG_FEATURE_VAL      0x04
#define REG_FEATURE_VALID    0x08
#define REG_MEM_SEL          0x0C
#define REG_MEM_WE           0x10
#define REG_MEM_ADDR         0x14
#define REG_MEM_DATA_IN      0x18
#define REG_EXPECTED_CLASS   0x1C
#define REG_SIMILARITY_OUT   0x20
#define REG_DONE             0x24
#define REG_EXPECTED_OUT     0x28
#define REG_MEM_DATA_OUT     0x2C

// Delay-Funktion
void short_delay() {
    for (volatile int i = 0; i < 1000; i++);
}

u32 write_and_read_am(u32 addr, u32 value) {
    xil_printf("Schreibe Wert 0x%08X an Adresse %u in AM...\r\n", value, addr);

    xil_printf("Setze Adresse...\r\n");
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_ADDR, addr);

    xil_printf("Setze Daten...\r\n");
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_DATA_IN, value);

    xil_printf("Setze mem_sel = 0b10...\r\n");
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_SEL, 0b10);

    xil_printf("Aktiviere mem_we = 1...\r\n");
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_WE, 1);
    xil_printf("Warte kurz...\r\n");
    for (volatile int i = 0; i < 1000; i++);

    xil_printf("Setze mem_we = 0...\r\n");
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_WE, 0);

    xil_printf("Setze Leseadresse...\r\n");
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_ADDR, addr);
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_SEL, 0b10);

    xil_printf("Lese aus mem_data_out...\r\n");
    u32 result = Xil_In32(HDC_CONTROLLER_BASE + REG_MEM_DATA_OUT);
    xil_printf(" -> Gelesen: 0x%08X\r\n", result);

    return result;
}


int main() {
    xil_printf("=== HDC AXI Test gestartet ===\r\n");

    u32 addr = 5;
    u32 value_to_write = 0xDEADBEEF;

    // Werte schreiben
    write_and_read_am(1, 0x11111111);
    write_and_read_am(2, 0x22222222);
    write_and_read_am(3, 0x33333333);

    // Nochmal nur lesen
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_ADDR, 2);
    Xil_Out32(HDC_CONTROLLER_BASE + REG_MEM_SEL, 0b10);
    for (volatile int i = 0; i < 1000; i++);
    u32 val = Xil_In32(HDC_CONTROLLER_BASE + REG_MEM_DATA_OUT);
    xil_printf("Manuell gelesen: 0x%08X\r\n", val);


    xil_printf("=== HDC AXI Test beendet ===\r\n");
    return 0;
}
