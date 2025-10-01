`timescale 1ns/1ns
module QSPI_Master
#(parameter DATA_WIDTH = 8,
            CPOL = 1,
            CPHA = 0,
            CLOCK_DIVIDER = 1,
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
typedef enum {idle, transmit,done} t_write_state_e;
t_write_state_e current_state;
int i,clk_count = 0;
logic divided_clk = 0;
logic [3:0] temp_io = {4{1'b0}};
logic [3:0] enable_io = {4{1'b0}};
logic rd_data_valid,transaction_done = 1;

always_ff @(posedge sys_clk, negedge nrst)
    if (~nrst) begin 
        clk_count <= 0;
        divided_clk <= 0;
    end else begin 
        if (clk_count == CLOCK_DIVIDER-1) begin 
            divided_clk <= ~divided_clk;
            clk_count <= 0;
        end else begin 
            clk_count <= clk_count + 1;
        end 
    end 


always_ff @(posedge divided_clk, negedge nrst)
    if(~nrst) begin 
        chip_select <= 1'b1;
        data_buffer <= 0;
        i <= 0;
        temp_io <= {4{1'b0}};
        enable_io <= {4{1'b0}};
        current_state <= idle;
        rd_data_valid <= 0;
        transaction_done <= 1;
    end else begin 
        if(current_state == idle) begin 
            if(trigger_transmission && transaction_done) begin 
                chip_select <= 0;
                rd_data_valid <= 0;
                transaction_done <= 0;
                i <= 0;
                if(operation) begin
                    data_buffer <= wr_data;
                    current_state <= transmit;
                end else begin 
                    data_buffer <= 0;
                    current_state <= transmit;
                end
            end 
        end else if (current_state == transmit) begin
            if(sel_mode == 2'b00) begin
                if (operation) begin 
                    enable_io <= 4'b0001;
                    case (1'b1) 
                            (i >= 0 && i < DATA_WIDTH-1): begin 
                                temp_io[0] <= data_buffer[i];
                                i <= i + 1;
                            end 
                            (i == DATA_WIDTH-1) : begin 
                                temp_io[0] <= data_buffer[i];
                                i <= 0;
                                current_state <= done;
                                chip_select <= 1;
                            end 
                            default : begin 
                               // NULL
                            end
                    endcase

                end else begin 
                    // OPERATION FOR READ
                    enable_io <= 4'b0010;
                    case (1'b1)
                        (i >= 0 && i < DATA_WIDTH-1): begin 
                            data_buffer[i] <= IO[1];
                            i <= i + 1;
                        end 
                        (i == DATA_WIDTH-1) : begin 
                            data_buffer[i] <= IO[1];
                            i <= 0;
                            current_state <= done;
                            chip_select <= 1;
                            rd_data_valid <= 1;
                        end
                        default : begin 
                            // NULL
                        end 
                    endcase
                end 
            end else if(sel_mode == 2'b01) begin 
                enable_io <= 4'b0011;
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
                                current_state <= done;
                                chip_select <= 1;
                            end 
                            default : begin 
                               // NULL
                            end
                    endcase
                end else begin 
                    // OPERATION FOR READ.
                    enable_io <= {4{1'b0}};
                    case (1'b1)
                        (i >= 0 && i < DATA_WIDTH-1): begin 
                            data_buffer[i] <= IO[0];
                            data_buffer[i+1] <= IO[1];
                            i <= i + 2;
                        end 
                        (i == DATA_WIDTH-2) : begin 
                            data_buffer[i] <= IO[0];
                            data_buffer[i+1] <= IO[1];
                            i <= 0;
                            current_state <= done;
                            chip_select <= 1;
                            rd_data_valid <= 1;
                        end
                        default : begin 
                            // NULL
                        end 
                    endcase
                end 
            end else begin 
                enable_io <= {4{1'b1}};
                if (operation) begin 
                        case (1'b1) 
                            (i >= 0 && i < DATA_WIDTH-4): begin 
                                temp_io[0] <= data_buffer[i];
                                temp_io[1] <= data_buffer[i+1];
                                temp_io[2] <= data_buffer[i+2];
                                temp_io[3] <= data_buffer[i+3];
                                i <= i + 4;
                            end 
                            (i == DATA_WIDTH-4) : begin 
                                temp_io[0] <= data_buffer[i];
                                temp_io[1] <= data_buffer[i+1];
                                temp_io[2] <= data_buffer[i+2];
                                temp_io[3] <= data_buffer[i+3];
                                i <= 0;
                                current_state <= done;
                                chip_select <= 1;
                            end 
                            default : begin 
                               // NULL
                            end
                        endcase
                end else begin 
                    // OPERATION FOR READ.
                    enable_io <= {4{1'b0}};
                    case (1'b1)
                        (i >= 0 && i < DATA_WIDTH-1): begin 
                            data_buffer[i] <= IO[0];
                            data_buffer[i+1] <= IO[1];
                            data_buffer[i+2] <= IO[2];
                            data_buffer[i+3] <= IO[3];
                            i <= i + 4;
                        end 
                        (i == DATA_WIDTH-4) : begin 
                            data_buffer[i] <= IO[0];
                            data_buffer[i+1] <= IO[1];
                            data_buffer[i+2] <= IO[2];
                            data_buffer[i+3] <= IO[3];
                            i <= 0;
                            current_state <= done;
                            chip_select <= 1;
                            rd_data_valid <= 1;
                        end
                        default : begin 
                            // NULL
                        end 
                    endcase
                end 
            end 
        end else if(current_state == done) begin
            temp_io <= {4{1'b0}};
            current_state <= idle;
            transaction_done <= 1;
            if(operation == 0 && rd_data_valid == 1) begin 
                rd_data <= data_buffer;
                rd_data_valid <= 0;
            end 
        end 
    end 
    assign sclk = chip_select ? 1'b0 : divided_clk;
    assign IO[0] = enable_io[0] ? temp_io[0] : 1'bz;
    assign IO[1] = enable_io[1] ? temp_io[1] : 1'bz;
    assign IO[2] = enable_io[2] ? temp_io[2] : 1'bz;
    assign IO[3] = enable_io[3] ? temp_io[3] : 1'bz;
endmodule