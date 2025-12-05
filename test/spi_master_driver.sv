import raid_pkg::*;

// Bit-banging SPI master driver (mode 0) for mgmt + hosts
class spi_master_driver;

  virtual spi_master_if.master_mp vif;
  time half_period;

  function new(virtual spi_master_if.master_mp vif, time half_period = 5ns);
    this.vif         = vif;
    this.half_period = half_period;
  endfunction

  task reset_lines();
    vif.cs_n  <= 1'b1;
    vif.sclk  <= 1'b0;
    vif.mosi  <= 1'b0;
    #(2*half_period);
  endtask

  // Generic full-duplex byte transfer
  task automatic transfer_bytes(ref byte tx[$], output byte rx[$]);
    rx.delete();
    vif.cs_n <= 1'b0;
    #(half_period);
    foreach (tx[i]) begin
      byte rx_byte;
      for (int b = 7; b >= 0; b--) begin
        vif.mosi <= tx[i][b];
        #(half_period);
        vif.sclk <= 1'b1;
        rx_byte[b] = vif.miso;
        #(half_period);
        vif.sclk <= 1'b0;
      end
      rx.push_back(rx_byte);
    end
    vif.mosi <= 1'b0;
    #(half_period);
    vif.cs_n <= 1'b1;
    #(half_period);
  endtask

  // Management register write (0x02 command)
  task automatic mgmt_write(byte addr, byte data);
    byte tx[$];
    byte rx[$];
    tx.push_back(8'h02);
    tx.push_back(addr);
    tx.push_back(data);
    transfer_bytes(tx, rx);
  endtask

  // Management register read (0x03 command)
  task automatic mgmt_read(byte addr, output byte data);
    byte tx[$];
    byte rx[$];
    tx.push_back(8'h03);
    tx.push_back(addr);
    tx.push_back(8'h00); // dummy to capture read data
    transfer_bytes(tx, rx);
    data = rx.size() >= 3 ? rx[2] : 8'h00;
  endtask

  // Host READ (0x03/0x0B) utility
  task automatic host_read(bit fast_mode, bit [23:0] addr, int unsigned nbytes,
                           output byte data[$]);
    byte tx[$];
    byte rx[$];
    int skip;
    tx.push_back(fast_mode ? 8'h0B : 8'h03);
    tx.push_back(addr[23:16]);
    tx.push_back(addr[15:8]);
    tx.push_back(addr[7:0]);
    if (fast_mode) tx.push_back(8'h00); // dummy byte
    for (int i = 0; i < nbytes; i++) tx.push_back(8'h00);
    transfer_bytes(tx, rx);
    data.delete();
    // Skip command/address/dummy bytes when returning data
    skip = fast_mode ? 5 : 4;
    for (int i = skip; i < rx.size(); i++) data.push_back(rx[i]);
  endtask

  // Host WRITE (0x02) utility
  task automatic host_write(bit [23:0] addr, byte payload[$]);
    byte tx[$];
    byte rx[$];
    tx.push_back(8'h02);
    tx.push_back(addr[23:16]);
    tx.push_back(addr[15:8]);
    tx.push_back(addr[7:0]);
    foreach (payload[i]) tx.push_back(payload[i]);
    transfer_bytes(tx, rx);
  endtask
endclass
