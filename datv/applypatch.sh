cp patches/ad9361* ../linux/drivers/iio/adc/
cp patches/zynq-pluto-sdr-maiasdr.dtsi ../linux/arch/arm/boot/dts/
#remove adm7111
cp patches/zynq-pluto-sdr-revb.dts ../linux/arch/arm/boot/dts/
#remove TDD/PHASER
cp patches/zynq-pluto-sdr-revc.dts ../linux/arch/arm/boot/dts/
cp patches/oscimp/Makefile ../linux_driver/nco_counter_core/
cp configs/zynq_pluto_linux_defconfig ../linux/arch/arm/configs/
cp configs/zynq_plutoplus_linux_defconfig ../linux/arch/arm/configs/
## Replace mosquitoo 2.0.17 (segfault) with 20.0.18
cp patches/mosquitto/* ../buildroot/package/mosquitto/