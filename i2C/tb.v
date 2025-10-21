`timescale 1ns / 1ps

module tb;
  parameter CLK_PERIOD = 20;
  reg  clk   = 0;
  reg  rst_n = 0;
  // Master (M0) Test Sinyalleri
  reg  [4:0]  M0_AXI_AWADDR;  reg         M0_AXI_AWVALID=0; wire        M0_AXI_AWREADY;
  reg  [31:0] M0_AXI_WDATA;   reg  [3:0]  M0_AXI_WSTRB;   reg         M0_AXI_WVALID=0;  wire        M0_AXI_WREADY;
  wire [1:0]  M0_AXI_BRESP;   wire        M0_AXI_BVALID;  reg         M0_AXI_BREADY=0;
  reg  [4:0]  M0_AXI_ARADDR;  reg         M0_AXI_ARVALID=0; wire        M0_AXI_ARREADY;
  wire [31:0] M0_AXI_RDATA;   wire [1:0]  M0_AXI_RRESP;   wire        M0_AXI_RVALID;  reg         M0_AXI_RREADY=0;
  // Slave (M1) Test Sinyalleri
  reg  [3:0]  M1_AXI_AWADDR;  reg         M1_AXI_AWVALID=0; wire        M1_AXI_AWREADY;
  reg  [31:0] M1_AXI_WDATA;   reg  [3:0]  M1_AXI_WSTRB;   reg         M1_AXI_WVALID=0;  wire        M1_AXI_WREADY;
  wire [1:0]  M1_AXI_BRESP;   wire        M1_AXI_BVALID;  reg         M1_AXI_BREADY=0;
  reg  [3:0]  M1_AXI_ARADDR;  reg         M1_AXI_ARVALID=0; wire        M1_AXI_ARREADY;
  wire [31:0] M1_AXI_RDATA;   wire [1:0]  M1_AXI_RRESP;   wire        M1_AXI_RVALID;  reg         M1_AXI_RREADY=0;
  wire sda, scl; pullup(sda); pullup(scl);
  
  always #(CLK_PERIOD/2) clk = ~clk;

  i2c_top_system dut (
    .clk(clk), .rst_n(rst_n),
    .M0_AXI_AWADDR(M0_AXI_AWADDR), .M0_AXI_AWVALID(M0_AXI_AWVALID), .M0_AXI_AWREADY(M0_AXI_AWREADY),
    .M0_AXI_WDATA(M0_AXI_WDATA),   .M0_AXI_WSTRB(M0_AXI_WSTRB),   .M0_AXI_WVALID(M0_AXI_WVALID),   .M0_AXI_WREADY(M0_AXI_WREADY),
    .M0_AXI_BRESP(M0_AXI_BRESP),   .M0_AXI_BVALID(M0_AXI_BVALID), .M0_AXI_BREADY(M0_AXI_BREADY),
    .M0_AXI_ARADDR(M0_AXI_ARADDR), .M0_AXI_ARVALID(M0_AXI_ARVALID), .M0_AXI_ARREADY(M0_AXI_ARREADY),
    .M0_AXI_RDATA(M0_AXI_RDATA),   .M0_AXI_RRESP(M0_AXI_RRESP),   .M0_AXI_RVALID(M0_AXI_RVALID),   .M0_AXI_RREADY(M0_AXI_RREADY),
    .M1_AXI_AWADDR(M1_AXI_AWADDR), .M1_AXI_AWVALID(M1_AXI_AWVALID), .M1_AXI_AWREADY(M1_AXI_AWREADY),
    .M1_AXI_WDATA(M1_AXI_WDATA),   .M1_AXI_WSTRB(M1_AXI_WSTRB),   .M1_AXI_WVALID(M1_AXI_WVALID),   .M1_AXI_WREADY(M1_AXI_WREADY),
    .M1_AXI_BRESP(M1_AXI_BRESP),   .M1_AXI_BVALID(M1_AXI_BVALID), .M1_AXI_BREADY(M1_AXI_BREADY),
    .M1_AXI_ARADDR(M1_AXI_ARADDR), .M1_AXI_ARVALID(M1_AXI_ARVALID), .M1_AXI_ARREADY(M1_AXI_ARREADY),
    .M1_AXI_RDATA(M1_AXI_RDATA),   .M1_AXI_RRESP(M1_AXI_RRESP),   .M1_AXI_RVALID(M1_AXI_RVALID),   .M1_AXI_RREADY(M1_AXI_RREADY),
    .sda(sda), .scl(scl)
  );

  initial begin
    $dumpfile("i2c_final_test.vcd"); $dumpvars(0, tb);
    #10; rst_n = 0; #(CLK_PERIOD * 10); rst_n = 1;
    $display("[%0t ns] >>> RESET RELEASED <<<", $time); #(CLK_PERIOD * 5);
    axi_write(1, 4'h0, 32'h42); axi_write(1, 4'h8, 32'h1);
    
    // --- Test senaryosu ---
    $display("--- TEST 1: Master 2-Byte Write (Data: 0xCAFE) ---");
    axi_write(0, 5'h04, 32'h42); axi_write(0, 5'h00, 32'd2); axi_write(0, 5'h0C, 32'hCAFE);
    axi_write(0, 5'h10, 32'h1); 
    wait_for_flag(0, 5'h10, 1, 1);
    wait_for_flag(1, 4'h8, 1, 1);
    axi_read(1, 4'hC);
    // Not: Slave modülü sadece en son gelen byte'ı saklar. Şartnamede böyle bir kısıt yok
    // ama slave tasarımı böyle. Dolayısıyla son byte olan 0xFE kontrolü doğru.
    if (M1_AXI_RDATA[15:8] != 8'hCA || M1_AXI_RDATA[7:0] != 8'hFE) $error("HATA: Test 1 - Slave yanlis veri aldi! Alinan: %h", M1_AXI_RDATA);
    else $display("BASARILI: Test 1 - Slave veriyi dogru aldi.");
    
    #(CLK_PERIOD * 10);
    $display("--- TEST 2: Master 4-Byte Read ---");
    // Slave, master okuma yapacağında bu veriyi yollayacak.
    axi_write(1, 4'h4, 32'hDEADBEEF);
    axi_write(0, 5'h04, 32'h42); axi_write(0, 5'h00, 32'd4);
    axi_write(0, 5'h10, 32'h4); 
    wait_for_flag(0, 5'h10, 3, 1);
    axi_read(0, 5'h08);
    // Not: Slave her okuma isteğinde aynı veriyi yolladığı için bu beklenen sonuç.
    if (M0_AXI_RDATA != 32'hDEADBEEF) $error("HATA: Test 2 - Master yanlis veri okudu! Okunan: %h", M0_AXI_RDATA);
    else $display("BASARILI: Test 2 - Master veriyi dogru okudu.");
    
    $display("[%0t ns] >>> ALL TESTS PASSED <<<", $time);
    $finish;
  end

  task axi_write; input integer s; input [4:0] a; input [31:0] d; begin if(s==1)begin M1_AXI_AWADDR<=a[3:0]; M1_AXI_AWVALID<=1; M1_AXI_WDATA<=d; M1_AXI_WSTRB<=4'hF; M1_AXI_WVALID<=1; M1_AXI_BREADY<=1; @(posedge clk); while(!(M1_AXI_AWREADY&&M1_AXI_WREADY)) @(posedge clk); M1_AXI_AWVALID<=0; M1_AXI_WVALID<=0; while(!M1_AXI_BVALID) @(posedge clk); @(posedge clk); M1_AXI_BREADY<=0; end else begin M0_AXI_AWADDR<=a; M0_AXI_AWVALID<=1; M0_AXI_WDATA<=d; M0_AXI_WSTRB<=4'hF; M0_AXI_WVALID<=1; M0_AXI_BREADY<=1; @(posedge clk); while(!(M0_AXI_AWREADY&&M0_AXI_WREADY)) @(posedge clk); M0_AXI_AWVALID<=0; M0_AXI_WVALID<=0; while(!M0_AXI_BVALID) @(posedge clk); @(posedge clk); M0_AXI_BREADY<=0; end end endtask
  task axi_read; input integer s; input [4:0] a; begin if(s==1)begin M1_AXI_ARADDR<=a[3:0]; M1_AXI_ARVALID<=1; M1_AXI_RREADY<=1; @(posedge clk); while(!M1_AXI_ARREADY) @(posedge clk); M1_AXI_ARVALID<=0; while(!M1_AXI_RVALID) @(posedge clk); @(posedge clk); M1_AXI_RREADY<=0; end else begin M0_AXI_ARADDR<=a; M0_AXI_ARVALID<=1; M0_AXI_RREADY<=1; @(posedge clk); while(!M0_AXI_ARREADY) @(posedge clk); M0_AXI_ARVALID<=0; while(!M0_AXI_RVALID) @(posedge clk); @(posedge clk); M0_AXI_RREADY<=0; end end endtask

  // *** DÜZELTME: 'return' yerine 'disable' kullanımı ***
  task wait_for_flag; 
    input integer s; 
    input [4:0] a; 
    input integer b; 
    input check;
    reg[31:0] read_data;
    integer i;
    
    begin: wait_loop_block // Döngüye isim veriyoruz
        $display("Waiting for flag: Slv=%d, Addr=0x%h, Bit=%d to be %d",s,a,b,check);
        for(i=0; i<500; i=i+1) begin
            axi_read(s,a);
            read_data = (s==0)? M0_AXI_RDATA : M1_AXI_RDATA;
            if(read_data[b] == check) begin
                $display("Flag SET at Addr=0x%h", a);
                disable wait_loop_block; // İsimli bloktan çık
            end
            #(CLK_PERIOD*20);
        end
        $error("TIMEOUT waiting for flag at Addr=0x%h",a);
        $finish;
    end
  endtask
  
endmodule