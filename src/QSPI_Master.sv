`timescale 1ns/1ns
module QSPI_Master
#(parameter DATA_WIDTH = 8,
            CPOL = 0,
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
//CLK VARIABLES
int clk_count;
int transmit_count;
logic divided_clk = 0;
typedef enum logic [1:0] { IDLE, TRANSMISSION, FINISH} state_t;
state_t current_state;
logic transaction_done;
logic [3:0] enable_io,io_int = {4{1'b0}};
logic [DATA_WIDTH-1:0] data_buffer = 0;
logic operation_sync;
logic [1:0] sel_mode_sync;


//CLOCK GENERATION 
always_ff @(posedge sys_clk, negedge nrst) begin 
    if(~nrst) begin 
        clk_count <= 0;
        divided_clk <= 0;
    end else begin 
        if(clk_count == CLOCK_DIVIDER-1) begin 
            divided_clk <= ~divided_clk;
            clk_count <= 0;
        end else begin
            clk_count <= clk_count + 1;
        end
    end 
end 

// CONTROL SIGNALS 
always_ff @(posedge divided_clk or negedge nrst) begin 
    if(~nrst) begin 
        current_state <= IDLE;
        chip_select <= 1'b1;
        transaction_done <= 1'b1;
        data_buffer <= 0;
        transmit_count <= DATA_WIDTH-1;
    end else begin 
        if(current_state == IDLE) begin 
            transmit_count <= DATA_WIDTH-1;
           if(trigger_transmission && transaction_done) begin 
                operation_sync <= operation;
                sel_mode_sync <= sel_mode;
                chip_select <= 0;
                transaction_done <= 0;
                if(operation) begin 
                    data_buffer <= wr_data;
                end else begin 
                    data_buffer <= 0;
                end 
                current_state <= TRANSMISSION;
           end
        end else if (current_state == TRANSMISSION) begin 
            if (sel_mode_sync == 2'b00) begin 
                if(transmit_count == 0) begin 
                    //transmit_count <= DATA_WIDTH-1;
                    chip_select <= 1;
                    current_state <= FINISH;
                end else begin 
                    transmit_count <= transmit_count - 1;
                end 
            end else if (sel_mode_sync == 2'b01) begin 
                if(transmit_count == 1) begin 
                    //transmit_count <= DATA_WIDTH-1;
                    chip_select <= 1;
                    current_state <= FINISH;
                end else begin 
                    transmit_count <= transmit_count - 2;
                end 
            end else if (sel_mode_sync == 2'b10) begin 
                if(transmit_count == 3) begin 
                    //transmit_count <= DATA_WIDTH-1;
                    chip_select <= 1;
                    current_state <= FINISH;
                end else begin 
                    transmit_count <= transmit_count - 4;
                end 
            end   
        end else if (current_state == FINISH) begin 
            transmit_count <= DATA_WIDTH-1;
            if(~operation_sync) begin 
                rd_data <= data_buffer;
            end
            transaction_done <= 1;
            data_buffer <= 0;
            current_state <= IDLE;
        end 
    end 
end 


// WRITE OPERATION
always_ff @(negedge sclk or negedge nrst) begin 
    if(~nrst) begin 
        enable_io <= 0;
        io_int <= 0;
    end else begin 
        if(operation_sync) begin 
            if(sel_mode_sync == 2'b00) begin 
                enable_io <= 4'b0001;
                io_int[0] <= data_buffer[transmit_count];
            end else if(sel_mode_sync == 2'b01) begin 
                enable_io <= 4'b0011;
                io_int[0] <= data_buffer[transmit_count];
                io_int[1] <= data_buffer[transmit_count-1];
            end else if(sel_mode_sync == 2'b10) begin 
                enable_io <= {4{1'b1}};
                io_int[0] <= data_buffer[transmit_count];
                io_int[1] <= data_buffer[transmit_count-1];
                io_int[2] <= data_buffer[transmit_count-2];
                io_int[3] <= data_buffer[transmit_count-3];
            end 
        end 
    end 
end

// READ OPERATION
always_ff @(posedge sclk or posedge nrst) begin 
    if(~nrst) begin 
        enable_io <= 0;
        io_int <= 0;
    end else begin 
        if(~operation_sync) begin 
            if(sel_mode_sync == 2'b00) begin 
                //enable_io <= 4'b0010;
                data_buffer[transmit_count] <= IO[1];
            end else if(sel_mode_sync == 2'b01) begin 
                //enable_io <= 4'b0000;
                data_buffer[transmit_count] <= IO[0];
                data_buffer[transmit_count-1] <= IO[1];
            end else if(sel_mode_sync == 2'b10) begin 
                //enable_io <= {4{1'b0}};
                data_buffer[transmit_count] <= IO[0];
                data_buffer[transmit_count-1] <= IO[1];
                data_buffer[transmit_count-2] <= IO[2];
                data_buffer[transmit_count-3] <= IO[3];
            end 
        end 
    end 
end


assign sclk = chip_select ? CPOL : divided_clk;
assign IO[0] = enable_io[0] ? io_int[0] : 1'bz;
assign IO[1] = enable_io[1] ? io_int[1] : 1'bz;
assign IO[2] = enable_io[2] ? io_int[2] : 1'bz;
assign IO[3] = enable_io[3] ? io_int[3] : 1'bz;
endmodule
        