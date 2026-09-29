package com.hsv2.hsv2_lite.mediapipe

data class DetectionResult(
    // MediaPipe detection
    val className: String,
    val score: Float,
    val box: BoundingBox,

    // P3.2.2: Robust distance
    val distanceMeters: Float?,

    // P3.2.3: 3D position in D455 depth-camera frame
    val xMeters: Float?,
    val yMeters: Float?,
    val zMeters: Float?,

    // P3.2.4: Direction
    val direction: String?,
    val horizontalDirection: String?,
    val angleDegrees: Float?,

    // P3.2.5: Ground-plane cross-check
    val groundPlaneDistanceMeters: Float?,
    val groundPlaneValid: Boolean,
    val groundPlaneUsingFallback: Boolean,

    // P3.2.1: RGB -> depth ROI
    val depthBox: BoundingBox?
)


fun DetectionResult.toFlutterMap(): Map<String, Any?> {
    return mapOf(
        "class" to className,
        "score" to score,

        "left" to box.left,
        "top" to box.top,
        "right" to box.right,
        "bottom" to box.bottom,

        "distanceMeters" to distanceMeters,

        "xMeters" to xMeters,
        "yMeters" to yMeters,
        "zMeters" to zMeters,

        "direction" to direction,
        "horizontalDirection" to horizontalDirection,
        "angleDegrees" to angleDegrees,

        "groundPlaneDistanceMeters" to groundPlaneDistanceMeters,
        "groundPlaneValid" to groundPlaneValid,
        "groundPlaneUsingFallback" to groundPlaneUsingFallback,

        "depthBox" to depthBox?.let {
            mapOf(
                "left" to it.left,
                "top" to it.top,
                "right" to it.right,
                "bottom" to it.bottom
            )
        }
    )
}
