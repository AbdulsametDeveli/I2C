`timescale 1ns/1ps

module i2c_master #(
    parameter CLK_FREQ_HZ = 50000000,
    parameter I2C_FREQ_HZ = 400000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        i_start_transfer,
    input  wire [6:0]  i_address,
    input  wire [2:0]  i_n_bytes,
    input  wire        i_is_read,
    output wire        o_ready_for_cmd,
    input  wire        i_tx_data_valid,
    input  wire [7:0]  i_tx_data,
    output wire        o_tx_data_ready,
    output reg         o_rx_data_valid,
    output reg  [7:0]  o_rx_data,
    input  wire        i_rx_data_ready,
    output reg         o_transfer_done,
    output reg         o_ack_error,
    inout  wire        sda,
    inout  wire        scl
);

    // Verilog-2001 compatible clog2 function
    function integer clog2;
      input integer value;
      integer i;
      begin
        value = value - 1;
        for (i = 0; value > 0; i = i + 1)
          value = value >> 1;
        clog2 = i;
      end
    endfunction
    
    localparam PRESCALER = (CLK_FREQ_HZ / (I2C_FREQ_HZ * 4)) - 1;
    reg [clog2(PRESCALER+1)-1:0] cnt;
    reg scl_oe, sda_oe, sda_int=1, scl_clk_en=0;
    
    assign scl = scl_oe ? 1'b0 : 1'bz;
    assign sda = sda_oe ? sda_int : 1'bz;
    wire sda_in = sda;
    wire scl_rising_edge, scl_falling_edge;

    always @(posedge clk) begin
        if (rst) cnt <= 0;
        else if(scl_clk_en) if(cnt == PRESCALER) cnt <= 0; else cnt <= cnt + 1;
        else cnt <= 0;
    end
    
    assign scl_rising_edge  = scl_clk_en && (cnt == PRESCALER/2);
    assign scl_falling_edge = scl_clk_en && (cnt == PRESCALER);

    localparam [3:0] ST_IDLE=0, ST_START=1, ST_TX_BYTE=2, ST_RX_BYTE=3, ST_ACK_CHECK=4, ST_ACK_SEND=5, ST_STOP=6;
    reg [3:0]  state = ST_IDLE;
    reg [7:0]  shift_reg;
    reg [2:0]  bit_cnt;
    reg [2:0]  byte_cnt;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state <= ST_IDLE; scl_oe <= 0; sda_oe <= 0; sda_int <= 1; scl_clk_en <= 0;
            o_transfer_done <= 0; o_ack_error <= 0; o_rx_data_valid <= 0;
            bit_cnt <= 0;
        end else begin
            // Pulsed signals reset every cycle unless set
            o_transfer_done <= 0;
            if(o_rx_data_valid && i_rx_data_ready) o_rx_data_valid <= 0;

            case(state)
                ST_IDLE: begin
                    scl_clk_en <= 0;
                    o_ack_error <= 0;
                    if(i_start_transfer) begin
                        shift_reg <= {i_address, i_is_read};
                        byte_cnt  <= i_n_bytes;
                        bit_cnt   <= 0;
                        state     <= ST_START;
                    end
                end
                ST_START: begin
                    scl_clk_en <= 1;
                    sda_oe <= 1; sda_int <= 0; // START condition
                    if(scl_falling_edge) state <= ST_TX_BYTE;
                end
                ST_TX_BYTE: begin
                    sda_oe <= 1; // Driving data
                    if (scl_rising_edge) begin
                        scl_oe <= 0;
                    end else if(scl_falling_edge) begin
                        scl_oe <= 1;
                        if(o_tx_data_ready && i_tx_data_valid) shift_reg <= i_tx_data; // Latch new data if available
                        sda_int <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 1;
                        if(bit_cnt == 7) begin
                            bit_cnt <= 0; state <= ST_ACK_CHECK;
                        end
                    end
                end
                ST_ACK_CHECK: begin
                    sda_oe <= 0; // Release sda for slave
                    if (scl_rising_edge) begin
                        scl_oe <= 0; if(sda_in) o_ack_error <= 1;
                    end else if(scl_falling_edge) begin
                        scl_oe <= 1;
                        if(o_ack_error) state <= ST_STOP;
                        else begin
                            if(byte_cnt == 0) state <= (i_is_read) ? ST_RX_BYTE : ST_STOP;
                            else begin byte_cnt <= byte_cnt - 1; state <= (i_is_read) ? ST_RX_BYTE : ST_TX_BYTE; end
                        end
                    end
                end
                ST_RX_BYTE: begin
                    sda_oe <= 0;
                    if(scl_rising_edge) begin
                        scl_oe <= 0; shift_reg <= {shift_reg[6:0], sda_in};
                    end else if(scl_falling_edge) begin
                        scl_oe <= 1; bit_cnt <= bit_cnt + 1;
                        if(bit_cnt == 7) begin bit_cnt <= 0; o_rx_data <= {shift_reg[6:0],sda_in}; o_rx_data_valid <= 1; state <= ST_ACK_SEND; end
                    end
                end
                ST_ACK_SEND: begin
                    sda_oe <= 1; // Drive ack/nack
                    sda_int <= (byte_cnt == 0); // NACK if last byte, otherwise ACK
                    if(scl_rising_edge) begin scl_oe <= 0; end
                    else if(scl_falling_edge) begin
                        scl_oe <= 1;
                        state <= (byte_cnt == 0) ? ST_STOP : ST_RX_BYTE;
                    end
                end
                ST_STOP: begin
                    scl_clk_en <= 1; sda_oe <= 1; sda_int <= scl_rising_edge ? 1'b1 : 1'b0;
                    if(scl_rising_edge) begin o_transfer_done <= 1; state <= ST_IDLE; end
                end
            endcase
        end
    end
    assign o_ready_for_cmd = (state == ST_IDLE);
    assign o_tx_data_ready = (state == ST_ACK_CHECK) && (byte_cnt > 0) && !i_is_read && !o_ack_error;
endmodule