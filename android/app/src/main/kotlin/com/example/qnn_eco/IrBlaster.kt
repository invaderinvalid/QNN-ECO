package com.example.qnn_eco

import android.content.Context
import android.hardware.ConsumerIrManager
import kotlinx.coroutines.delay

enum class NotificationSentiment {
    CRISIS,
    DISTRESSED,
    MILD_NEGATIVE,
    NEUTRAL,
    POSITIVE,
}

/**
 * Transmits the supplied 24-bit NEC commands. Codes are kept in one place so a
 * different physical receiver can be supported without touching triage logic.
 */
class IrBlaster(context: Context) {
    private val transmitter = context.getSystemService(ConsumerIrManager::class.java)

    val isAvailable: Boolean
        get() = transmitter?.hasIrEmitter() == true

    suspend fun signal(sentiment: NotificationSentiment) {
        check(isAvailable) { "This device does not expose an IR transmitter." }
        val commands = when (sentiment) {
            NotificationSentiment.CRISIS -> listOf(NecRemoteCodes.ON, NecRemoteCodes.RED, NecRemoteCodes.FLASH)
            NotificationSentiment.DISTRESSED -> listOf(NecRemoteCodes.ON, NecRemoteCodes.YELLOW)
            NotificationSentiment.MILD_NEGATIVE -> listOf(NecRemoteCodes.ON, NecRemoteCodes.SKY_BLUE)
            NotificationSentiment.NEUTRAL -> listOf(NecRemoteCodes.ON, NecRemoteCodes.WHITE)
            NotificationSentiment.POSITIVE -> listOf(NecRemoteCodes.ON, NecRemoteCodes.GREEN)
        }

        commands.forEachIndexed { index, command ->
            transmitter?.transmit(NecRemoteCodes.CARRIER_FREQUENCY_HZ, NecIrEncoder.encode24(command))
            if (index < commands.lastIndex) delay(COMMAND_GAP_MILLIS)
        }
    }

    private companion object {
        const val COMMAND_GAP_MILLIS = 90L
    }
}

object NecRemoteCodes {
    const val CARRIER_FREQUENCY_HZ = 38_000

    const val RED = 0xF720DF
    const val YELLOW = 0xF728D7
    const val GREEN = 0xF7A05F
    const val SKY_BLUE = 0xF750AF
    const val WHITE = 0xF7E01F
    const val ON = 0xF7C03F
    const val FLASH = 0xF7D02F
}

/** NEC timing with least-significant-bit-first payload, matching standard NEC remotes. */
object NecIrEncoder {
    fun encode24(command: Int): IntArray = buildList {
        add(9_000)
        add(4_500)
        repeat(24) { bit ->
            add(560)
            add(if (((command shr bit) and 1) == 1) 1_690 else 560)
        }
        add(560)
        add(40_000)
    }.toIntArray()
}
