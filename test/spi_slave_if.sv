// SPI slave-side interface used to connect flash stubs
interface spi_slave_if;
  logic sclk;
  logic cs_n;
  logic mosi;
  logic miso;

  // Drive strength is separated to avoid multiple drivers on miso
  logic miso_drv;
  assign miso = miso_drv;

  modport flash_mp  (input sclk, input cs_n, input mosi, output miso_drv);
  modport monitor_mp(input sclk, input cs_n, input mosi, input miso);
endinterface
