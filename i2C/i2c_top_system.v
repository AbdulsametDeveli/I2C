`timescale 1ns/1ps

module i2c_top_system (
    input  wire                     clk,
    input  wire                     rst_n,
    // AXI-Lite Master (M0)
    input  wire [4:0]               M0_AXI_AWADDR, input  wire M0_AXI_AWVALID, output wire M0_AXI_AWREADY,
    input  wire [31:0]              M0_AXI_WDATA, input  wire [3:0] M0_AXI_WSTRB, input wire M0_AXI_WVALID, output wire M0_AXI_WREADY,
    output wire [1:0]               M0_AXI_BRESP, output wire M0_AXI_BVALID, input wire M0_AXI_BREADY,
    input  wire [4:0]               M0_AXI_ARADDR, input  wire M0_AXI_ARVALID, output wire M0_AXI_ARREADY,
    output wire [31:0]              M0_AXI_RDATA, output wire [1:0] M0_AXI_RRESP, output wire M0_AXI_RVALID, input wire M0_AXI_RREADY,
    // AXI-Lite Slave (M1)
    input  wire [3:0]               M1_AXI_AWADDR, input wire M1_AXI_AWVALID, output wire M1_AXI_AWREADY,
    input  wire [31:0]              M1_AXI_WDATA, input wire [3:0] M1_AXI_WSTRB, input wire M1_AXI_WVALID, output wire M1_AXI_WREADY,
    output wire [1:0]               M1_AXI_BRESP, output wire M1_AXI_BVALID, input wire M1_AXI_BREADY,
    input  wire [3:0]               M1_AXI_ARADDR, input wire M1_AXI_ARVALID, output wire M1_AXI_ARREADY,
    output wire [31:0]              M1_AXI_RDATA, output wire [1:0] M1_AXI_RRESP, output wire M1_AXI_RVALID, input wire M1_AXI_RREADY,
    // I2C Bus
    inout  wire                     sda,
    inout  wire                     scl
);
    // i2c_master_axil instance (M0)
    i2c_master_axil #(.C_S_AXI_ADDR_WIDTH(5)) M0 (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR(M0_AXI_AWADDR), .S_AXI_AWVALID(M0_AXI_AWVALID), .S_AXI_AWREADY(M0_AXI_AWREADY),
        .S_AXI_WDATA(M0_AXI_WDATA),   .S_AXI_WSTRB(M0_AXI_WSTRB),     .S_AXI_WVALID(M0_AXI_WVALID), .S_AXI_WREADY(M0_AXI_WREADY),
        .S_AXI_BRESP(M0_AXI_BRESP),   .S_AXI_BVALID(M0_AXI_BVALID),   .S_AXI_BREADY(M0_AXI_BREADY),
        .S_AXI_ARADDR(M0_AXI_ARADDR), .S_AXI_ARVALID(M0_AXI_ARVALID), .S_AXI_ARREADY(M0_AXI_ARREADY),
        .S_AXI_RDATA(M0_AXI_RDATA),   .S_AXI_RRESP(M0_AXI_RRESP),     .S_AXI_RVALID(M0_AXI_RVALID), .S_AXI_RREADY(M0_AXI_RREADY),
        .sda(sda), .scl(scl)
    );
    // i2c_slave_axil instance (M1)
    i2c_slave_axil #(.C_S_AXI_ADDR_WIDTH(4)) M1 (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR(M1_AXI_AWADDR), .S_AXI_AWVALID(M1_AXI_AWVALID), .S_AXI_AWREADY(M1_AXI_AWREADY),
        .S_AXI_WDATA(M1_AXI_WDATA),   .S_AXI_WSTRB(M1_AXI_WSTRB),     .S_AXI_WVALID(M1_AXI_WVALID), .S_AXI_WREADY(M1_AXI_WREADY),
        .S_AXI_BRESP(M1_AXI_BRESP),   .S_AXI_BVALID(M1_AXI_BVALID),   .S_AXI_BREADY(M1_AXI_BREADY),
        .S_AXI_ARADDR(M1_AXI_ARADDR), .S_AXI_ARVALID(M1_AXI_ARVALID), .S_AXI_ARREADY(M1_AXI_ARREADY),
        .S_AXI_RDATA(M1_AXI_RDATA),   .S_AXI_RRESP(M1_AXI_RRESP),     .S_AXI_RVALID(M1_AXI_RVALID), .S_AXI_RREADY(M1_AXI_RREADY),
        .slave_clk(clk), .slave_rst(~rst_n), .sda(sda), .scl(scl)
    );
endmodule