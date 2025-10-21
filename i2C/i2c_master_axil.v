`timescale 1ns/1ps

module i2c_master_axil #(
    parameter C_S_AXI_ADDR_WIDTH = 5,
    parameter C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                         S_AXI_ACLK,
    input  wire                         S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire                         S_AXI_AWVALID,
    output reg                          S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                         S_AXI_WVALID,
    output reg                          S_AXI_WREADY,
    output reg  [1:0]                   S_AXI_BRESP,
    output reg                          S_AXI_BVALID,
    input  wire                         S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire                         S_AXI_ARVALID,
    output reg                          S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg  [1:0]                   S_AXI_RRESP,
    output reg                          S_AXI_RVALID,
    input  wire                         S_AXI_RREADY,
    inout  wire sda,
    inout  wire scl
);
    localparam ADDR_I2C_NBY = 5'h00;
    localparam ADDR_I2C_ADR = 5'h04;
    localparam ADDR_I2C_RDR = 5'h08;
    localparam ADDR_I2C_TDR = 5'h0C;
    localparam ADDR_I2C_CFG = 5'h10;

    reg [31:0] i2c_nby_reg, i2c_adr_reg, i2c_rdr_reg, i2c_tdr_reg, i2c_cfg_reg;

    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_lat, araddr_lat;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 0; S_AXI_WREADY <= 0; S_AXI_BVALID <= 0; S_AXI_BRESP <= 0;
            S_AXI_ARREADY <= 0; S_AXI_RVALID <= 0; S_AXI_RRESP <= 0; S_AXI_RDATA <= 0;
            i2c_nby_reg <= 0; i2c_adr_reg <= 0; i2c_rdr_reg <= 0; i2c_tdr_reg <= 0; i2c_cfg_reg <= 0;
        end else begin
            if (~S_AXI_AWREADY && S_AXI_AWVALID) begin S_AXI_AWREADY <= 1'b1; awaddr_lat <= S_AXI_AWADDR; end else S_AXI_AWREADY <= 1'b0;
            if (~S_AXI_WREADY && S_AXI_WVALID) S_AXI_WREADY <= 1'b1; else S_AXI_WREADY <= 1'b0;
            if (S_AXI_AWREADY&&S_AXI_AWVALID && S_AXI_WREADY&&S_AXI_WVALID && ~S_AXI_BVALID) begin
                case (awaddr_lat)
                    ADDR_I2C_NBY: i2c_nby_reg <= S_AXI_WDATA;
                    ADDR_I2C_ADR: i2c_adr_reg <= S_AXI_WDATA;
                    ADDR_I2C_TDR: i2c_tdr_reg <= S_AXI_WDATA;
                    ADDR_I2C_CFG: begin
                         i2c_cfg_reg[0] <= i2c_cfg_reg[0] | S_AXI_WDATA[0];
                         i2c_cfg_reg[1] <= i2c_cfg_reg[1] & S_AXI_WDATA[1];
                         i2c_cfg_reg[2] <= i2c_cfg_reg[2] | S_AXI_WDATA[2];
                         i2c_cfg_reg[3] <= i2c_cfg_reg[3] & S_AXI_WDATA[3];
                    end
                    default: ;
                endcase
                S_AXI_BVALID <= 1'b1; S_AXI_BRESP <= 2'b00;
            end else if (S_AXI_BVALID && S_AXI_BREADY) S_AXI_BVALID <= 0;
            if (~S_AXI_ARREADY && S_AXI_ARVALID) begin S_AXI_ARREADY <= 1'b1;  araddr_lat <= S_AXI_ARADDR; end else S_AXI_ARREADY <= 0;
            if (S_AXI_ARREADY&&S_AXI_ARVALID && ~S_AXI_RVALID) begin
                case (araddr_lat)
                    ADDR_I2C_NBY: S_AXI_RDATA <= i2c_nby_reg; ADDR_I2C_ADR: S_AXI_RDATA <= i2c_adr_reg;
                    ADDR_I2C_RDR: S_AXI_RDATA <= i2c_rdr_reg; ADDR_I2C_TDR: S_AXI_RDATA <= i2c_tdr_reg;
                    ADDR_I2C_CFG: S_AXI_RDATA <= i2c_cfg_reg; default: S_AXI_RDATA <= 32'hDEADBEEF;
                endcase
                S_AXI_RVALID <= 1'b1; S_AXI_RRESP <= 2'b00;
            end else if (S_AXI_RVALID && S_AXI_RREADY) S_AXI_RVALID <= 0;
        end
    end

    wire rst = ~S_AXI_ARESETN;
    reg core_start_transfer; reg [6:0] core_address; reg [2:0] core_n_bytes; reg core_is_read_latch;
    wire core_ready_for_cmd; reg core_tx_data_valid; reg [7:0] core_tx_data; wire core_tx_data_ready;
    wire core_rx_data_valid; wire [7:0] core_rx_data; reg core_rx_data_ready;
    wire core_transfer_done; wire core_ack_error;

    localparam FSM_IDLE = 3'd0, FSM_START = 3'd1, FSM_TRANSFER = 3'd2, FSM_WAIT_DONE = 3'd3, FSM_FINISH = 3'd4;
    reg [2:0] state = FSM_IDLE;
    reg [1:0] byte_count_down;
    reg [1:0] rx_byte_count_up;
    wire [1:0] nby_clamped = (i2c_nby_reg == 0) ? 2'd0 : (i2c_nby_reg > 4) ? 2'd3 : (i2c_nby_reg - 1);
    
    always @(posedge S_AXI_ACLK or posedge rst) begin
        if(rst) begin
            state <= FSM_IDLE;
            core_start_transfer <= 0; core_tx_data_valid <= 0; core_rx_data_ready <= 0;
            byte_count_down <= 0; i2c_rdr_reg <= 0;
        end else begin
            core_start_transfer <= 0; core_tx_data_valid <= 0;
            
            if (core_rx_data_valid) begin
                 core_rx_data_ready <= 1;
                 case (rx_byte_count_up)
                     2'd0: i2c_rdr_reg[7:0]   <= core_rx_data;
                     2'd1: i2c_rdr_reg[15:8]  <= core_rx_data;
                     2'd2: i2c_rdr_reg[23:16] <= core_rx_data;
                     2'd3: i2c_rdr_reg[31:24] <= core_rx_data;
                 endcase
                 rx_byte_count_up <= rx_byte_count_up + 1;
            end else core_rx_data_ready <= 0;
            
            case(state)
                FSM_IDLE: begin
                    if (i2c_cfg_reg[0]) begin
                        i2c_cfg_reg[0] <= 0; i2c_cfg_reg[1] <= 0; core_is_read_latch <= 0; state <= FSM_START;
                    end else if (i2c_cfg_reg[2]) begin
                        i2c_cfg_reg[2] <= 0; i2c_cfg_reg[3] <= 0; core_is_read_latch <= 1; i2c_rdr_reg <= 0; state <= FSM_START;
                    end
                end
                FSM_START: begin
                    core_start_transfer <= 1;
                    core_address <= i2c_adr_reg[6:0];
                    core_n_bytes <= {1'b0, nby_clamped};
                    byte_count_down <= nby_clamped;
                    rx_byte_count_up <= 0;
                    state <= FSM_TRANSFER;
                end
                FSM_TRANSFER: begin
                    if (core_is_read_latch) begin if (core_transfer_done || core_ack_error) state <= FSM_FINISH; end
                    else begin
                        if (core_tx_data_ready) begin
                            core_tx_data_valid <= 1;
                            case (nby_clamped - byte_count_down)
                                2'd0: core_tx_data <= i2c_tdr_reg[7:0];
                                2'd1: core_tx_data <= i2c_tdr_reg[15:8];
                                2'd2: core_tx_data <= i2c_tdr_reg[23:16];
                                2'd3: core_tx_data <= i2c_tdr_reg[31:24];
                            endcase
                            if (byte_count_down == 0) state <= FSM_WAIT_DONE; else byte_count_down <= byte_count_down - 1;
                        end
                    end
                end
                FSM_WAIT_DONE: if (core_transfer_done || core_ack_error) state <= FSM_FINISH;
                FSM_FINISH: begin if (core_is_read_latch) i2c_cfg_reg[3] <= 1; else i2c_cfg_reg[1] <= 1; state <= FSM_IDLE; end
            endcase
        end
    end

    i2c_master master_i (
        .clk(S_AXI_ACLK), .rst(rst), .i_start_transfer(core_start_transfer), .i_address(core_address),
        .i_n_bytes(core_n_bytes), .i_is_read(core_is_read_latch), .o_ready_for_cmd(core_ready_for_cmd),
        .i_tx_data_valid(core_tx_data_valid), .i_tx_data(core_tx_data), .o_tx_data_ready(core_tx_data_ready),
        .o_rx_data_valid(core_rx_data_valid), .o_rx_data(core_rx_data), .i_rx_data_ready(core_rx_data_ready),
        .o_transfer_done(core_transfer_done), .o_ack_error(core_ack_error), .sda(sda), .scl(scl));
endmodule