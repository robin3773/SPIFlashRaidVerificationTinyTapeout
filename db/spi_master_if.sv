// Simple SPI master-side interface with helper tasks for bit-level timing
interface spi_master_if;
  logic sclk;
  logic cs_n;
  logic mosi;
  logic miso;

  // Optional clocking block for monitors
  clocking cb @(posedge sclk);
    input miso;
    input mosi;
    input cs_n;
  endclocking

  modport master_mp (output sclk, output cs_n, output mosi, input miso);
  modport monitor_mp (input sclk, input cs_n, input mosi, input miso);
endinterface
