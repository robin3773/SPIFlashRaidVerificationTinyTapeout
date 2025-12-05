import raid_pkg::*; 
// Lightweight SPI monitor that reconstructs command/address and data
class spi_master_monitor;

  virtual spi_master_if.monitor_mp vif;
  mailbox #(raid_host_item) mon_mbx;

  function new(virtual spi_master_if.monitor_mp vif,
               mailbox #(raid_host_item) mon_mbx);
    this.vif     = vif;
    this.mon_mbx = mon_mbx;
  endfunction

  task run();
    raid_host_item item;
    bit [7:0] shift_mosi;
    bit [7:0] shift_miso;
    int bit_count;
    int byte_count;
    item = null;
    forever begin
      @(posedge vif.cs_n or posedge vif.sclk);
      if (vif.cs_n) begin
        // Transaction ended
        if (item != null && (item.cmd != 8'h00 || item.payload.size() != 0))
          mon_mbx.put(item);
        item = null;
        bit_count  = 0;
        byte_count = 0;
      end else if (!vif.cs_n) begin
        if (item == null) begin
          item = new();
          item.start_time = $time;
        end
        // sample MOSI on rising edge, MISO on falling edge (mode 0)
        shift_mosi = {shift_mosi[6:0], vif.mosi};
        bit_count++;
        if (bit_count == 8) begin
          bit_count = 0;
          byte_count++;
          case (byte_count)
            1: item.cmd  = shift_mosi;
            2: item.addr[23:16] = shift_mosi;
            3: item.addr[15:8]  = shift_mosi;
            4: begin
              item.addr[7:0] = shift_mosi;
              item.is_read   = (item.cmd == 8'h03 || item.cmd == 8'h0B);
            end
            default: item.payload.push_back(shift_mosi);
          endcase
        end
      end
    end
  endtask
endclass
