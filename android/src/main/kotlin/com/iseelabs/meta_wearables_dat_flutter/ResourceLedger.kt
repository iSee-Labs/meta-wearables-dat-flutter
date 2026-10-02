// Counts the native resources the plugin holds so `dumpDiagnostics()` can
// report them and integration tests can prove every `stop*` call released
// everything it acquired.

package com.iseelabs.meta_wearables_dat_flutter

object ResourceLedger {
    enum class Kind(val wire: String) {
        TEXTURES("textures"),
        LISTENERS("listeners"),
        DEVICE_SESSIONS("deviceSessions"),
        CAMERAS("cameras"),
        DISPLAYS("displays"),
        DECODERS("decoders"),
        CAPABILITIES("capabilities"),
        MOCK_DEVICES("mockDevices"),
    }

    private val counts = mutableMapOf<Kind, Int>()

    @Synchronized
    fun acquire(kind: Kind, amount: Int = 1) {
        counts[kind] = (counts[kind] ?: 0) + amount
    }

    @Synchronized
    fun release(kind: Kind, amount: Int = 1) {
        counts[kind] = maxOf(0, (counts[kind] ?: 0) - amount)
    }

    @Synchronized
    fun set(kind: Kind, value: Int) {
        counts[kind] = maxOf(0, value)
    }

    @Synchronized
    fun snapshot(): Map<String, Int> = Kind.values().associate { it.wire to (counts[it] ?: 0) }

    @Synchronized
    fun reset() = counts.clear()
}
