#PrimeTime Script
set power_enable_analysis TRUE
set power_analysis_mode time_based

read_file -format verilog  ./IOTDF_syn.v
current_design IOTDF
link

read_sdf -load_delay net ./IOTDF_syn.v


## Measure  power
#report_switching_activity -list_not_annotated -show_pin

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F1.fsdb
update_power
report_power 
report_power > F1_7.power

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F2.fsdb
update_power
report_power
report_power >> F1_7.power

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F3.fsdb
update_power
report_power
report_power >> F1_7.power

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F4.fsdb
update_power
report_power
report_power >> F1_7.power

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F5.fsdb
update_power
report_power
report_power >> F1_7.power

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F6.fsdb
update_power
report_power
report_power >> F1_7.power

read_vcd  -strip_path test/u_IOTDF  ./IOTDF_F7.fsdb
update_power
report_power
report_power >> F1_7.power


