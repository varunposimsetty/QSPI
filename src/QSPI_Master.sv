`timescale 1ns/1ns
module QSPI_Master
(#parameter DATA_WIDTH = 8,
            CPOL = 1,
            CPHA = 0,
            ADDR_WIDTH = 24,
            DUMMY_CYCLES = 10

)
(
    input logic sys_clk,
    input logic nrst,
    input logic [1:0] sel_mode, // 00 - SPI, 01 - Dual, 10 - Quad
    input logic operation, // 0 - Read, 1 - write
    input logic trigger_transmission,
    input logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic chip_select,
    output logic sclk,
    inout  wire [3:0] IO
);

logic[DATA_WIDTH-1:0] data_buffer = {DATA_WIDTH{1'b0}};
enum {idle, transmit,finish} t_write_state;
t_write_state current_state = idle;
int i = 0;
logic [3:0] temp_io = 4{1'b0};


always_ff @(posedge sys_clk, negedge nrst)
    if(~nrst) begin 
        chip_select <= 1'b1;
        sclk <= 1'b0;
        data_buffer <= 0;
        i <= 0;
        temp_io <= {4{1'b0}};
        current_state <= idle;
        data_buffer <= 0;
    end else begin 
        if(current_state == idle) begin 
            if(trigger_transmission) begin 
                chip_select <= '0';
                sclk <= sys_clk;
                if(operation) begin
                    data_buffer <= wr_data;
                    current_state <= transmit;
                    i <= 0;
                end else begin 
                    data_buffer <= 0;
                    current_state <= transmit;
                    i <= 0;
                end
            end 
        end else if (current_state == transmit) begin
            if(sel_mode == 2'b00) begin
                if (operation) begin 
                    case (1'b1) 
                            (i >= 0 && i < DATA_WIDTH-1): begin 
                                temp_io[1] <= data_buffer[i];
                                i <= i + 1;
                            end 
                            (i == DATA_WIDTH-1) : begin 
                                temp_io[1] <= data_buffer[i];
                                i <= 0;
                                current_state <= finish;
                                chip_select <= 1;
                                sclk <= 0;
                            end 
                            default : begin 
                               // NULL
                            end
                    endcase

                end else begin 
                    // OPERATION FOR READ

                end 
            end else if(sel_mode == 2'b01) begin 
                if (operation) begin 
                    case (1'b1) 
                            (i >= 0 && i < DATA_WIDTH-2): begin 
                                temp_io[0] <= data_buffer[i];
                                temp_io[1] <= data_buffer[i+1];
                                i <= i + 2;
                            end 
                            (i == DATA_WIDTH-2) : begin 
                                temp_io[0] <= data_buffer[i];
                                temp_io[1] <= data_buffer[i+1];
                                i <= 0;
                                current_state <= finish;
                                chip_select <= 1;
                                sclk <= 0;
                            end 
                            default : begin 
                               // NULL
                            end
                    endcase
                end else begin 
                    // OPERATION FOR READ.
                end 
            end else begin 
                if (operation) begin 
                        case (1'b1) 
                            (i >= 0 && i < DATA_WIDTH-4): begin 
                                temp_io[0] <= data_buffer[i];
                                temp_io[1] <= data_buffer[i+1];
                                temp_io[2] <= data_buffer[i+2];
                                temp_io[3] <= data_buffer[i+3];
                                i <= i + 2;
                            end 
                            (i == DATA_WIDTH-4) : begin 
                                temp_io[0] <= data_buffer[i];
                                temp_io[1] <= data_buffer[i+1];
                                temp_io[2] <= data_buffer[i+2];
                                temp_io[3] <= data_buffer[i+3];
                                i <= 0;
                                current_state <= finish;
                                chip_select <= 1;
                                sclk <= 0;
                            end 
                            default : begin 
                               // NULL
                            end
                        endcase
                end else begin 
                    // OPERATION FOR READ.
                end 
            end 
        end else if(current_state == finish) begin
            current_state <= idle;
        end 
    end 
endmodule