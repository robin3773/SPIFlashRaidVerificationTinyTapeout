// RAID verification package: common typedefs, register map, and lightweight transaction objects
package raid_pkg;

  // Control register mode encodings (matches serial_interface.v)
  typedef enum logic [1:0] {
    MODE_MAIN      = 2'b00,
    MODE_SECONDARY = 2'b01,
    MODE_SHARE     = 2'b10,
    MODE_RSVD      = 2'b11
  } raid_mode_e;

  typedef enum logic {
    FLASH_MAIN = 1'b0,
    FLASH_SEC  = 1'b1
  } flash_sel_e;

  // Register addresses per serial_interface.v
  localparam byte ADDR0_START_H = 8'h00;
  localparam byte ADDR0_START_M = 8'h01;
  localparam byte ADDR0_START_L = 8'h02;
  localparam byte ADDR0_END_H   = 8'h03;
  localparam byte ADDR0_END_M   = 8'h04;
  localparam byte ADDR0_END_L   = 8'h05;
  localparam byte ADDR1_START_H = 8'h06;
  localparam byte ADDR1_START_M = 8'h07;
  localparam byte ADDR1_START_L = 8'h08;
  localparam byte ADDR1_END_H   = 8'h09;
  localparam byte ADDR1_END_M   = 8'h0A;
  localparam byte ADDR1_END_L   = 8'h0B;
  localparam byte CONTROL_REG   = 8'h0C;
  localparam byte STATUS_REG    = 8'h0D;

  // Default register values taken from RTL reset
  localparam byte CONTROL_RESET = 8'h00;        // Mode MAIN, ranges disabled, host = main
  localparam byte STATUS_RESET  = 8'h00;        // Cleared on reset/CS high
  localparam int unsigned ADDR_START_RESET = 'h000000;
  localparam int unsigned ADDR_END_RESET   = 'hFFFFFF;

  typedef struct {
    logic [23:0] start;
    logic [23:0] end_addr;
    bit          enable;
    flash_sel_e  flash_sel;
  } range_cfg_t;

  // Transaction representing a management register operation
  class raid_mgmt_item;
    rand bit  is_write;     // 1 = write (0x02), 0 = read (0x03)
    rand byte addr;
    rand byte data;
    time      timestamp;

    function new();
      timestamp = $time;
    endfunction

    function string sprint();
      return $sformatf("%s @0x%02x data=0x%02x t=%0t",
                       is_write ? "WRITE" : "READ",
                       addr, data, timestamp);
    endfunction
  endclass

  // Host transaction (read/write to flash)
  class raid_host_item;
    rand bit        is_read;
    rand bit [7:0]  cmd;
    rand bit [23:0] addr;
    rand byte       payload[$]; // write data or expected read length placeholder
    string          origin;     // "main" or "secondary" host
    time            start_time;
    time            end_time;

    function new();
      origin     = "main";
      start_time = $time;
      end_time   = 0;
    endfunction

    function string sprint();
      string pay;
      foreach (payload[i]) pay = {pay, $sformatf("%02x ", payload[i])};
      return $sformatf("%s cmd=0x%02x addr=0x%06x len=%0d from=%s",
                       is_read ? "READ" : "WRITE", cmd, addr, payload.size(), origin);
    endfunction
  endclass

  // Observation coming from flash stub
  class flash_obs_item;
    bit        is_read;
    bit [7:0]  cmd;
    bit [23:0] addr;
    byte       data[$];
    int        flash_id; // 0=main,1=secondary
    time       start_time;
    time       end_time;

    function new();
      start_time = $time;
      end_time   = 0;
      flash_id   = 0;
    endfunction

    function string sprint();
      string pay;
      foreach (data[i]) pay = {pay, $sformatf("%02x ", data[i])};
      return $sformatf("flash%d %s cmd=0x%02x addr=0x%06x len=%0d",
                       flash_id, is_read ? "READ" : "WRITE", cmd, addr, data.size());
    endfunction
  endclass

  // Helper: default byte pattern used by flash stub
  function automatic byte default_flash_byte(int unsigned addr, int flash_id);
    // Deterministic pattern keeps scoreboard simple and repeatable
    default_flash_byte = flash_id ? ~addr[7:0] : addr[7:0];
  endfunction

endpackage
