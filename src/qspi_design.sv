`timescale 1ns/1ns

module QSPI_Master
(#parameter CPOL = 1, CPHA = 0, DATA_WIDTH = 8)
(
    input logic sys_clk,
    input logic rst_n,
    input logic [DATA_WIDTH-1 : 0] wr_data,
    input logic [1:0] sel_mode, // SPI - 00 / Dual SPI - 01 / Quad SPI - 03
    input logic operation, // read - 0 or write - 1 operation
    input logic trigger_transmission, // enable signal
    output logic [DATA_WIDTH-1 : 0] rd_data,
    output logic sck_out,
    output logic csb,
    inout wire IO_0,
    inout wire IO_1,
    inout wire IO_2,
    inout wire IO_3
);

enum {idle,working,finish} t_state;
t_state current_state = idle;
logic [3:0] drive_enable = {4{1'b0}};
logic [3:0] IO = {4{1'bz}};
logic [DATA_WIDTH-1:0] buffer = {DATA_WIDTH{1'b0}};


always_ff @(posedge sys_clk or negedge rst_n)
    if(~rst_n) begin  
        current_state <= idle;
        buffer <= 0;
        sck_out <= 1'bz;
        csb <= 0;
        drive_enable <= {4{1'b0}};
        IO <= {4{1'bz}};
    end else begin 
        if(trigger_transmission) begin 
            if (sel_mode == 2'b00) begin 
                if (operation) begin 
                    drive_enable <= 4'b0011;
                    current_state <= working;
                    buffer <= wr_data;

                end else begin
                    
                end
            end else if(sel_mode == 2'b01) begin 
                if (operation) begin 

                end else begin 

                

                end 


            end else if(sel_mode == 2'b10) begin 
                if (operation) begin 


                end else begin 


                end 



            end
        end
    end


    

assign IO_0 = drive_enable[0] ? IO[0] : 1'bz;
assign IO_1 = drive_enable[1] ? IO[1] : 1'bz;
assign IO_2 = drive_enable[2] ? IO[2] : 1'bz;
assign IO_3 = drive_enable[3] ? IO[3] : 1'bz;


endmodule