cp patches/ad9361* ../linux/drivers/iio/adc/
cp patches/zynq-pluto-sdr-maiasdr.dtsi ../linux/arch/arm/boot/dts/
#remove adm7111
cp patches/zynq-pluto-sdr-revb.dts ../linux/arch/arm/boot/dts/
#remove TDD/PHASER
cp patches/zynq-pluto-sdr-revc.dts ../linux/arch/arm/boot/dts/
cp patches/oscimp/Makefile ../linux_driver/nco_counter_core/
cp configs/zynq_pluto_linux_defconfig ../linux/arch/arm/configs/
cp configs/zynq_plutoplus_linux_defconfig ../linux/arch/arm/configs/
cp configs/zynq_e200_linux_defconfig ../linux/arch/arm/configs/
cp patches/e200/ad5660_mp.c ../linux/drivers/iio/adc/
cp patches/e200/Kconfig ../linux/drivers/iio/adc/
cp patches/e200/Makefile ../linux/drivers/iio/adc/
cp patches/e200/core.c ../linux/drivers/mtd/spi-nor/
cp patches/zynq-e200.dts ../linux/arch/arm/boot/dts/
cp patches/zynq-e200.dtsi ../linux/arch/arm/boot/dts/
#replace axis by amba
cp patches/zynq-7000.dtsi ../linux/arch/arm/boot/dts/
## Replace mosquitoo 2.0.17 (segfault) with 20.0.18
cp patches/mosquitto/* ../buildroot/package/mosquitto/
## Customize u-boot env
cp patches/u-boot/zynq-common.h ../u-boot-xlnx/include/configs/
cp patches/u-boot/zynq-plutoplus.dts ../u-boot-xlnx/arch/arm/dts/
cp patches/u-boot/zynq-e200-sdr.dts ../u-boot-xlnx/arch/arm/dts/
cp patches/u-boot/zynq_plutoplus_defconfig ../u-boot-xlnx/configs/
cp patches/u-boot/zynq_e200_defconfig ../u-boot-xlnx/configs/
cp patches/u-boot/Makefile ../u-boot-xlnx/arch/arm/dts/
