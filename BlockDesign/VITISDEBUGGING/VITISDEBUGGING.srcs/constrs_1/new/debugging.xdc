# -------------------------------
# 1. Halte den Clock (nicht optimieren)
# -------------------------------
set_property KEEP true [get_nets design_1_i/zynq_ultra_ps_e_0/inst/pl_clk0]

# -------------------------------
# 2. MARK_DEBUG auf äußeren Netzen (nicht auf internen /U0/...!)
# -------------------------------
set_property MARK_DEBUG true [get_nets design_1_i/HDC_Controller_AXI_W_0/feature_dbg_valid]
set_property MARK_DEBUG true [get_nets {design_1_i/HDC_Controller_AXI_W_0/feature_dbg_class[0]}]
set_property MARK_DEBUG true [get_nets {design_1_i/HDC_Controller_AXI_W_0/feature_dbg_class[1]}]
set_property MARK_DEBUG true [get_nets {design_1_i/HDC_Controller_AXI_W_0/feature_dbg_class[2]}]

# feature_dbg_value[0..15]
foreach i {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15} {
    set_property MARK_DEBUG true [get_nets "design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[$i]"]
}

# -------------------------------
# 3. Debug Core: ILA erstellen und konfigurieren
# -------------------------------
create_debug_core u_ila_0 ila

# Eigenschaften
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]

# -------------------------------
# 4. Clock anschließen
# -------------------------------
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets design_1_i/zynq_ultra_ps_e_0/inst/pl_clk0]

# -------------------------------
# 5. Probes anschließen
# -------------------------------

# Probe 0: feature_dbg_class[2:0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 3 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_class[0] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_class[1] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_class[2] ]]

# Probe 1: feature_dbg_value[15:0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[0] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[1] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[2] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[3] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[4] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[5] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[6] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[7] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[8] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[9] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[10] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[11] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[12] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[13] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[14] \
    design_1_i/HDC_Controller_AXI_W_0/feature_dbg_value[15] ]]

# Probe 2: feature_dbg_valid
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets design_1_i/HDC_Controller_AXI_W_0/feature_dbg_valid]

# -------------------------------
# 6. Debug Hub konfigurieren
# -------------------------------
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub] ;# ggf. anpassen
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets design_1_i/zynq_ultra_ps_e_0/inst/pl_clk0]
