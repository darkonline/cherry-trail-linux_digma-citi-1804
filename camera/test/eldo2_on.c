// SPDX-License-Identifier: GPL-2.0
/*
 * Test module for Digma CITI 1804: switch on the AXP288 ELDO2 output (camera 1.8 V)
 * through the regular axp20x regmap. Restores the previous state on unload.
 * ELDO2 enable = register 0x12 bit 1; its voltage register 0x1a is already 0x16 (1.8 V).
 */
#include <linux/module.h>
#include <linux/i2c.h>
#include <linux/regmap.h>

#define AXP288_ELDO_CTRL	0x12
#define AXP288_ELDO2_EN		BIT(1)

static struct device *pmic;
static struct regmap *map;
static unsigned int saved;

static int __init eldo2_on_init(void)
{
	unsigned int val;
	int ret;

	pmic = bus_find_device_by_name(&i2c_bus_type, NULL, "i2c-INT33F4:00");
	if (!pmic)
		return -ENODEV;
	map = dev_get_regmap(pmic, NULL);
	if (!map) {
		put_device(pmic);
		return -ENODEV;
	}
	ret = regmap_read(map, AXP288_ELDO_CTRL, &saved);
	if (ret)
		goto err;
	ret = regmap_update_bits(map, AXP288_ELDO_CTRL, AXP288_ELDO2_EN, AXP288_ELDO2_EN);
	if (ret)
		goto err;
	regmap_read(map, AXP288_ELDO_CTRL, &val);
	pr_info("eldo2_on: reg 0x12 0x%02x -> 0x%02x\n", saved, val);
	return 0;
err:
	put_device(pmic);
	return ret;
}

static void __exit eldo2_on_exit(void)
{
	regmap_update_bits(map, AXP288_ELDO_CTRL, AXP288_ELDO2_EN, saved & AXP288_ELDO2_EN);
	pr_info("eldo2_on: reg 0x12 restored (ELDO2 %s)\n", (saved & AXP288_ELDO2_EN) ? "on" : "off");
	put_device(pmic);
}

module_init(eldo2_on_init);
module_exit(eldo2_on_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("CITI 1804 test: enable AXP288 ELDO2 (camera 1.8 V)");
