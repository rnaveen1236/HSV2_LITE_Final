package com.hsv2.hsv2_lite.mediapipe

import kotlin.math.atan2

class DirectionCalculator {

    fun calculateAngleDegrees(
        centerX: Float,
        principalX: Float,
        focalLengthX: Float
    ): Float {

        if (focalLengthX <= 0f) {
            return 0f
        }

        val angleRadians = atan2(
            centerX - principalX,
            focalLengthX
        )

        return Math.toDegrees(
            angleRadians.toDouble()
        ).toFloat()
    }

    fun angleToClockDirection(
        angleDegrees: Float
    ): String {

        return when {
            angleDegrees >= 75f -> "3 o'clock"
            angleDegrees >= 45f -> "2 o'clock"
            angleDegrees >= 15f -> "1 o'clock"

            angleDegrees > -15f -> "12 o'clock"

            angleDegrees > -45f -> "11 o'clock"
            angleDegrees > -75f -> "10 o'clock"

            else -> "9 o'clock"
        }
    }

    fun angleToHorizontalDirection(
        angleDegrees: Float
    ): String {

        return when {
            angleDegrees < -15f -> "LEFT"
            angleDegrees > 15f -> "RIGHT"
            else -> "CENTER"
        }
    }
}
