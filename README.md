# Hyperdimensional Computing (HDC) Controller

## Overview
This project implements a **hardware accelerator for Hyperdimensional Computing (HDC)** on FPGA.  
The system encodes input features into high-dimensional binary hypervectors, performs bundling (majority vote), and classifies them using associative memory.

It is designed for FPGA platforms (e.g., Xilinx Zynq Ultrascale+ devices such as the Ultra96-V2) with **AXI-based integration** into a processing system.  

The design is fully written in **VHDL** and consists of three major modules:
- **HDC_Controller**  
  Manages the overall flow: feature collection, accelerator control, bundling, similarity computation, majority updates, and associative memory writes.
- **Accelerator**  
  Encodes feature vectors into high-dimensional hypervectors using **Identity Memory (IM)** and **Continuous Memory (CM)**.
- **Associative Memory (AM)**  
  Stores class hypervectors and supports classification via Hamming distance.

---

## Features
- **Configurable parameters**:
  - `D`: Hypervector dimension (default 10000 bits)
  - `N`: Number of features (default 32)
  - `M`: Number of quantization levels in CIM (default 40)
- **Segmented architecture**:  
  Hypervectors are processed in **32-bit chunks**, enabling scalable BRAM usage.
- **Popcount-based Hamming distance**:  
  Efficient 4-bit lookup-table based population count.
- **FSM-driven control**:  
  Encodes, bundles, and compares hypervectors in sequential states.
- **AXI-compatible wrapper** for integration with ARM CPUs on Zynq devices.
- **Training & Testing mode**:  
  - Training: Update associative memory with thresholded majority hypervectors  
  - Testing: Classify input vectors against stored hypervectors

---

## Architecture

### Top-level: `HDC_Controller`
- Collects features (`feature_values`) via AXI.
- Controls the **Accelerator** to encode hypervectors.
- Accumulates multiple hypervectors into a **bundled result accumulator**.
- Computes **Hamming distance** between bundled result and AM entries.
- Selects the closest memory index (= predicted class).
- Performs **majority thresholding** to update class hypervectors during training.

### Accelerator
- Reads **IM** and **CM** hypervectors.
- For each feature:
  - Selects IM vector (position encoding).
  - Selects CM vector (quantized level encoding).
  - Computes XOR → produces feature hypervector.
- Accumulates feature hypervectors over all features.
- Produces one encoded hypervector per input sample.

### Memories
- **Identity Memory (IM)**  
  Stores random hypervectors per feature index.
- **Continuous Memory (CM)**  
  Stores random hypervectors per quantized level.
- **Associative Memory (AM)**  
  Stores trained class hypervectors.

---

## FSM States

### HDC_Controller
- **0**: Idle / feature loading  
- **1–3**: Fetch AM data  
- **4**: XOR and prepare Hamming distance  
- **5**: Compare current Hamming distance with minimum  
- **6**: Iterate over classes or finalize result  
- **7**: Majority accumulation (increment bit counters)  
- **9**: Thresholding (convert counters → binary majority vector)  
- **10**: Clear counters for next training class  

### Accelerator
- **0**: Idle (wait for start)  
- **1**: Prepare IM/CM addresses  
- **2**: Wait (BRAM latency)  
- **3**: XOR of IM and CM vectors, increment per-bit counters  
- **4**: Majority vote for one 32-bit chunk  
- **5**: Assemble `bundled_result` and output  

---

## Data Preparation

The system requires **three input files** containing the pre-generated hypervectors and feature data.  
Depending on whether you run the **Vivado simulation** or the **Vitis software version**, the handling differs.

### Required Files
- `position_vectors.txt` → Identity Memory hypervectors  
- `value_vectors.txt` → Continuous Memory hypervectors  
- `feature_values.txt` → Training/testing feature inputs  

All files must be placed in the same directory as the **Master project / Debugging folder**.

---

### Vivado Testbench Version
- The VHDL testbench loads `position_vectors.txt`, `value_vectors.txt`, and `feature_values.txt` directly.  
- Position and value vectors can be generated using the Python scripts:
  - `position_vectors_gen.py`
  - `value_vectors_gen.py`
- Training and test feature sets are prepared with:
  - `createfeaturefile.py` → splits dataset into training/testing sets based on labels and ensures equidistant sampling.

---

### Vitis (C/AXI) Version
- The `.txt` files are **converted into C arrays** and stored in:
  - `vectors_data.c`
- During execution, the software loads IM, CM, and features into the FPGA memories via AXI.  
- Training/testing data management:
  - `createfeaturefile.py` splits dataset based on labels and sample counts.
  - Results are compiled into `vectors_data.c`.

**Execution requirements:**
- Requires **JTAG connection** between host PC and FPGA board.  
- Program output is captured using a serial terminal such as **PuTTY**.  

---

## Workflow

```text
            +------------------+
            |   Dataset (CSV)  |
            +------------------+
                      |
                      v
            +------------------+
            | createfeaturefile.py
            |  → feature_values.txt
            +------------------+
               |             |
               |             v
               |    +---------------------+
               |    | value_vectors_gen.py|
               |    +---------------------+
               |             |
               |             v
               |    value_vectors.txt
               v
      +---------------------+
      | position_vectors_gen.py
      +---------------------+
               |
               v
    position_vectors.txt

    ------------------- Vivado -------------------
    • Files read directly by testbench
    • Simulation produces bundled_result

    ------------------- Vitis --------------------
    • .txt → converted to C arrays
    • Stored in vectors_data.c
    • Software loads data into FPGA via AXI
    • Output observed over JTAG / PuTTY
