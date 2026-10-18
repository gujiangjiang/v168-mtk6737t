# 同时提供两套产品名:
#   omni_q5c62q_njx -> TWRP minimal manifest (twrp-9.0, omni 系)
#   twrp_q5c62q_njx -> OrangeFox fox_12.1 (twrp 系)
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/omni_q5c62q_njx.mk \
    $(LOCAL_DIR)/twrp_q5c62q_njx.mk

COMMON_LUNCH_CHOICES := \
    omni_q5c62q_njx-eng \
    omni_q5c62q_njx-userdebug \
    twrp_q5c62q_njx-eng \
    twrp_q5c62q_njx-userdebug
