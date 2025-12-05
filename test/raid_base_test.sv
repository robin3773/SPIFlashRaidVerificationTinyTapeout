`include "raid_env.sv"
import raid_pkg::*;

// Base test offering reusable tasks for mgmt + host sequencing
class raid_base_test;

  string name;
  raid_env env;

  function new(string name = "raid_base_test");
    this.name = name;
    env = new();
  endfunction

  function void set_vifs(
    virtual spi_master_if.master_mp mgmt_vif,
    virtual spi_master_if.master_mp main_host_vif,
    virtual spi_master_if.master_mp sec_host_vif
  );
    env.connect_vifs(mgmt_vif, main_host_vif, sec_host_vif);
    env.build();
  endfunction

  task start_env();
    env.mgmt_drv.reset_lines();
    env.main_host_drv.reset_lines();
    env.sec_host_drv.reset_lines();
    env.start();
  endtask

  // Reset helper controls DUT reset net by reference
  task automatic apply_reset(ref logic rst_n, time hold = 100ns);
    rst_n = 1'b0;
    #(hold);
    rst_n = 1'b1;
    #(hold);
    env.sb.reset_cfg();
  endtask

  // Mgmt register utilities ----------------------------------------------------
  task automatic mgmt_program(byte addr, byte data);
    env.mgmt_drv.mgmt_write(addr, data);
    env.apply_mgmt_write(addr, data);
  endtask

  task automatic mgmt_read_check(byte addr, byte exp);
    byte rd;
    env.mgmt_drv.mgmt_read(addr, rd);
    if (rd !== exp) begin
      $display("[%0t][TEST %s] MGMT read mismatch @0x%02x exp=%02x got=%02x",
               $time, name, addr, exp, rd);
    end
  endtask

  // Host traffic helpers ------------------------------------------------------
  task automatic host_write(bit use_secondary, bit [23:0] addr, byte data[$]);
    raid_host_item item = new();
    item.is_read = 0;
    item.cmd     = 8'h02;
    item.addr    = addr;
    item.payload = data;
    item.origin  = use_secondary ? "secondary" : "main";
    env.exp_host_mbx.put(item);
    if (use_secondary)
      env.sec_host_drv.host_write(addr, data);
    else
      env.main_host_drv.host_write(addr, data);
  endtask

  task automatic host_read(bit use_secondary, bit fast_mode,
                           bit [23:0] addr, int unsigned nbytes);
    raid_host_item item = new();
    item.is_read = 1;
    item.cmd     = fast_mode ? 8'h0B : 8'h03;
    item.addr    = addr;
    // payload just holds expected length for scoreboard comparison
    for (int i = 0; i < nbytes; i++) item.payload.push_back(8'h00);
    item.origin  = use_secondary ? "secondary" : "main";
    env.exp_host_mbx.put(item);
    byte rd[$];
    if (use_secondary)
      env.sec_host_drv.host_read(fast_mode, addr, nbytes, rd);
    else
      env.main_host_drv.host_read(fast_mode, addr, nbytes, rd);
  endtask

  // Default configuration: MAIN mode, host=main, ranges disabled
  task automatic program_default_cfg();
    mgmt_program(CONTROL_REG, 8'h00);
    mgmt_program(ADDR0_START_H, 8'hFF);
    mgmt_program(ADDR0_START_M, 8'hFF);
    mgmt_program(ADDR0_START_L, 8'hFF);
    mgmt_program(ADDR0_END_H,   8'hFF);
    mgmt_program(ADDR0_END_M,   8'hFF);
    mgmt_program(ADDR0_END_L,   8'hFF);
    mgmt_program(ADDR1_START_H, 8'hFF);
    mgmt_program(ADDR1_START_M, 8'hFF);
    mgmt_program(ADDR1_START_L, 8'hFF);
    mgmt_program(ADDR1_END_H,   8'hFF);
    mgmt_program(ADDR1_END_M,   8'hFF);
    mgmt_program(ADDR1_END_L,   8'hFF);
  endtask

  // Extend in derived tests
  virtual task run(ref logic rst_n);
    $display("[%0t][TEST %s] Base run - override in derived class", $time, name);
  endtask
endclass
