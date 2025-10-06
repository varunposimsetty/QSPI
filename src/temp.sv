`timescale 1ns/1ns
module QSPI_Master
#(parameter DATA_WIDTH = 8,
            CPOL = 0,
            CPHA = 0,
            CLOCK_DIVIDER = 1,
            DUMMY_CYCLES = 0

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

//Clock Signals 
int clk_count,transmit_count,dummy_cycle_count,dummy_limit_sync,limit;
logic divided_clk;
//Control Signals 
typedef enum logic [1:0] { IDLE, TRANSMISSION, DUMMY, FINISH} state_t;
state_t current_state,next_state;
logic dummy_enable, dummy_cycles_done,transaction_done,read_done;
logic cpol_sync,cpha_sync,operation_sync;
logic [1:0] sel_mode_sync;
logic [3:0] enable_io,io_int;
logic [DATA_WIDTH-1:0] write_data_buffer,read_data_buffer;

// NEED TO DO
task automatic write_shift(
    input  logic [1:0] sel_mode_sync,
    input  logic [DATA_WIDTH-1:0] write_data_buffer,
    input  int transmit_count,
    output logic [3:0] io_int);
    case (sel_mode_sync)
        2'b00: io_int[0] = write_data_buffer[transmit_count];
        2'b01: begin
            io_int[0] = write_data_buffer[transmit_count];
            io_int[1] = write_data_buffer[transmit_count-1];
        end
        2'b10: begin
            io_int[0] = write_data_buffer[transmit_count];
            io_int[1] = write_data_buffer[transmit_count-1];
            io_int[2] = write_data_buffer[transmit_count-2];
            io_int[3] = write_data_buffer[transmit_count-3];
        end
    endcase
endtask 

task automatic read_shift(
    input logic [1:0] sel_mode_sync,
    input int transmit_count,
    input logic read_done,
    output logic [DATA_WIDTH-1:0] read_data_buffer);
    if(~read_done) begin 
    case(sel_mode_sync)
        2'b00: read_data_buffer[transmit_count] = IO[1];
        2'b01: begin
            read_data_buffer[transmit_count] = IO[0];
            read_data_buffer[transmit_count-1] = IO[1];
        end
        2'b10: begin
            read_data_buffer[transmit_count] = IO[0];
            read_data_buffer[transmit_count-1] = IO[1];
            read_data_buffer[transmit_count-2] = IO[2];
            read_data_buffer[transmit_count-3] = IO[3];
        end    
    endcase
    end
endtask


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

always_ff @(posedge divided_clk or negedge nrst) begin 
    if(~nrst) begin 
        current_state <= IDLE;
        next_state <= IDLE;
        dummy_enable <= 0;
        transaction_done <= 1;
        cpol_sync <= 0;
        cpha_sync <= 0;
        operation_sync <= 0;
        sel_mode_sync <= 0;
        chip_select <= 1;
        dummy_cycle_count<= 0;
        dummy_limit_sync <= 0;
        write_data_buffer <= 0;
        rd_data <= 0;
    end else begin 
        current_state <= next_state;
        if(current_state == IDLE) begin 
            if(trigger_transmission && transaction_done) begin 
                transaction_done <= 0;
                cpol_sync <= CPOL;
                cpha_sync <= CPHA;
                operation_sync <= operation;
                sel_mode_sync <= sel_mode;
                dummy_enable <= (DUMMY_CYCLES != 0) && (!operation);
                dummy_limit_sync <= DUMMY_CYCLES;
                next_state <= TRANSMISSION;
            end
        end else if(current_state == TRANSMISSION) begin 
            chip_select <= 0;
            if(operation_sync) begin 
                write_data_buffer <= wr_data;
                case(sel_mode_sync)
                    2'b00 : begin enable_io <= 1; limit <= 0; end
                    2'b01 : begin enable_io <= 3; limit <= 1; end
                    2'b10 : begin enable_io <= {4{1'b1}}; limit <= 3; end
                endcase
            end else begin 
                enable_io <= {4{1'b0}};
                case(sel_mode_sync)
                    2'b00 : limit <= 0;
                    2'b01 : limit <= 1;
                    2'b10 : limit <= 3;
                endcase
            end    
            if (sel_mode_sync == 2'b00) begin 
                if(transmit_count == 0) begin 
                    if(dummy_enable) begin 
                        next_state <= DUMMY;
                    end else begin 
                        next_state <= FINISH;
                    end
                end
            end else if (sel_mode_sync == 2'b01) begin 
                if(transmit_count == 1) begin
                    if(dummy_enable) begin 
                        next_state <= DUMMY;
                    end else begin 
                        next_state <= FINISH;
                    end
                end
            end else if (sel_mode_sync == 2'b10) begin 
                if(transmit_count == 3) begin 
                    if(dummy_enable) begin 
                        next_state <= DUMMY;
                    end else begin 
                        next_state <= FINISH;
                    end
                end 
            end
        end else if (current_state == DUMMY) begin 
                if(dummy_cycles_done) begin
                    next_state <= FINISH;
                end
        end else if (current_state == FINISH) begin 
            chip_select <= 1;
            next_state <= IDLE;
            write_data_buffer <= 0;
            transaction_done <= 1;
            if(~operation_sync) begin 
                rd_data <= read_data_buffer;
            end
        end
    end 
end 


// POSEDGE CLOCK OPERATION --> READ : MODE 0,3 WRITE : 1,2
always_ff @(posedge sclk or negedge nrst) begin 
    if(~nrst) begin
        transmit_count <= DATA_WIDTH-1;
        dummy_cycles_done <= 0;
    end else begin 
        if(current_state == TRANSMISSION) begin
            if ((cpol_sync == 0 && cpha_sync == 0) || (cpol_sync == 1 && cpha_sync == 1)) begin
                read_shift(sel_mode_sync,transmit_count,read_data_buffer);
            end else if (((cpol_sync == 1 && cpha_sync == 0) || (cpol_sync == 0 && cpha_sync == 1))) begin
                 write_shift(sel_mode_sync, write_data_buffer, transmit_count, io_int);
            end
            if(transmit_count <= limit) begin
                read_done <= 1;
                transmit_count <= DATA_WIDTH-1;
            end else begin 
                transmit_count <= transmit_count - 1;
            end 
        end else if(current_state == DUMMY) begin 
            if (dummy_cycle_count == dummy_limit_sync-1) begin 
                dummy_cycle_count <= 0;
                dummy_cycles_done <= 1;
            end else begin
                dummy_cycle_count <= dummy_cycle_count + 1;
            end
        end else if (current_state == FINISH) begin 
                dummy_cycles_done <= 0;
                read_done <= 0;
        end
    end   
end 

// NEGEDGE CLOCK OPERATION --> READ : MODE 1,2 WRITE : 0,3
always_ff @(negedge sclk or negedge nrst) begin 
    if(~nrst) begin
        transmit_count <= DATA_WIDTH-1;
        dummy_cycles_done <= 0;
    end else begin 
        if(current_state == TRANSMISSION) begin
            if ((cpol_sync == 1 && cpha_sync == 0) || (cpol_sync == 0 && cpha_sync == 1)) begin
                read_shift(sel_mode_sync,transmit_count,read_done,read_data_buffer);
            end else if (((cpol_sync == 0 && cpha_sync == 0) || (cpol_sync == 1 && cpha_sync == 1))) begin
                 write_shift(sel_mode_sync, write_data_buffer, transmit_count, io_int);
            end
            if(transmit_count <= limit) begin
                read_done <= 1;
                transmit_count <= DATA_WIDTH-1;
            end else begin 
                transmit_count <= transmit_count - 1;
            end 
        end else if(current_state == DUMMY) begin 
            if (dummy_cycle_count == dummy_limit_sync-1) begin 
                dummy_cycle_count <= 0;
                dummy_cycles_done <= 1;
            end else begin
                dummy_cycle_count <= dummy_cycle_count + 1;
            end
        end else if (current_state == FINISH) begin 
                dummy_cycles_done <= 0;
                read_done <= 0;
        end
    end   
end 




assign sclk  = chip_select  ? cpol_sync : (cpol_sync ? ~divided_clk : divided_clk);
assign IO[0] = enable_io[0] ? io_int[0] : 1'bz;
assign IO[1] = enable_io[1] ? io_int[1] : 1'bz;
assign IO[2] = enable_io[2] ? io_int[2] : 1'bz;
assign IO[3] = enable_io[3] ? io_int[3] : 1'bz;

endmodule
