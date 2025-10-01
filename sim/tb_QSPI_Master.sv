
`timescale 1ns/1ns

module tb_QSPI_Master;

    // Parameters
    localparam DATA_WIDTH = 8;
    localparam CLK_PERIOD = 10; // ns, corresponds to 100 MHz sys_clk

    // DUT signals
    logic sys_clk, nrst;
    logic [1:0] sel_mode;
    logic operation;
    logic trigger_transmission;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic chip_select, sclk;
    tri   [3:0] IO;

    // Slave model drive signals for read
    logic [3:0] IO_drv;
    logic [3:0] IO_drive_en;

    // Connect tri-state model: slave drives IO when enabled
    assign IO[0] = IO_drive_en[0] ? IO_drv[0] : 1'bz;
    assign IO[1] = IO_drive_en[1] ? IO_drv[1] : 1'bz;
    assign IO[2] = IO_drive_en[2] ? IO_drv[2] : 1'bz;
    assign IO[3] = IO_drive_en[3] ? IO_drv[3] : 1'bz;

    // Instantiate DUT
    QSPI_Master #(.DATA_WIDTH(DATA_WIDTH), .CPOL(0), .CPHA(0)) dut (
        .sys_clk(sys_clk),
        .nrst(nrst),
        .sel_mode(sel_mode),
        .operation(operation),
        .trigger_transmission(trigger_transmission),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .chip_select(chip_select),
        .sclk(sclk),
        .IO(IO)
    );

    // Clock generation
    initial sys_clk = 0;
    always #(CLK_PERIOD/2) sys_clk = ~sys_clk;

    // Simple slave behaviour for read mode
    // For each mode, load IO_drv with the bits to send MSB-first when chip_select is low
    logic [DATA_WIDTH-1:0] slave_shift;
    always @(negedge sclk) begin
        if (!chip_select && !operation) begin
            case (sel_mode)
                2'b00: begin
                    IO_drv[1] <= slave_shift[DATA_WIDTH-1];
                    slave_shift <= {slave_shift[DATA_WIDTH-2:0], 1'b0};
                end
                2'b01: begin
                    IO_drv[0] <= slave_shift[DATA_WIDTH-1];
                    IO_drv[1] <= slave_shift[DATA_WIDTH-2];
                    slave_shift <= {slave_shift[DATA_WIDTH-3:0], 2'b00};
                end
                2'b10: begin
                    IO_drv[0] <= slave_shift[DATA_WIDTH-1];
                    IO_drv[1] <= slave_shift[DATA_WIDTH-2];
                    IO_drv[2] <= slave_shift[DATA_WIDTH-3];
                    IO_drv[3] <= slave_shift[DATA_WIDTH-4];
                    slave_shift <= {slave_shift[DATA_WIDTH-5:0], 4'b0000};
                end
            endcase
        end
    end

    // Test sequence
    initial begin
        $dumpfile("./work/result.vcd");
        $dumpvars(0,tb_QSPI_Master);
        // Initial values
        nrst = 0;
        sel_mode = 2'b00;
        operation = 0;
        trigger_transmission = 0;
        wr_data = 0;
        IO_drive_en = 4'b0000;
        IO_drv = 4'b0000;
        slave_shift = 0;

        // Reset DUT
        #(CLK_PERIOD*5);
        nrst = 1;

        // ----------------------
        // Loop through all modes
        // ----------------------
        repeat (3) begin : mode_loop
            // WRITE
            operation = 1; // write mode
            wr_data = 8'hA5; // sample pattern
            trigger_transmission = 1;
            wait (dut.current_state == dut.FINISH);
            trigger_transmission = 0;
            #(CLK_PERIOD*5);

            // READ
            operation = 0; // read mode
            case (sel_mode)
                2'b00: begin IO_drive_en = 4'b0010; slave_shift = 8'h3C; end
                2'b01: begin IO_drive_en = 4'b0011; slave_shift = 8'h5A; end
                2'b10: begin IO_drive_en = 4'b1111; slave_shift = 8'hC3; end
            endcase
            trigger_transmission = 1;
            wait (dut.current_state == dut.FINISH);
            trigger_transmission = 0;
            IO_drive_en = 4'b0000;
            #(CLK_PERIOD*5);

            // Next mode
            sel_mode = sel_mode + 1;
        end

        // End simulation
        $stop;
    end

endmodule