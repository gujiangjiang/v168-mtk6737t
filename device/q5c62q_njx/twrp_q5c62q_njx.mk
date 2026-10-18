# OrangeFox (fox_12.1) 产品定义
# lunch 目标: twrp_q5c62q_njx-eng
DEVICE_PATH := device/mediatek/q5c62q_njx

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

## Device identifier
PRODUCT_DEVICE := q5c62q_njx
PRODUCT_NAME := twrp_q5c62q_njx
PRODUCT_BRAND := freeme
PRODUCT_MODEL := V168
PRODUCT_MANUFACTURER := freeme

# 与原机一致的 USB 默认配置
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=mtp

# 注: 指纹覆盖(PRODUCT_BUILD_PROP_OVERRIDES)只在 TWRP 9.0 产品(omni_*)中保留,
#     A12(fox_12.1) 上该语法存在兼容风险, OrangeFox 构建不需要它, 故此处不设。

# OrangeFox 设备级配置(可选, 文件不存在则自动跳过)
$(call inherit-product-if-exists, $(DEVICE_PATH)/fox_q5c62q_njx.mk)
