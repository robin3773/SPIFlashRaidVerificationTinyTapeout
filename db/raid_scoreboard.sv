
// Simple scoreboard that mirrors DUT routing rules and compares flash activity
class raid_scoreboard;

  mailbox #(raid_host_item) exp_host_mbx;
  mailbox #(flash_obs_item) flash_obs_mbx;

  // Mirror of management registers
  range_cfg_t range0_cfg;
  range_cfg_t range1_cfg;
  raid_mode_e mode;
  bit         host_select;
  raid_cov    cov;

  // Predictive flash memories
  byte main_mem[int unsigned];
  byte sec_mem[int unsigned];

  int error_count;

  function new(mailbox #(raid_host_item) exp_host_mbx,
               mailbox #(flash_obs_item) flash_obs_mbx,
               raid_cov cov = null);
    this.exp_host_mbx  = exp_host_mbx;
    this.flash_obs_mbx = flash_obs_mbx;
    this.cov           = cov;
    reset_cfg();
  endfunction

  function void reset_cfg();
    range0_cfg.start     = ADDR_START_RESET[23:0];
    range0_cfg.end_addr  = ADDR_END_RESET[23:0];
    range0_cfg.enable    = 1'b0;
    range0_cfg.flash_sel = FLASH_MAIN;
    range1_cfg           = range0_cfg;
    range1_cfg.flash_sel = FLASH_MAIN;
    mode                 = MODE_MAIN;
    host_select          = 1'b0;
    error_count          = 0;
    main_mem.delete();
    sec_mem.delete();
  endfunction

  // Update mirrored config when mgmt writes are observed
  function void apply_mgmt_write(byte addr, byte data);
    case (addr)
      ADDR0_START_H: range0_cfg.start[23:16] = data;
      ADDR0_START_M: range0_cfg.start[15:8]  = data;
      ADDR0_START_L: range0_cfg.start[7:0]   = data;
      ADDR0_END_H:   range0_cfg.end_addr[23:16] = data;
      ADDR0_END_M:   range0_cfg.end_addr[15:8]  = data;
      ADDR0_END_L:   range0_cfg.end_addr[7:0]   = data;
      ADDR1_START_H: range1_cfg.start[23:16] = data;
      ADDR1_START_M: range1_cfg.start[15:8]  = data;
      ADDR1_START_L: range1_cfg.start[7:0]   = data;
      ADDR1_END_H:   range1_cfg.end_addr[23:16] = data;
      ADDR1_END_M:   range1_cfg.end_addr[15:8]  = data;
      ADDR1_END_L:   range1_cfg.end_addr[7:0]   = data;
      CONTROL_REG: begin
        mode        = raid_mode_e'(data[1:0]);
        range0_cfg.enable    = data[2];
        range1_cfg.enable    = data[3];
        range0_cfg.flash_sel = flash_sel_e'(data[4]);
        range1_cfg.flash_sel = flash_sel_e'(data[5]);
        host_select          = data[6];
      end
      default: ;
    endcase
  endfunction

  // Memory helpers
  function byte get_mem(flash_sel_e sel, int unsigned addr);
    case (sel)
      FLASH_MAIN: begin
        if (!main_mem.exists(addr)) main_mem[addr] = default_flash_byte(addr, 0);
        return main_mem[addr];
      end
      default: begin
        if (!sec_mem.exists(addr)) sec_mem[addr] = default_flash_byte(addr, 1);
        return sec_mem[addr];
      end
    endcase
  endfunction

  function void set_mem(flash_sel_e sel, int unsigned addr, byte data);
    if (sel == FLASH_MAIN) main_mem[addr] = data;
    else                   sec_mem[addr] = data;
  endfunction

  // Compute expected flash select given mirrored config and host transaction
  function flash_sel_e expected_flash(const ref raid_host_item item);
    flash_sel_e sel;
    sel = (mode == MODE_SECONDARY) ? FLASH_SEC : FLASH_MAIN; // default

    if (mode == MODE_SHARE && item.is_read) begin
      if (range0_cfg.enable &&
          item.addr >= range0_cfg.start &&
          item.addr <= range0_cfg.end_addr)
        sel = range0_cfg.flash_sel;
      else if (range1_cfg.enable &&
               item.addr >= range1_cfg.start &&
               item.addr <= range1_cfg.end_addr)
        sel = range1_cfg.flash_sel;
    end else if (mode == MODE_SHARE && !item.is_read) begin
      // Writes fall back to default selection
      sel = (mode == MODE_SECONDARY) ? FLASH_SEC : FLASH_MAIN;
    end
    return sel;
  endfunction

  task run();
    forever begin
      raid_host_item exp;
      flash_obs_item obs;
      flash_sel_e exp_flash;
      byte exp_data[$];
      exp_host_mbx.get(exp);
      flash_obs_mbx.get(obs);

      exp_flash = expected_flash(exp);

      // Build expected data using mirrored memory
      if (exp.is_read) begin
        for (int i = 0; i < exp.payload.size(); i++)
          exp_data.push_back(get_mem(exp_flash, exp.addr + i));
      end else begin
        // Update model immediately so subsequent reads see new values
        foreach (exp.payload[i]) set_mem(exp_flash, exp.addr + i, exp.payload[i]);
      end

      if (obs.flash_id !== exp_flash) begin
        $display("[%0t][SB] Flash select mismatch: expected %0d got %0d (%s)",
                 $time, exp_flash, obs.flash_id, exp.sprint());
        error_count++;
      end

      // Read data check
      if (exp.is_read) begin
        if (obs.data.size() != exp.payload.size()) begin
          $display("[%0t][SB] Read length mismatch exp=%0d got=%0d @0x%06x",
                   $time, exp.payload.size(), obs.data.size(), exp.addr);
          error_count++;
        end else begin
          foreach (exp.payload[i]) begin
            if (obs.data[i] !== exp_data[i]) begin
              $display("[%0t][SB] Read data mismatch @%0d exp=%02x got=%02x addr=0x%06x",
                       $time, i, exp_data[i], obs.data[i], exp.addr);
              error_count++;
            end
          end
        end
      end else begin
        // For writes, mirror data into expected payload then compare
        foreach (exp.payload[i]) begin
          if (i >= obs.data.size() || obs.data[i] !== exp.payload[i]) begin
            $display("[%0t][SB] Write payload mismatch idx%0d exp=%02x got=%02x addr=0x%06x",
                     $time, i, exp.payload[i],
                     i < obs.data.size() ? obs.data[i] : 8'hXX, exp.addr);
            error_count++;
          end
        end
      end

      if (cov != null) begin
        int range_hit = -1;
        if (range0_cfg.enable &&
            exp.addr >= range0_cfg.start &&
            exp.addr <= range0_cfg.end_addr) range_hit = 0;
        else if (range1_cfg.enable &&
                 exp.addr >= range1_cfg.start &&
                 exp.addr <= range1_cfg.end_addr) range_hit = 1;
        cov.sample_route(obs.flash_id, obs.cmd, range_hit);
      end
    end
  endtask
endclass
