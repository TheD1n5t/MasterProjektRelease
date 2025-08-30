// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Fri Jul 18 00:36:25 2025
// Host        : DESKTOP-U0V267S running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ u_ila_0_stub.v
// Design      : u_ila_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xczu3eg-sbva484-1-i
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2024.1" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15, probe16, probe17)
/* synthesis syn_black_box black_box_pad_pin="probe0[4:0],probe1[511:0],probe2[255:0],probe3[3:0],probe4[255:0],probe5[9:0],probe6[2:0],probe7[15:0],probe8[31:0],probe9[15:0],probe10[7:0],probe11[31:0],probe12[15:0],probe13[7:0],probe14[2:0],probe15[0:0],probe16[0:0],probe17[0:0]" */
/* synthesis syn_force_seq_prim="clk" */;
  input clk /* synthesis syn_isclock = 1 */;
  input [4:0]probe0;
  input [511:0]probe1;
  input [255:0]probe2;
  input [3:0]probe3;
  input [255:0]probe4;
  input [9:0]probe5;
  input [2:0]probe6;
  input [15:0]probe7;
  input [31:0]probe8;
  input [15:0]probe9;
  input [7:0]probe10;
  input [31:0]probe11;
  input [15:0]probe12;
  input [7:0]probe13;
  input [2:0]probe14;
  input [0:0]probe15;
  input [0:0]probe16;
  input [0:0]probe17;
endmodule
