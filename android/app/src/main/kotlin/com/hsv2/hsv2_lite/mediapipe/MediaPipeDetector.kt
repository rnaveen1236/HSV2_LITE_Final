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

        // MediaPipe-only inference resolution.
        // The original D455 frame remains 640x480.
        private const val DETECTOR_WIDTH = 320
        private const val DETECTOR_HEIGHT = 320
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

        var detectorBitmap: Bitmap? = null

        return try {

            // -------------------------------------------------------------
            // Detector-only downscale.
            //
            // The original D455 bitmap remains 640x480 and is still used
            // by the rest of the RGB/depth/XYZ/Fusion pipeline.
            // Only MediaPipe inference uses 320x240.
            // -------------------------------------------------------------

            detectorBitmap =
                Bitmap.createScaledBitmap(
                    bitmap,
                    DETECTOR_WIDTH,
                    DETECTOR_HEIGHT,
                    true
                )

            val scaleX =
                bitmap.width.toFloat() /
                    DETECTOR_WIDTH.toFloat()

            val scaleY =
                bitmap.height.toFloat() /
                    DETECTOR_HEIGHT.toFloat()

            val mpImage =
                BitmapImageBuilder(
                    detectorBitmap
                ).build()

            val result: ObjectDetectorResult =
                detector.detect(mpImage)

            val detections =
                mutableListOf<Detection>()

            for (detection in result.detections()) {

                val categories =
                    detection.categories()

                if (categories.isEmpty()) {
                    continue
                }

                val category =
                    categories[0]

                val boundingBox =
                    detection.boundingBox()

                // MediaPipe coordinates are from the 320x240
                // detector image. Convert them back to the
                // original D455 640x480 coordinate system.
                detections.add(
                    Detection(
                        className =
                            category.categoryName(),
                        score =
                            category.score(),
                        left =
                            boundingBox.left.toFloat() *
                                scaleX,
                        top =
                            boundingBox.top.toFloat() *
                                scaleY,
                        right =
                            boundingBox.right.toFloat() *
                                scaleX,
                        bottom =
                            boundingBox.bottom.toFloat() *
                                scaleY
                    )
                )
            }

            Log.d(
                TAG,
                "Detection count=${detections.size}, " +
                    "timestamp=$timestampMs, " +
                    "input=${bitmap.width}x${bitmap.height}, " +
                    "inference=${DETECTOR_WIDTH}x${DETECTOR_HEIGHT}"
            )

            detections

        } catch (e: Exception) {

            Log.e(
                TAG,
                "MediaPipe detection failed",
                e
            )

            emptyList()

        } finally {

            if (detectorBitmap != null &&
                !detectorBitmap.isRecycled
            ) {
                detectorBitmap.recycle()
            }
        }
    }

    fun close() {

        objectDetector?.close()
        objectDetector = null

        Log.d(
            TAG,
            "MediaPipe detector closed"
        )
    }
}
