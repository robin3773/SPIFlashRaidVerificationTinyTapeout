// raid_tests.sv - collection of all directed/random tests

// Utility to pack control register fields
function automatic byte mk_ctrl(raid_pkg::raid_mode_e mode,
                                bit r0_en, bit r1_en,
                                bit r0_sel, bit r1_sel,
                                bit host_sel);
  mk_ctrl = {1'b0, host_sel, r1_sel, r0_sel, r1_en, r0_en, mode};
endfunction

// 1. Reset Test ----------------------------------------------------------------
// 1. Reset Test ----------------------------------------------------------------
class spi_reset_test extends raid_base_test;
  function new(); super.new("spi_reset_test"); endfunction
  virtual task run(ref logic rst_n);
    byte expected[byte];
    start_env();
    apply_reset(rst_n);

    // Build expected reset map
    expected[ADDR0_START_H] = ADDR_START_RESET[23:16];
    expected[ADDR0_START_M] = ADDR_START_RESET[15:8];
    expected[ADDR0_START_L] = ADDR_START_RESET[7:0];
    expected[ADDR0_END_H]   = ADDR_END_RESET[23:16];
    expected[ADDR0_END_M]   = ADDR_END_RESET[15:8];
    expected[ADDR0_END_L]   = ADDR_END_RESET[7:0];
    expected[ADDR1_START_H] = ADDR_START_RESET[23:16];
    expected[ADDR1_START_M] = ADDR_START_RESET[15:8];
    expected[ADDR1_START_L] = ADDR_START_RESET[7:0];
    expected[ADDR1_END_H]   = ADDR_END_RESET[23:16];
    expected[ADDR1_END_M]   = ADDR_END_RESET[15:8];
    expected[ADDR1_END_L]   = ADDR_END_RESET[7:0];
    expected[CONTROL_REG]   = CONTROL_RESET;
    expected[STATUS_REG]    = 8'h03;

    // Read back all registers for reset value check
    foreach (expected[idx]) mgmt_read_check(idx, expected[idx]);

    // Program random values then reset again to confirm re-init
    mgmt_program(CONTROL_REG,   8'h55);
    mgmt_program(ADDR0_START_H, 8'hAA);
    mgmt_program(ADDR0_START_M, 8'hBB);
    mgmt_program(ADDR0_START_L, 8'hCC);
    mgmt_program(ADDR0_END_H,   8'hDD);
    mgmt_program(ADDR0_END_M,   8'hEE);
    mgmt_program(ADDR0_END_L,   8'hFF);
    mgmt_program(ADDR1_START_H, 8'h11);
    mgmt_program(ADDR1_START_M, 8'h22);
    mgmt_program(ADDR1_START_L, 8'h33);
    mgmt_program(ADDR1_END_H,   8'h44);
    mgmt_program(ADDR1_END_M,   8'h55);
    mgmt_program(ADDR1_END_L,   8'h66);

    apply_reset(rst_n);
    foreach (expected[idx]) mgmt_read_check(idx, expected[idx]);
  endtask
endclass

// 2. Register Read/Write -------------------------------------------------------
class spi_reg_rw_test extends raid_base_test;
  function new(); super.new("spi_reg_rw_test"); endfunction
  virtual task run(ref logic rst_n);
    byte rand_val;
    start_env();
    apply_reset(rst_n);
    program_default_cfg();
    for (int addr = ADDR0_START_H; addr <= CONTROL_REG; addr++) begin
      rand_val = $urandom_range(0, 255);
      mgmt_program(addr[7:0], rand_val);
      mgmt_read_check(addr[7:0], rand_val);
    end
  endtask
endclass

// 3. MAIN mode passthrough -----------------------------------------------------
class spi_main_mode_test extends raid_base_test;
  function new(); super.new("spi_main_mode_test"); endfunction
  virtual task run(ref logic rst_n);
    byte data[$];
    start_env();
    apply_reset(rst_n);
    program_default_cfg();
    // Read then write/verify on main flash
    host_read(0, 0, 24'h000100, 4);
    data = {8'hDE, 8'hAD, 8'hBE, 8'hEF};
    host_write(0, 24'h000104, data);
    host_read(0, 0, 24'h000104, data.size());
  endtask
endclass

// 4. SECONDARY mode routing ----------------------------------------------------
class spi_secondary_mode_test extends raid_base_test;
  function new(); super.new("spi_secondary_mode_test"); endfunction
  virtual task run(ref logic rst_n);
    byte data[$];
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SECONDARY, 0, 0, 0, 0, 0));
    host_read(0, 0, 24'h000200, 4);
    data = {8'h12, 8'h34};
    host_write(0, 24'h000210, data);
    host_read(0, 0, 24'h000210, data.size());
  endtask
endclass

// 5. SHARE default routing when ranges off ------------------------------------
class spi_share_default_test extends raid_base_test;
  function new(); super.new("spi_share_default_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SHARE, 0, 0, 0, 0, 0));
    host_read(0, 1, 24'h001000, 3);
    host_read(0, 0, 24'h002000, 3);
  endtask
endclass

// 6. SHARE range0 -> main ------------------------------------------------------
class spi_share_range0_main_test extends raid_base_test;
  function new(); super.new("spi_share_range0_main_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    // Range0: 0x000000-0x000FFF to main
    mgmt_program(ADDR0_START_H, 8'h00);
    mgmt_program(ADDR0_START_M, 8'h00);
    mgmt_program(ADDR0_START_L, 8'h00);
    mgmt_program(ADDR0_END_H,   8'h00);
    mgmt_program(ADDR0_END_M,   8'h0F);
    mgmt_program(ADDR0_END_L,   8'hFF);
    mgmt_program(CONTROL_REG,   mk_ctrl(MODE_SHARE, 1, 0, 0, 0, 0));
    host_read(0, 0, 24'h000123, 4);
  endtask
endclass

// 7. SHARE range1 -> secondary -------------------------------------------------
class spi_share_range1_secondary_test extends raid_base_test;
  function new(); super.new("spi_share_range1_secondary_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    // Range1: 0x00F000-0x00FFFF to secondary
    mgmt_program(ADDR1_START_H, 8'h00);
    mgmt_program(ADDR1_START_M, 8'h0F);
    mgmt_program(ADDR1_START_L, 8'h00);
    mgmt_program(ADDR1_END_H,   8'h00);
    mgmt_program(ADDR1_END_M,   8'h0F);
    mgmt_program(ADDR1_END_L,   8'hFF);
    mgmt_program(CONTROL_REG,   mk_ctrl(MODE_SHARE, 0, 1, 0, 1, 0));
    host_read(0, 1, 24'h00F010, 4);
  endtask
endclass

// 8. Outside-range -> default flash -------------------------------------------
class spi_share_default_select_test extends raid_base_test;
  function new(); super.new("spi_share_default_select_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    mgmt_program(ADDR0_START_H, 8'h00);
    mgmt_program(ADDR0_START_M, 8'h10);
    mgmt_program(ADDR0_START_L, 8'h00);
    mgmt_program(ADDR0_END_H,   8'h00);
    mgmt_program(ADDR0_END_M,   8'h10);
    mgmt_program(ADDR0_END_L,   8'hFF);
    mgmt_program(CONTROL_REG,   mk_ctrl(MODE_SHARE, 1, 0, 0, 0, 0));
    host_read(0, 0, 24'h000050, 3); // outside range -> default main
  endtask
endclass

// 9. SHARE write safety (only default flash updates) --------------------------
class spi_share_write_safety_test extends raid_base_test;
  function new(); super.new("spi_share_write_safety_test"); endfunction
  virtual task run(ref logic rst_n);
    byte data[$];
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SHARE, 1, 1, 0, 1, 0));
    data = {8'hCA, 8'hFE};
    host_write(0, 24'h001000, data); // write goes to default flash
    host_read(0, 0, 24'h001000, data.size());
  endtask
endclass

// 10. Host select switching ----------------------------------------------------
class spi_host_switch_test extends raid_base_test;
  function new(); super.new("spi_host_switch_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    // Use secondary host
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_MAIN, 0, 0, 0, 0, 1'b1));
    host_read(1, 0, 24'h000300, 4);
    // Back to main host
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_MAIN, 0, 0, 0, 0, 1'b0));
    host_read(0, 0, 24'h000304, 4);
  endtask
endclass

// 11. Unsupported opcode robustness -------------------------------------------
class spi_illegal_opcode_test extends raid_base_test;
  function new(); super.new("spi_illegal_opcode_test"); endfunction
  virtual task run(ref logic rst_n);
    byte tx[$];
    byte rx[$];
    start_env();
    apply_reset(rst_n);
    // Send opcode 0x9F (ID read) and observe no decode side-effects
    tx = {8'h9F, 8'h00, 8'h00, 8'h00};
    env.main_host_drv.transfer_bytes(tx, rx);
    host_read(0, 0, 24'h000010, 2); // sanity read afterwards
  endtask
endclass

// 12. Host contention detection -----------------------------------------------
class spi_host_contention_test extends raid_base_test;
  function new(); super.new("spi_host_contention_test"); endfunction
  virtual task run(ref logic rst_n);
    byte main_tx[$];
    byte sec_tx[$];
    byte rx[$];
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_MAIN, 0, 0, 0, 0, 1'b0));
    main_tx = {8'h03, 8'h00, 8'h00, 8'h00, 8'h00};
    sec_tx  = {8'h03, 8'h00, 8'h00, 8'h10, 8'h00};
    fork
      env.main_host_drv.transfer_bytes(main_tx, rx);
      env.sec_host_drv.transfer_bytes(sec_tx, rx);
    join
    host_read(0, 0, 24'h000000, 1);
  endtask
endclass

// 13. Invalid range (start > end) ---------------------------------------------
class spi_bad_range_test extends raid_base_test;
  function new(); super.new("spi_bad_range_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    // Start > End, should be ignored and fall back to default
    mgmt_program(ADDR0_START_H, 8'h10);
    mgmt_program(ADDR0_START_M, 8'hFF);
    mgmt_program(ADDR0_START_L, 8'h00);
    mgmt_program(ADDR0_END_H,   8'h00);
    mgmt_program(ADDR0_END_M,   8'h00);
    mgmt_program(ADDR0_END_L,   8'h10);
    mgmt_program(CONTROL_REG,   mk_ctrl(MODE_SHARE, 1, 0, 0, 0, 0));
    host_read(0, 0, 24'h000020, 2);
  endtask
endclass

// 14. Overlapping range priority ----------------------------------------------
class spi_overlap_range_test extends raid_base_test;
  function new(); super.new("spi_overlap_range_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    mgmt_program(ADDR0_START_H, 8'h00);
    mgmt_program(ADDR0_START_M, 8'h20);
    mgmt_program(ADDR0_START_L, 8'h00);
    mgmt_program(ADDR0_END_H,   8'h00);
    mgmt_program(ADDR0_END_M,   8'h2F);
    mgmt_program(ADDR0_END_L,   8'hFF);
    mgmt_program(ADDR1_START_H, 8'h00);
    mgmt_program(ADDR1_START_M, 8'h28);
    mgmt_program(ADDR1_START_L, 8'h00);
    mgmt_program(ADDR1_END_H,   8'h00);
    mgmt_program(ADDR1_END_M,   8'h2F);
    mgmt_program(ADDR1_END_L,   8'hFF);
    mgmt_program(CONTROL_REG,   mk_ctrl(MODE_SHARE, 1, 1, 0, 1, 0));
    host_read(0, 0, 24'h002800, 4); // should use range0 priority (main)
  endtask
endclass

// 15. Low-edge boundary --------------------------------------------------------
class spi_addr_low_test extends raid_base_test;
  function new(); super.new("spi_addr_low_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SHARE, 1, 0, 0, 0, 0));
    mgmt_program(ADDR0_START_H, 8'h00);
    mgmt_program(ADDR0_START_M, 8'h00);
    mgmt_program(ADDR0_START_L, 8'h00);
    mgmt_program(ADDR0_END_H,   8'h00);
    mgmt_program(ADDR0_END_M,   8'h00);
    mgmt_program(ADDR0_END_L,   8'h10);
    host_read(0, 0, 24'h000000, 4);
  endtask
endclass

// 16. High-edge boundary -------------------------------------------------------
class spi_addr_high_test extends raid_base_test;
  function new(); super.new("spi_addr_high_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SHARE, 0, 1, 0, 1, 0));
    mgmt_program(ADDR1_START_H, 8'hFF);
    mgmt_program(ADDR1_START_M, 8'hFF);
    mgmt_program(ADDR1_START_L, 8'h00);
    mgmt_program(ADDR1_END_H,   8'hFF);
    mgmt_program(ADDR1_END_M,   8'hFF);
    mgmt_program(ADDR1_END_L,   8'hFF);
    host_read(0, 1, 24'hFFFFFF, 4);
  endtask
endclass

// 17. Runtime reconfiguration safety ------------------------------------------
class spi_runtime_cfg_test extends raid_base_test;
  function new(); super.new("spi_runtime_cfg_test"); endfunction
  virtual task run(ref logic rst_n);
    start_env();
    apply_reset(rst_n);
    // Baseline in main
    host_read(0, 0, 24'h000400, 2);
    // Change mode mid-sim while idle
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SECONDARY, 0, 0, 0, 0, 0));
    host_read(0, 0, 24'h000400, 2);
  endtask
endclass

// 18. Randomized read/write routing -------------------------------------------
class spi_random_rw_test extends raid_base_test;
  function new(); super.new("spi_random_rw_test"); endfunction
  virtual task run(ref logic rst_n);
    byte data[$];
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SHARE, 1, 1, 0, 1, 0));
    repeat (10) begin
      bit is_rd = $urandom_range(0,1);
      bit [23:0] addr = $urandom_range(0, 16'h3FFF);
      int len = 1 + $urandom_range(0, 3);
      data.delete();
      for (int i=0; i<len; i++) data.push_back($urandom_range(0,255));
      if (is_rd)
        host_read(0, 0, addr, len);
      else
        host_write(0, addr, data);
    end
  endtask
endclass

// 19. Random host switching + mode mix ----------------------------------------
class spi_random_host_mode_test extends raid_base_test;
  function new(); super.new("spi_random_host_mode_test"); endfunction
  virtual task run(ref logic rst_n);
    byte data[$];
    bit use_secondary;
    start_env();
    apply_reset(rst_n);
    repeat (8) begin
      raid_mode_e m = raid_mode_e'($urandom_range(0,2));
      bit host_sel = $urandom_range(0,1);
      mgmt_program(CONTROL_REG, mk_ctrl(m, 1, 1, $urandom_range(0,1), $urandom_range(0,1), host_sel));
      use_secondary = host_sel;
      host_read(use_secondary, 0, $urandom_range(0, 16'h0FFF), 2);
    end
  endtask
endclass

// 20. Long stress stability ----------------------------------------------------
class spi_stress_test extends raid_base_test;
  function new(); super.new("spi_stress_test"); endfunction
  virtual task run(ref logic rst_n);
    byte data[$];
    start_env();
    apply_reset(rst_n);
    mgmt_program(CONTROL_REG, mk_ctrl(MODE_SHARE, 1, 1, 0, 1, 0));
    for (int i = 0; i < 50; i++) begin
      bit is_rd = $urandom_range(0,1);
      bit use_secondary = $urandom_range(0,1);
      bit fast = $urandom_range(0,1);
      bit [23:0] addr = $urandom_range(0, 24'h00FFFF);
      int len = 1 + $urandom_range(0, 7);
      data.delete();
      for (int j = 0; j < len; j++) data.push_back($urandom_range(0,255));
      if (is_rd)
        host_read(use_secondary, fast, addr, len);
      else
        host_write(use_secondary, addr, data);
    end
  endtask
endclass

// Factory helper ---------------------------------------------------------------
function automatic raid_base_test create_test_by_name(string name);
  raid_base_test t;
  if (name == "spi_reset_test") begin
    spi_reset_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_reg_rw_test") begin
    spi_reg_rw_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_main_mode_test") begin
    spi_main_mode_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_secondary_mode_test") begin
    spi_secondary_mode_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_share_default_test") begin
    spi_share_default_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_share_range0_main_test") begin
    spi_share_range0_main_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_share_range1_secondary_test") begin
    spi_share_range1_secondary_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_share_default_select_test") begin
    spi_share_default_select_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_share_write_safety_test") begin
    spi_share_write_safety_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_host_switch_test") begin
    spi_host_switch_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_illegal_opcode_test") begin
    spi_illegal_opcode_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_host_contention_test") begin
    spi_host_contention_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_bad_range_test") begin
    spi_bad_range_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_overlap_range_test") begin
    spi_overlap_range_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_addr_low_test") begin
    spi_addr_low_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_addr_high_test") begin
    spi_addr_high_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_runtime_cfg_test") begin
    spi_runtime_cfg_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_random_rw_test") begin
    spi_random_rw_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_random_host_mode_test") begin
    spi_random_host_mode_test tr;
    tr = new();
    t  = tr;
  end else if (name == "spi_stress_test") begin
    spi_stress_test tr;
    tr = new();
    t  = tr;
  end else begin
    spi_reset_test tr;
    tr = new();
    t  = tr;
    $display("Unknown TEST=%s, defaulting to spi_reset_test", name);
  end
  return t;
endfunction
