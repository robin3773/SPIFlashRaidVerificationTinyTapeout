`timescale 1ns/1ps


module testbench;

  initial begin
    $dumpfile("raid_tb.vcd");
    $dumpvars(0, testbench);
  end

  // Clocks and reset
  logic clk;
  logic rst_n;
  logic ena;
  initial begin
    clk = 0;
    forever #10 clk = ~clk; // 50 MHz
  end

  // SPI interfaces
  spi_master_if mgmt_if();
  spi_master_if main_host_if();
  spi_master_if sec_host_if();
  spi_slave_if  main_flash_if();
  spi_slave_if  sec_flash_if();

  // DUT pin bundles
  wire [7:0] ui_in;
  wire [7:0] uo_out;
  wire [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Connect UI inputs (hosts + mgmt)
  assign ui_in[0] = main_host_if.sclk;
  assign ui_in[1] = main_host_if.cs_n;
  assign ui_in[2] = main_host_if.mosi;
  assign ui_in[3] = sec_host_if.sclk;
  assign ui_in[4] = sec_host_if.cs_n;
  assign ui_in[5] = sec_host_if.mosi;
  assign ui_in[6] = mgmt_if.sclk;
  assign ui_in[7] = mgmt_if.cs_n;

  // Connect bidirectional IO inputs (into DUT)
  assign uio_in[0] = mgmt_if.mosi;
  assign uio_in[1] = main_flash_if.miso;
  assign uio_in[2] = sec_flash_if.miso;
  assign uio_in[7:3] = '0;

  // DUT instance (top module)
  tt_um_flash_raid_controller dut (
    .ui_in (ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena   (ena),
    .clk   (clk),
    .rst_n (rst_n)
  );

  // ena is tied high in silicon; drive high here
  assign ena = 1'b1;

  // Hook outputs back to interfaces
  assign main_host_if.miso = uo_out[0];
  assign sec_host_if.miso  = uo_out[1];
  assign mgmt_if.miso      = uo_out[2];

  assign main_flash_if.sclk = uo_out[3];
  assign main_flash_if.cs_n = uo_out[4];
  assign main_flash_if.mosi = uo_out[5];

  assign sec_flash_if.sclk = uo_out[6];
  assign sec_flash_if.cs_n = uo_out[7];

  // Secondary flash MOSI comes from bidir pin uio_out[3]
  assign sec_flash_if.mosi = uio_out[3];

  // Flash observation mailbox shared with scoreboard
  mailbox #(flash_obs_item) flash_obs_mbx;

  // Flash stubs (main = 0, secondary = 1)
  flash_stub #(.FLASH_ID(0)) u_flash_main (.spi(main_flash_if), .obs_mbx(flash_obs_mbx));
  flash_stub #(.FLASH_ID(1)) u_flash_sec  (.spi(sec_flash_if),  .obs_mbx(flash_obs_mbx));

  initial begin
    string testname;
    raid_base_test test;
    if (!$value$plusargs("TEST=%s", testname)) testname = "spi_reset_test";
    test = create_test_by_name(testname);
    flash_obs_mbx = test.env.flash_obs_mbx;
    test.set_vifs(mgmt_if.master_mp, main_host_if.master_mp, sec_host_if.master_mp);
    // Drive reset high initially
    rst_n = 1'b1;
    #1;
    test.run(rst_n);
    #1000;
    if (test.total_errors() == 0)
      $display("==== TEST %s PASSED ====", testname);
    else
      $display("==== TEST %s FAILED: %0d errors (SB=%0d, TEST=%0d) ====",
               testname, test.total_errors(), test.env.sb.error_count, test.test_errors);
    $finish;
  end
endmodule
