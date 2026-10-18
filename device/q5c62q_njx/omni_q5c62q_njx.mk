# 产品定义 (TWRP minimal manifest / OrangeFox 均为 omni 系)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)
$(call inherit-product, vendor/omni/config/common.mk)

PRODUCT_DEVICE := q5c62q_njx
PRODUCT_NAME := omni_q5c62q_njx
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
