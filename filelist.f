// Verification + RTL file list for SPI RAID controller
// Usage: iverilog -g2012 -f filelist.f -o simv
../RAID_Verification/raid_pkg.sv
../RAID_Verification/spi_master_if.sv
../RAID_Verification/spi_slave_if.sv
../RAID_Verification/spi_master_driver.sv
../RAID_Verification/spi_master_monitor.sv
../RAID_Verification/raid_scoreboard.sv
../RAID_Verification/raid_cov.sv
../RAID_Verification/raid_env.sv
../RAID_Verification/raid_base_test.sv
../RAID_Verification/raid_tests.sv
../RAID_Verification/flash_stub.sv
../RAID_Verification/testbench.sv

../src/flash_mux_miso.v
../src/flash_mux_no_miso.v
../src/host_mux.v
../src/instruction_decoder.v
../src/serial_interface.v
../src/raider.v
../src/project.v
