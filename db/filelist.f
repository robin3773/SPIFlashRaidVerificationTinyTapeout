// Verification + RTL file list for SPI RAID controller
// Usage: iverilog -g2012 -f filelist.f -o simv
raid_pkg.sv
spi_master_if.sv
spi_slave_if.sv
spi_master_driver.sv
spi_master_monitor.sv
raid_cov.sv
raid_scoreboard.sv
raid_env.sv
raid_base_test.sv
raid_tests.sv
flash_stub.sv
testbench.sv




design.sv
raider.v
serial_interface.v
flash_mux_miso.v
flash_mux_no_miso.v
host_mux.v
instruction_decoder.v