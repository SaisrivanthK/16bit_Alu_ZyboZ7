## ---------------- Clock (125 MHz) ----------------
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 8.000 -name sys_clk [get_ports clk]

## ---------------- Onboard switches = ALU opcode ----------------
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]

## ---------------- Onboard buttons ----------------
## BTN0 clear selected input, BTN1 clear A and B, BTN2 backspace, BTN3 system reset
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]

## ---------------- Onboard LEDs (last key pressed) ----------------
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## ---------------- Pmod JA : Pmod KYPD ----------------
## Pins 1-4 = COL4..COL1 (driven), pins 7-10 = ROW4..ROW1 (inputs)
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports {kypd_col[3]}]
set_property -dict {PACKAGE_PIN L14 IOSTANDARD LVCMOS33} [get_ports {kypd_col[2]}]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports {kypd_col[1]}]
set_property -dict {PACKAGE_PIN K14 IOSTANDARD LVCMOS33} [get_ports {kypd_col[0]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {kypd_row[3]}]
set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {kypd_row[2]}]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {kypd_row[1]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {kypd_row[0]}]

## ---------------- Pmod JC : Pmod OLED (SSD1306, 128x32) ----------------
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports oled_cs]      ;# pin 1
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports oled_sdin]    ;# pin 2
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports oled_sclk]    ;# pin 4
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports oled_dc]      ;# pin 7
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports oled_res]     ;# pin 8
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports oled_vbatc]   ;# pin 9
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports oled_vddc]    ;# pin 10

## ---------------- Pmod JE : 4-switch Pmod (pins 1-4) ----------------
## ext_sw[0] = reset, ext_sw[1] = select A/B
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {ext_sw[0]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {ext_sw[1]}]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {ext_sw[2]}]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {ext_sw[3]}]

## ---------------- Timing ----------------
## Human-speed I/O
set_false_path -from [get_ports {sw[*] btn[*] ext_sw[*] kypd_row[*]}]
set_false_path -to   [get_ports {kypd_col[*] oled_* led[*]}]

## The combinational ALU result is only captured once every 256 clocks
set_multicycle_path -setup 250 -from [get_cells -quiet {a_reg_reg[*] b_reg_reg[*] sw_s2_reg[*]}] -to [get_cells -quiet {y_cap_reg[*] flg_cap_reg[*]}]
set_multicycle_path -hold  249 -from [get_cells -quiet {a_reg_reg[*] b_reg_reg[*] sw_s2_reg[*]}] -to [get_cells -quiet {y_cap_reg[*] flg_cap_reg[*]}]
