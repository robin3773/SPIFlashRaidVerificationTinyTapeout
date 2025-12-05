`include "spi_master_driver.sv"
`include "spi_master_monitor.sv"
`include "raid_scoreboard.sv"
`include "raid_cov.sv"
import raid_pkg::*;

// Minimal reusable environment tying drivers, monitors, scoreboard, and coverage together
class raid_env;

  // Virtual interfaces provided by testbench
  virtual spi_master_if.master_mp mgmt_vif;
  virtual spi_master_if.master_mp main_host_vif;
  virtual spi_master_if.master_mp sec_host_vif;

  // Drivers/monitors
  spi_master_driver     mgmt_drv;
  spi_master_driver     main_host_drv;
  spi_master_driver     sec_host_drv;

  // Scoreboard + coverage
  mailbox #(raid_host_item) exp_host_mbx;
  mailbox #(flash_obs_item) flash_obs_mbx;
  raid_scoreboard           sb;
  raid_cov                  cov;

  function new();
    exp_host_mbx  = new();
    flash_obs_mbx = new();
    cov           = new();
  endfunction

  function void connect_vifs(
    virtual spi_master_if.master_mp mgmt_vif,
    virtual spi_master_if.master_mp main_host_vif,
    virtual spi_master_if.master_mp sec_host_vif
  );
    this.mgmt_vif     = mgmt_vif;
    this.main_host_vif= main_host_vif;
    this.sec_host_vif = sec_host_vif;
    mgmt_drv      = new(mgmt_vif);
    main_host_drv = new(main_host_vif);
    sec_host_drv  = new(sec_host_vif);
  endfunction

  function void build();
    sb = new(exp_host_mbx, flash_obs_mbx, cov);
  endfunction

  // sample configuration coverage whenever control register changes
  function void apply_mgmt_write(byte addr, byte data);
    sb.apply_mgmt_write(addr, data);
    cov.sample_cfg(sb.mode, sb.host_select, sb.range0_cfg.enable, sb.range1_cfg.enable);
  endfunction

  task start();
    fork
      sb.run();
    join_none
  endtask
endclass
