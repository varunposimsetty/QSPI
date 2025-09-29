`timescale 1ns/1ns

module QSPI_Master
(#parameter CPOL = 1, CPHA = 0, DATA_WIDTH = 8)
(
    input logic sys_clk,
    input logic rst_n,
    input logic [DATA_WIDTH-1 : 0] wr_data,
    output logic [DATA_WIDTH-1 : 0] rd_data,
    output logic sck_out,
    output logic csb,
    inout wire IO_0,
    inout wire IO_1,
    inout wire IO_2,
    inout wire IO_3
);

enum {idle,working,finish} state;


endmodule