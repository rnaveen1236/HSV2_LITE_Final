package com.hsv2.hsv2_lite.mediapipe

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetectorResult

class MediaPipeDetector(
    private val context: Context
) {

    companion object {
        private const val TAG = "MediaPipeDetector"
        private const val MODEL_NAME = "efficientdet_lite0.tflite"
        private const val SCORE_THRESHOLD = 0.30f
        private const val MAX_RESULTS = 10
    }

    private var objectDetector: ObjectDetector? = null

    fun initialize() {

        if (objectDetector != null) {
            return
        }

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(MODEL_NAME)
            .build()

        val options = ObjectDetector.ObjectDetectorOptions.builder()
            .setBaseOptions(baseOptions)
            .setScoreThreshold(SCORE_THRESHOLD)
            .setMaxResults(MAX_RESULTS)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        objectDetector = ObjectDetector.createFromOptions(
            context,
            options
        )

        Log.d(
            TAG,
            "MediaPipe ObjectDetector initialized with $MODEL_NAME"
        )
    }

    fun detect(
        bitmap: Bitmap,
        timestampMs: Long
    ): List<Detection> {

        initialize()

        val detector = objectDetector
            ?: return emptyList()

        return try {

            val mpImage = BitmapImageBuilder(bitmap).build()

            val result: ObjectDetectorResult =
                detector.detect(mpImage)

            val detections = mutableListOf<Detection>()

            for (detection in result.detections()) {

                val categories = detection.categories()

                if (categories.isEmpty()) {
                    continue
                }

                val category = categories[0]

                val boundingBox = detection.boundingBox()

                detections.add(
                    Detection(
                        className =
                            category.categoryName(),
                        score =
                            category.score(),
                        left =
                            boundingBox.left.toFloat(),
                        top =
                            boundingBox.top.toFloat(),
                        right =
                            boundingBox.right.toFloat(),
                        bottom =
                            boundingBox.bottom.toFloat()
                    )
                )
            }

            Log.d(
                TAG,
                "Detection count=${detections.size}, timestamp=$timestampMs"
            )

            detections

        } catch (e: Exception) {

            Log.e(
                TAG,
                "MediaPipe detection failed",
                e
            )

            emptyList()
        }
    }

    fun close() {

        objectDetector?.close()
        objectDetector = null

        Log.d(TAG, "MediaPipe detector closed")
    }
}
