# PLUTODVB2 SDR ADALM Pluto firmware for DATV

This repository contains the modified ADALM Pluto firmware for the PlutoDVB2 project.

Latest binary Release : [![GitHub Release](https://img.shields.io/github/release/f5oeo/plutosdr-fw.svg)](https://github.com/f5oeo/plutosdr-fw/releases/latest)  [![Github Releases](https://img.shields.io/github/downloads/f5oeo/plutosdr-fw/total.svg)](https://github.com/f5oeo/plutosdr-fw/releases/latest)

## Description
PlutoDVB2 firmware is a dvb dedicated firmware. It uses dvbs2 modulator in fpga ([https://github.com/OpenResearchInstitute/dvb_fpga/tree/master](https://github.com/OpenResearchInstitute/dvb_fpga/tree/master))

It can handle transport stream for video and also ip (dvb-gse).

It could also be used as a standard pluto and can be used by third party software like gnuradio, sdrconsole...with a PTT function on gpio.

Feedbacks are welcome on https://groups.io/g/plutodvb

### Version of firmware
Each new firmware is tagged with a git commit. Name is created with : 
* Name : PlutoDVB2
* Current tag 
* Number of commits since the current tag
* Short version of commit

For example, PlutoDVB2-0.3-11-g1581cc1.

You can check which commit is referenced to by reading commits history at [ refere to the firmware built  ](https://github.com/F5OEO/pluto-ori-ps/commits/main)

## Hardware
Analog device Pluto Rev B and D, plutoPlus and antSDR.

A recommended setup is to use Pluto over ethernet instead of usb.

Several recent usb to ethernet adapters has successfully been tested : 
* https://www.amazon.fr/dp/B07K1PSVG5?psc=1&ref=ppx_yo2ov_dt_b_product_details
* https://www.amazon.fr/dp/B0871ZHCKK?psc=1&ref=ppx_yo2ov_dt_b_product_details

For easy GSE operation, a minitiouner plugged on the ethernet hub adapter is recommanded.

## Extensions
* 2 CPUs enable by default
* Frequency extension Tx/Rx : 46.875Mhz-6Ghz

## MQTT control and status
See https://github.com/F5OEO/pluto-ori-ps/wiki

## Credits

Firmware License : [![Many Licenses](https://img.shields.io/badge/license-LGPL2+-blue.svg)](https://github.com/analogdevicesinc/plutosdr-fw/blob/master/LICENSE.md)  [![Many License](https://img.shields.io/badge/license-GPL2+-blue.svg)](https://github.com/analogdevicesinc/plutosdr-fw/blob/master/LICENSE.md)  [![Many License](https://img.shields.io/badge/license-BSD-blue.svg)](https://github.com/analogdevicesinc/plutosdr-fw/blob/master/LICENSE.md)  [![Many License](https://img.shields.io/badge/license-apache-blue.svg)](https://github.com/analogdevicesinc/plutosdr-fw/blob/master/LICENSE.md) and many others.

