# I2C 
AXI-Lite I2C Master & Slave (Verilog)
Bu proje, Verilog HDL kullanılarak geliştirilmiş, AXI-Lite arayüzüne sahip bir I2C Master (M0) ve I2C Slave (M1) IP'si içerir.

Proje, SoC (örn. Zynq) sistemlerine kolay entegrasyon için tasarlanmıştır. i2c_top_system.v modülü, bu iki IP'yi bir I2C veriyolu (sda, scl) üzerinden birbirine bağlar. tb.v dosyası, tüm sistemin doğrulamasını içeren bir testbench sağlar.

Dosya Yapısı
i2c_top_system.v: Master (M0) ve Slave'i (M1) örnekleyen (instantiate) en üst seviye modül.
i2c_master_axil.v: I2C Master çekirdeği için AXI-Lite wrapper.
i2c_slave_axil.v: I2C Slave çekirdeği için AXI-Lite wrapper.
i2c_master.v: I2C Master protokol mantığı.
i2c_slave.v: I2C Slave protokol mantığı.
tb.v: AXI-Lite komutları göndererek sistemi test eden simülasyon testbench'i.

Register Haritası: M0 (Master)
Offset	Adı	RW	Açıklama
0x00	NBY	RW	
Toplam byte sayısı (R/W) 
0x04	ADR	RW	
7-bit Slave adresi 
0x08	RDR	RO	
Okunan veri (Read Data) 
0x0C	TDR	RW	
Yazılacak veri (Write Data) 
0x10	CFG	RW	
Kontrol/Durum Register'ı  bit[0]: Yazma Başlat (W)  bit[1]: Yazma Bitti (RO)  bit[2]: Okuma Başlat (W)  bit[3]: Okuma Bitti (RO) 

Register Haritası: M1 (Slave)
Offset	Adı	RW	Açıklama
0x00	SLV_ADDR	RW	
Slave'in kendi 7-bit adresi 
0x04	SLV_WDATA	RW	
Master'a gönderilecek okuma verisi 
0x08	SLV_STATUS	RW	
Durum  bit[0]: Enable  bit[1]: Veri Hazır (HW set , SW clear )
0x0C	SLV_RDATA	RO	
Master'dan alınan yazma verisi 

Simülasyon (tb.v)
Testbench, i2c_top_system modülünü test eder:
Slave Yapılandırması: Slave'in (M1) I2C adresi AXI üzerinden 0x42 olarak ayarlanır.
Test 1 (Master Write): Master (M0), Slave'e 0xCAFE verisini yazar. Slave'in SLV_RDATA register'ından son byte olan 0xFE'nin alındığı doğrulanır.
Test 2 (Master Read): Slave'in SLV_WDATA register'ı 0xDEADBEEF olarak ayarlanır. Master (M0), Slave'den okuma yapar ve 0xDEADBEEF verisini aldığı doğrulanır.


AXI-Lite I2C Master & Slave (Verilog)This project contains an I2C Master (M0) and an I2C Slave (M1) IP core, both developed in Verilog HDL and featuring an AXI-Lite interface.The project is designed for easy integration into SoC (e.g., Zynq) systems. The i2c_top_system.v module connects these two IPs via an I2C bus (sda, scl). The tb.v file provides a testbench for verifying the entire system.File Structurei2c_top_system.v: Top-level module that instantiates the Master (M0) and Slave (M1).i2c_master_axil.v: AXI-Lite wrapper for the I2C Master core.i2c_slave_axil.v: AXI-Lite wrapper for the I2C Slave core.i2c_master.v: I2C Master protocol logic.i2c_slave.v: I2C Slave protocol logic.tb.v: Simulation testbench that tests the system by sending AXI-Lite commands.Register Map: M0 (Master)OffsetNameR/WDescription0x00NBYRWTotal number of bytes (R/W)0x04ADRRW7-bit Slave address0x08RDRRORead Data0x0CTDRRWWrite Data0x10CFGRWControl/Status Register 
 bit[0]: Start Write (W) 
 bit[1]: Write Done (RO) 
 bit[2]: Start Read (W) 
 bit[3]: Read Done (RO)Register Map: M1 (Slave)OffsetNameR/WDescription0x00SLV_ADDRRWSlave's own 7-bit address0x04SLV_WDATARWRead data to be sent to Master0x08SLV_STATUSRWStatus 
 bit[0]: Enable 
 bit[1]: Data Ready (HW set, SW clear)0x0CSLV_RDATAROWrite data received from MasterSimulation (tb.v)The testbench verifies the i2c_top_system module:Slave Configuration: The Slave's (M1) I2C address is set to 0x42 via AXI.Test 1 (Master Write): The Master (M0) writes the data 0xCAFE to the Slave. It is verified that the last byte, 0xFE, is received in the Slave's SLV_RDATA register.Test 2 (Master Read): The Slave's SLV_WDATA register is set to 0xDEADBEEF. The Master (M0) performs a read from the Slave, and it is verified that 0xDEADBEEF is received.
