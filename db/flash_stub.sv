
// Behavioral SPI flash stub supporting READ (0x03/0x0B) and WRITE (0x02)
module flash_stub #(parameter int FLASH_ID = 0)(
    spi_slave_if.flash_mp spi,
    ref mailbox #(raid_pkg::flash_obs_item) obs_mbx
);
  import raid_pkg::*;

  typedef enum logic [2:0] {IDLE, CMD, ADDR, DUMMY, DATA} state_e;
  state_e state;

  reg [7:0]  shift_in;
  reg [7:0]  shift_out;
  reg [7:0]  current_read_byte;
  reg [23:0] addr;
  int        bit_count;
  int        addr_bytes;
  byte       payload[$];
  bit        is_read_cmd;
  bit [7:0]  opcode;

  // Simple associative memory to keep model lightweight
  byte mem [int unsigned];

  initial begin
    spi.miso_drv = 1'b0;
    reset_fsm();
  end

  task reset_fsm();
    state       = IDLE;
    bit_count   = 0;
    addr_bytes  = 0;
    addr        = 24'h0;
    payload.delete();
    is_read_cmd = 0;
    opcode      = 8'h00;
  endtask

  // Initialize memory lazily on demand
  function byte read_mem(int unsigned a);
    if (!mem.exists(a)) mem[a] = default_flash_byte(a, FLASH_ID);
    return mem[a];
  endfunction

  // Rising edge handles input shifting and state transitions
  always @(posedge spi.sclk or posedge spi.cs_n) begin
    if (spi.cs_n) begin
      if (state != IDLE) begin
        flash_obs_item obs = new();
        obs.is_read  = is_read_cmd;
        obs.cmd      = opcode;
        obs.addr     = addr;
        obs.data     = payload;
        obs.flash_id = FLASH_ID;
        obs.end_time = $time;
        if (obs_mbx != null) obs_mbx.put(obs);
      end
      reset_fsm();
    end else begin
      shift_in = {shift_in[6:0], spi.mosi};
      bit_count++;
      if (bit_count == 8) begin
        bit_count = 0;
        case (state)
          IDLE: begin
            opcode      = shift_in;
            is_read_cmd = (shift_in == 8'h03 || shift_in == 8'h0B);
            state       = CMD;
          end
          CMD: begin
            addr[23:16] = shift_in;
            state       = ADDR;
            addr_bytes  = 1;
          end
          ADDR: begin
            if (addr_bytes == 1) addr[15:8] = shift_in;
            if (addr_bytes == 2) begin
              addr[7:0] = shift_in;
              state     = (opcode == 8'h0B) ? DUMMY : DATA;
              // preload shift_out for read path
              current_read_byte = read_mem(addr);
              shift_out         = current_read_byte;
            end
            addr_bytes++;
          end
          DUMMY: begin
            state     = DATA;
            current_read_byte = read_mem(addr);
            shift_out         = current_read_byte;
          end
          DATA: begin
            if (is_read_cmd) begin
              // capture byte just served, then advance
              payload.push_back(current_read_byte);
              addr++;
              current_read_byte = read_mem(addr);
              shift_out         = current_read_byte;
            end else begin
              // program writes into memory
              mem[addr] = shift_in;
              payload.push_back(shift_in);
              addr++;
            end
          end
          default: ;
        endcase
      end
    end
  end

  // Drive MISO on falling edge so master samples on rising edge (mode 0)
  always @(negedge spi.sclk) begin
    if (!spi.cs_n && is_read_cmd && state == DATA) begin
      spi.miso_drv <= shift_out[7];
      shift_out    <= {shift_out[6:0], 1'b0};
    end else begin
      spi.miso_drv <= 1'b0;
    end
  end
endmodule
