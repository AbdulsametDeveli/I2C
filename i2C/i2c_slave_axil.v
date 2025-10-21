`timescale 1ns / 1ps

//   - AXI-Lite register arayüzü üzerinden aşağıdaki register'ları sunar:
//       0x00 = SLV_ADDR   (7-bit slave adresi, RW)  
//       0x04 = SLV_WDATA  (Slave'a yazılacak data, RW)  
//       0x08 = SLV_STATUS (bit [0]=Enable, [1]=Data_Ready; RW)  
//       0x0C = SLV_RDATA  (Slave'den en son gelen data, RO)  
//   - İçte basit bir i2c_slave modülü barındırır.  
//   - AXI'den SLV_ADDR=** yazıldığında **, o adrese set edilir → i2c_slave aktifleşir.  
//   - i2c_slave'dan `data_valid` geldiğinde, `SLV_RDATA <= rdata` ve `SLV_STATUS[1]=1` flag'i set edilir.  
//   - SW, `SLV_STATUS[1]`=0 yazarak flag'i temizleyebilir.
//////////////////////////////////////////////////////////////////////////////////
module i2c_slave_axil #(
    parameter integer C_S_AXI_ADDR_WIDTH = 4,   // 4 bit → 16 byte adres (0x00..0x0C)
    parameter integer C_S_AXI_DATA_WIDTH = 32
)(
    // -------- AXI-Lite Slave Arayüzü --------
    input  wire                         S_AXI_ACLK,
    input  wire                         S_AXI_ARESETN,
    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire                         S_AXI_AWVALID,
    output reg                          S_AXI_AWREADY,
    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                         S_AXI_WVALID,
    output reg                          S_AXI_WREADY,
    // Write Response Channel
    output reg   [1:0]                  S_AXI_BRESP,
    output reg                          S_AXI_BVALID,
    input  wire                         S_AXI_BREADY,
    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire                         S_AXI_ARVALID,
    output reg                          S_AXI_ARREADY,
    // Read Data Channel
    output reg   [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg   [1:0]                   S_AXI_RRESP,
    output reg                           S_AXI_RVALID,
    input  wire                          S_AXI_RREADY,

    // -------- Alt Modül (i2c_slave) Portları --------
    input  wire        slave_clk,       // genellikle S_AXI_ACLK bağlanır
    input  wire        slave_rst,       // S_AXI_ARESETN'in invert'i
    inout  wire        sda,             // I2C SDA (open-drain)
    input  wire        scl,             // I2C SCL
    // Dışarıdan slave'in adresini set etmek için:
    // SLV_ADDR[6:0]
    // Yazma kanalı → bu register'a yazıp slave'in adresini değiştirebilirsin
    output wire [6:0]  own_address,     
    // "Slave'e yazılacak data" → yazma register'ı:
    output wire [7:0]  slv_wdata,       
    // "Slave'den okunan son veri" → okuma register'ı (RO):
    output wire [7:0]  slv_rdata,       
    // "Slave'e yeni veri geldi → data_valid" → status[1]=1, SW clear edebilir:
    output wire        slv_data_valid   
);

    // ----------------------------------------
    // İç register'lar
    // ----------------------------------------
    reg [31:0] reg_addr;    // 0x00: slave address (LSB[6:0])
    reg [31:0] reg_wdata;   // 0x04: slave'a yazılacak data
    reg [31:0] reg_status;  // 0x08: [0]=Enable, [1]=Data_Ready (HW set), diğer bitler reserved
    reg [31:0] reg_rdata;   // 0x0C: slave'den okunan son data (RO)

    // ----------------------------------------
    // AXI handshake için latched adresler
    // ----------------------------------------
    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_latched;
    reg [C_S_AXI_ADDR_WIDTH-1:0] araddr_latched;

    // ----------------------------------------
    // AXI-Lite Reset & Write/Read İşlemleri
    // ----------------------------------------
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            // Reset:
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00;
            S_AXI_RDATA   <= 32'd0;
            // Yerel register'ları temizle
            reg_addr    <= 32'd0;
            reg_wdata   <= 32'd0;
            reg_status  <= 32'd0;
            reg_rdata   <= 32'd0;
        end else begin
            // ---------- Write Address Channel ----------
            if (~S_AXI_AWREADY && S_AXI_AWVALID) begin
                S_AXI_AWREADY   <= 1'b1;
                awaddr_latched  <= S_AXI_AWADDR;
            end else begin
                S_AXI_AWREADY <= 1'b0;
            end

            // ---------- Write Data Channel ----------
            if (~S_AXI_WREADY && S_AXI_WVALID) begin
                S_AXI_WREADY <= 1'b1;
            end else begin
                S_AXI_WREADY <= 1'b0;
            end

            // ---------- Write Response (AW + W geldiyse) ----------
            if (S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID && ~S_AXI_BVALID) begin
                case (awaddr_latched[3:2])  
                    2'b00: reg_addr   <= S_AXI_WDATA;  // 0x00
                    2'b01: reg_wdata  <= S_AXI_WDATA;  // 0x04
                    2'b10: reg_status <= S_AXI_WDATA;  // 0x08 (Data_Ready veya Enable clear)
                    // 0x0C = reg_rdata RO, yazılmaz
                    default: ;
                endcase
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00; // OKAY
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end

            // ---------- Read Address Channel ----------
            if (~S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY  <= 1'b1;
                araddr_latched <= S_AXI_ARADDR;
            end else begin
                S_AXI_ARREADY <= 1'b0;
            end

            // ---------- Read Data Channel ----------
            if (S_AXI_ARREADY && S_AXI_ARVALID && ~S_AXI_RVALID) begin
                case (araddr_latched[3:2])
                    2'b00: S_AXI_RDATA <= reg_addr;   // 0x00
                    2'b01: S_AXI_RDATA <= reg_wdata;  // 0x04
                    2'b10: S_AXI_RDATA <= reg_status; // 0x08
                    2'b11: S_AXI_RDATA <= reg_rdata;  // 0x0C
                    default: S_AXI_RDATA <= 32'd0;
                endcase
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= 2'b00; // OKAY
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

    // ----------------------------------------
    // İçteki i2c_slave Instantiation
    // ----------------------------------------
    wire [7:0]  i2c_slave_rdata;
    wire        i2c_slave_data_valid;
    i2c_slave i2c_slave_inst (
        .clk        (slave_clk),
        .rst        (slave_rst),
        .own_address(reg_addr[6:0]), // düşük 7-bit
        .sda        (sda),
        .scl        (scl),
        .rdata      (i2c_slave_rdata),
        .wdata      (reg_wdata[7:0]),
        .data_valid (i2c_slave_data_valid)
    );

    // ----------------------------------------
    // Slave'den okunan veri geldiğinde register'a aktar
    // ----------------------------------------
    always @(posedge slave_clk or posedge slave_rst) begin
        if (slave_rst) begin
            reg_rdata  <= 32'd0;
            reg_status[1] <= 1'b0; // Data_Ready temiz
        end else begin
            if (i2c_slave_data_valid) begin
                reg_rdata[7:0] <= i2c_slave_rdata; 
                reg_status[1]  <= 1'b1; // Data_Ready = 1
            end
            // SW "reg_status[1]=0" yazarak "Data_Ready" flag'ini temizleyebilir.
        end
    end

    // ----------------------------------------
    // Continuous Outputs
    // ----------------------------------------
    assign own_address    = reg_addr[6:0];
    assign slv_wdata      = reg_wdata[7:0];
    assign slv_rdata      = reg_rdata[7:0];
    assign slv_data_valid = i2c_slave_data_valid; 
    // (SW, AXI üzerinden reg_status[1]=0 yazarak temizleyebilir)

endmodule
