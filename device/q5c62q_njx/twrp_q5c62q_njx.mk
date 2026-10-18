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

# 原机指纹 (供部分刷机脚本校验)
PRODUCT_BUILD_PROP_OVERRIDES += \
    BUILD_FINGERPRINT="alps/full_q5c62q_njx/q5c62q_njx:6.0/MRA58K/1505127327:user/dev-keys" \
    PRIVATE_BUILD_DESC="full_q5c62q_njx-user 6.0 MRA58K 1505127327 dev-keys"

# OrangeFox 设备级配置(可选, 文件不存在则自动跳过)
$(call inherit-product-if-exists, $(DEVICE_PATH)/fox_q5c62q_njx.mk)
