/*
 * AD5660: ad5660 control
 *
 * Copyright (c) 2023 lone boy <lone_boy@microphase.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 */


#include <linux/err.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/property.h>
#include <linux/slab.h>
#include <linux/sched.h>
#include <linux/delay.h>
#include <linux/iio/iio.h>
#include <linux/iio/sysfs.h>
#include <linux/gpio/consumer.h>
#include <asm/io.h>


#define DAC_MEM_ADDR 0x43C00000

/* 
*   DAC MODE 0 自动设置  1 手动设置
*   DAC value 1 写 dac的值
*   DAC dyn_value  mode 1 用户设置的值 mode 0 外部参考校准的值
*   DAC ref sel DAC MODE 0 0:10M 1:PPS 2:GPS
*   DAC_LOCKED PLL 锁定状态
*/

struct ad5660_data{
    struct device *dev;
    void __iomem *control_virtualaddr;
};

enum ad5660_iio_dev_attr{
    DAC_MODE,
    DAC_VALUE,
    DAC_READ_VALUE,
    DAC_REF_SEL,
    DAC_LOCKED,
};

static ssize_t ad5660_show(struct device *dev,struct device_attribute *attr,char *buf)
{
    struct iio_dev *indio_dev = dev_to_iio_dev(dev);
	struct iio_dev_attr *this_attr = to_iio_dev_attr(attr);
    struct ad5660_data *ad5660 = iio_priv(indio_dev);
    int ret = 0;

    switch ((u32) this_attr->address)
    {
    case DAC_MODE:
        ret = sprintf(buf,"%u\n",ioread32(ad5660->control_virtualaddr));
        break;
    case DAC_VALUE:
        ret = sprintf(buf,"%u\n",ioread32(ad5660->control_virtualaddr + 4));
        break;
    case DAC_READ_VALUE:
        ret = sprintf(buf,"%u\n",ioread32(ad5660->control_virtualaddr + 8));
        break;
    case DAC_REF_SEL:
        ret = sprintf(buf,"%u\n",ioread32(ad5660->control_virtualaddr + 12));
        break;
    case DAC_LOCKED:
        ret = sprintf(buf,"%u\n",ioread32(ad5660->control_virtualaddr + 16));
        break;
    default:
        ret = EINVAL;
        break;
    }
    return ret;
}


static ssize_t ad5660_store(struct device *dev,
				struct device_attribute *attr,
				const char *buf, size_t len)
{
    struct iio_dev *indio_dev = dev_to_iio_dev(dev);
	struct iio_dev_attr *this_attr = to_iio_dev_attr(attr);
    struct ad5660_data *ad5660 = iio_priv(indio_dev);
    int ret = 0;
    u32 val;

    switch ((u32) this_attr->address)
    {
    case DAC_MODE:
        ret = kstrtou32(buf,10,&val);
        iowrite32(val,ad5660->control_virtualaddr);
        break;
    case DAC_VALUE:
        ret = kstrtou32(buf,10,&val);
        iowrite32(val,ad5660->control_virtualaddr+4);
        break;
    case DAC_REF_SEL:
        ret = kstrtou32(buf,10,&val);
        iowrite32(val,ad5660->control_virtualaddr+12);
        break;
    default:
        ret = EINVAL;
        break;
    }
    return ret;
}

static IIO_DEVICE_ATTR(in_voltage_dac_mode,S_IRUGO | S_IWUSR,
    ad5660_show,
    ad5660_store,
    DAC_MODE
);

static IIO_DEVICE_ATTR(in_voltage_dac_value,S_IRUGO | S_IWUSR,
    ad5660_show,
    ad5660_store,
    DAC_VALUE
);

static IIO_DEVICE_ATTR(in_voltage_dac_read_value,S_IRUGO | S_IWUSR,
    ad5660_show,
    ad5660_store,
    DAC_READ_VALUE
);

static IIO_DEVICE_ATTR(in_voltage_dac_ref_sel,S_IRUGO | S_IWUSR,
    ad5660_show,
    ad5660_store,
    DAC_REF_SEL
);

static IIO_DEVICE_ATTR(in_voltage_dac_locked,S_IRUGO | S_IWUSR,
    ad5660_show,
    ad5660_store,
    DAC_LOCKED
);

