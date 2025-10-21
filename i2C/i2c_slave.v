`timescale 1ns / 1ps
//   - I2C bus'tan gelen "Address + R/W" biti kontrol edilir. Eğer adresi eşleşiyorsa ACK gönderilir.
//   - Eğer R/W=0 (Write) ise master'dan gelen 8 bit data'yı `rdata` register'ına yazar ve `data_valid=1` olur.
//   - Eğer R/W=1 (Read) ise önce dışarıdan `wdata[7:0]` alınır, sonra master'a 8 bit göndermeye başlar.  
//   - SDA open-drain, SCL dışarıdan besleniyor.  
//   - Dışarıya: `rdata[7:0]`, `data_valid` (Read tamamlanınca 1 olur), `wdata[7:0]` (okuma yanıtı için) gibi portlar sunulur.
//////////////////////////////////////////////////////////////////////////////////
module i2c_slave (
    input  wire        clk,          // Sistem clock (örneğin 50 MHz)
    input  wire        rst,          // Aktif Yüksek reset
    input  wire [6:0]  own_address,  // Bu slave'in kendi I²C adresi (7 bit)
    inout  wire        sda,          // I2C SDA hattı (open-drain)
    input  wire        scl,          // I2C SCL hattı (master tarafından üretilir)
    output reg  [7:0]  rdata,        // Slave'e "Write" yapıldığında gelen byte
    input  wire [7:0]  wdata,        // Slave "Read" modunda master'a verilecek byte
    output reg         data_valid    // Yeni rdata varsa 1 → üst katman alabilir
);

    // ----------------------------------------
    // State tanımları
    // ----------------------------------------
    localparam [2:0]
        SL_IDLE      = 3'd0,
        SL_ADDR      = 3'd1,
        SL_ACK_ADDR  = 3'd2,
        SL_RW_DATA   = 3'd3,
        SL_DATA_ACK  = 3'd4,
        SL_STOP      = 3'd5;

    reg [2:0]   state, next_state;
    reg [7:0]   shift_reg;       // Adres/RW veya data kaydı
    reg [2:0]   bit_cnt;         // Bit sayacı (0-7)

    reg         sda_oe;          // 1→SDA=0, 0→tri-state (pull-up)
    wire        sda_in;          // SDA hattının anlık durumu (pull-up veya 0)
    assign sda = (sda_oe ? 1'b0 : 1'bz);
    assign sda_in = sda;         // SCL rising edge'de bu okunur

    // SCL'de kenar deteksiyonu
    reg scl_dly;
    wire scl_rising  = (scl == 1'b1 && scl_dly == 1'b0);
    wire scl_falling = (scl == 1'b0 && scl_dly == 1'b1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scl_dly <= 1'b0;
        end else begin
            scl_dly <= scl;
        end
    end

    // ----------------------------------------
    // State Machine
    // ----------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= SL_IDLE;
            bit_cnt    <= 3'd7;
            shift_reg  <= 8'd0;
            data_valid <= 1'b0;
            rdata      <= 8'd0;
            sda_oe     <= 1'b0;   // SDA tri (pull-up)
        end else begin
            state      <= next_state;
            data_valid <= 1'b0;   // Her çevrim temizle, gerektiğinde 1'e çıkacak

            case (state)
                // ----------------------------------------
                SL_IDLE: begin
                    sda_oe <= 1'b0;   // Tri-state
                    // "Start" condition'u farz edelim: SCL=1 iken SDA high→low ise
                    if (scl_rising && sda_in == 1'b1) begin
                        // Başlangıç: adres + RW başlayacak
                        next_state <= SL_ADDR;
                        bit_cnt    <= 3'd7;
                    end else begin
                        next_state <= SL_IDLE;
                    end
                end

                // ----------------------------------------
                SL_ADDR: begin
                    // SCL rising edge'de bir bit oku
                    if (scl_rising) begin
                        shift_reg[bit_cnt] <= sda_in;
                        if (bit_cnt == 3'd0) begin
                            next_state <= SL_ACK_ADDR;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                            next_state <= SL_ADDR;
                        end
                    end else begin
                        next_state <= SL_ADDR;
                    end
                end

                // ----------------------------------------
                SL_ACK_ADDR: begin
                    // shift_reg'da [7:1]=adres, [0]=R/W biti
                    if (shift_reg[7:1] == own_address) begin
                        // Adres eşleşti → ACK
                        if (scl_falling) begin
                            sda_oe <= 1'b1; // SDA=0 ile ACK
                            next_state <= SL_RW_DATA;
                            bit_cnt    <= 3'd7;
                        end else begin
                            next_state <= SL_ACK_ADDR;
                        end
                    end else begin
                        // Adres eşleşmedi → hiçbir şey yapma, IDLE'a dön
                        sda_oe <= 1'b0;  // tri
                        if (scl_falling)
                            next_state <= SL_IDLE;
                        else
                            next_state <= SL_ACK_ADDR;
                    end
                end

                // ----------------------------------------
                SL_RW_DATA: begin
                    // R/W biti = shift_reg[0]
                    if (shift_reg[0] == 1'b0) begin
                        // Write: Master 8 bit data yolluyor, burada al
                        if (scl_rising) begin
                            shift_reg[bit_cnt] <= sda_in;
                            if (bit_cnt == 3'd0) begin
                                // 8 bit okundu → rdata'a kopyala, data_valid=1
                                rdata <= shift_reg;
                                data_valid <= 1'b1;
                                next_state <= SL_DATA_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                                next_state <= SL_RW_DATA;
                            end
                        end else begin
                            next_state <= SL_RW_DATA;
                        end

                    end else begin
                        // Read: Master veri okumak istiyor, slave → wdata gönder
                        // Her SCL falling edge'de SDA'yı bir bit olarak set et
                        if (scl_falling) begin
                            // wdata[bit_cnt] = 1 → tri, =0 → çek
                            sda_oe <= ~wdata[bit_cnt];
                            next_state <= SL_RW_DATA;
                        end else if (scl_rising) begin
                            if (bit_cnt == 3'd0) begin
                                next_state <= SL_DATA_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                                next_state <= SL_RW_DATA;
                            end
                        end else begin
                            next_state <= SL_RW_DATA;
                        end
                    end
                end

                // ----------------------------------------
                SL_DATA_ACK: begin
                    // ACK/NACK aşaması, sonrasında STOP'a bak
                    sda_oe <= 1'b0;  // SDA tri
                    next_state <= SL_STOP;
                end

                // ----------------------------------------
                SL_STOP: begin
                    // STOP condition: SCL=1 iken SDA low→high
                    sda_oe <= 1'b0;  // SDA tri
                    if (scl_rising && sda_in == 1'b1) begin
                        next_state <= SL_IDLE;
                    end else begin
                        next_state <= SL_STOP;
                    end
                end

                default: begin
                    next_state <= SL_IDLE;
                end
            endcase
        end
    end

endmodule
