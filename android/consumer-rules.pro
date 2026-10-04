# Consumer R8/ProGuard rules for meta_wearables_dat_flutter.
#
# Meta's DAT AARs ship their own consumer rules (keep rules for
# com.meta.wearable.**, com.facebook.wearable.**, fbjni and protobuf-lite),
# so the plugin only needs to protect its own entry point, which Flutter
# instantiates reflectively from the generated plugin registrant.
-keep class com.iseelabs.meta_wearables_dat_flutter.MetaWearablesDatPlugin { *; }
