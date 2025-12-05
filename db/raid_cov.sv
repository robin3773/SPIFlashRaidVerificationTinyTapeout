
// Functional coverage collector aligned with the Testplan spreadsheet
class raid_cov;

  covergroup cfg_cg;
    mode_cp: coverpoint mode_t { bins main = {MODE_MAIN};
                                 bins secondary = {MODE_SECONDARY};
                                 bins share = {MODE_SHARE}; }
    host_cp: coverpoint host_select { bins main = {1'b0}; bins secondary = {1'b1}; }
    range0_en_cp: coverpoint range0_en;
    range1_en_cp: coverpoint range1_en;
  endgroup

  covergroup route_cg;
    flash_cp: coverpoint flash_id { bins main = {0}; bins secondary = {1}; }
    opcode_cp: coverpoint opcode {
      bins read_std  = {8'h03};
      bins read_fast = {8'h0B};
      bins write     = {8'h02};
      bins other     = default;
    }
    range_hit: coverpoint range_hit_id { bins none = {-1}; bins r0 = {0}; bins r1 = {1}; }
    flash_opcode_cp: cross flash_cp, opcode_cp;
  endgroup

  // mirrored config bits for sampling
  raid_mode_e mode_t;
  bit host_select;
  bit range0_en;
  bit range1_en;

  // per-transaction state
  int flash_id;
  byte opcode;
  int range_hit_id; // -1 none, 0 range0, 1 range1

  function new();
    cfg_cg = new();
    route_cg = new();
    range_hit_id = -1;
  endfunction

  function void sample_cfg(raid_mode_e mode_t, bit host_sel, bit r0, bit r1);
    this.mode_t     = mode_t;
    this.host_select= host_sel;
    this.range0_en  = r0;
    this.range1_en  = r1;
    cfg_cg.sample();
  endfunction

  task sample_route(int flash_id, byte opcode, int range_hit_id);
    this.flash_id     = flash_id;
    this.opcode       = opcode;
    this.range_hit_id = range_hit_id;
    route_cg.sample();
  endtask
endclass