static struct attribute *ad5660_attributes[] = {
    &iio_dev_attr_in_voltage_dac_mode.dev_attr.attr,
    &iio_dev_attr_in_voltage_dac_value.dev_attr.attr,
    &iio_dev_attr_in_voltage_dac_read_value.dev_attr.attr,
    &iio_dev_attr_in_voltage_dac_ref_sel.dev_attr.attr,
    &iio_dev_attr_in_voltage_dac_locked.dev_attr.attr,
    NULL
};

static const struct attribute_group ad5660_attribute_group = {
	.attrs = ad5660_attributes,
};


static int ad5660_read_raw(struct iio_dev *indio_dev,
			    const struct iio_chan_spec *chan, int *val,
			    int *val2, long mask)
{
    return 0;
}

static int ad5660_write_raw(struct iio_dev *indio_dev,
			     struct iio_chan_spec const *chan, int val,
			     int val2, long mask)
{
    return 0;
}

static const struct iio_info ad5660_iio_info = {
	.read_raw = &ad5660_read_raw,
	.write_raw = &ad5660_write_raw,
    .attrs = &ad5660_attribute_group,
};

static const struct of_device_id of_ad5660mp_match[] = {
	{ .compatible = "microphase,ad5660" },
	{},
};

MODULE_DEVICE_TABLE(of, of_ad5660mp_match);


static const struct iio_chan_spec ad5660_channles[] = {
    {
        .type = IIO_VOLTAGE,
        .indexed = 1,
        .channel = 0,
        .info_mask_shared_by_type = BIT(IIO_CHAN_INFO_RAW),
    },
};

static int ad5660_probe(struct platform_device *pdev)
{
    struct ad5660_data *ad5660;
    struct iio_dev *indio_dev;
    int ret;

    indio_dev = devm_iio_device_alloc(&pdev->dev, sizeof(*ad5660));
	if (!indio_dev)
		return -ENOMEM;

    ad5660 = iio_priv(indio_dev);
    ad5660->dev = &pdev->dev;

    ad5660->control_virtualaddr = ioremap(DAC_MEM_ADDR, 0x10000);
    if (!ad5660->control_virtualaddr) {
		dev_err(&pdev->dev, "unable to IOMAP ad5660mp registers\n");
		return -ENOMEM;
	}

    dev_info(&pdev->dev,"IOMAP ad5660mp registers phyaddr %x virtaddr %x",DAC_MEM_ADDR,ad5660->control_virtualaddr);

    iowrite32(1,ad5660->control_virtualaddr);
    iowrite32(23000,ad5660->control_virtualaddr+4);


    indio_dev->name = "ad5660mp";
	indio_dev->dev.parent = &pdev->dev;
	indio_dev->dev.of_node = pdev->dev.of_node;
	indio_dev->info = &ad5660_iio_info;
	indio_dev->modes = INDIO_DIRECT_MODE;

    indio_dev->channels = ad5660_channles;
	indio_dev->num_channels = ARRAY_SIZE(ad5660_channles);
    ret = iio_device_register(indio_dev);
	if (ret < 0) {
		dev_err(&pdev->dev, "Couldn't register the device\n");
	}

	platform_set_drvdata(pdev, indio_dev);

	return ret;
}


static int ad5660_removed(struct platform_device *pdev)
{
    struct ad5660_data *ad5660;
	struct iio_dev *indio_dev;

	indio_dev = platform_get_drvdata(pdev);
	ad5660 = iio_priv(indio_dev);

	if (ad5660->control_virtualaddr)
		iounmap(ad5660->control_virtualaddr);

	iio_device_unregister(indio_dev);
	return 0;
}

static struct platform_driver lpf1600_driver = {
	.probe		= ad5660_probe,
	.remove		= ad5660_removed,
	.driver		= {
		.name		= KBUILD_MODNAME,
		.of_match_table	= of_ad5660mp_match,
	},
};

module_platform_driver(lpf1600_driver);

MODULE_AUTHOR("loneboy <995586238@qq.com>");
MODULE_DESCRIPTION("ad5660mp driver");
MODULE_LICENSE("GPL V2");