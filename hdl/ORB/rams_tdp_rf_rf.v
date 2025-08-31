module rams_tdp_rf_rf (
    clkA,
    clkB,
    enA,
    enB,
    weA,
    weB,
    addrA,
    addrB,
    diA,
    diB,
    doA,
    doB
);
  parameter WIDTH_G = 32;
  parameter SIZE = 64;
  parameter ADDRWIDTH = 6;
  parameter INIT_FILE = "NONE";
  input clkA, clkB, enA, enB, weA, weB;
  input [ADDRWIDTH - 1 : 0] addrA, addrB;
  input [WIDTH_G - 1 : 0] diA, diB;
  output [WIDTH_G - 1 : 0] doA, doB;
  reg [WIDTH_G - 1 : 0] ram[SIZE - 1 : 0];
  reg [WIDTH_G - 1 : 0] doA, doB;
  initial begin
    $readmemb(INIT_FILE, ram);
  end
  always @(posedge clkA) begin
    if (enA) begin
      if (weA) ram[addrA] <= diA;
      doA <= ram[addrA];
    end
  end
  always @(posedge clkB) begin
    if (enB) begin
      if (weB) ram[addrB] <= diB;
      doB <= ram[addrB];
    end
  end
endmodule
