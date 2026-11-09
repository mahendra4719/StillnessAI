package com.yourteam.drishti

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.calib3d.Calib3d
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfDouble
import org.opencv.core.MatOfPoint2f
import org.opencv.core.MatOfPoint3f
import org.opencv.core.Point
import org.opencv.core.Point3
import org.opencv.core.Rect
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Face landmarks + head pose (solvePnP, teammates ke jaisa) + Model 1 eye state. */
class VisionEngine(private val context: Context) {
    companion object {
        private val PNP_IDS = intArrayOf(1, 152, 33, 263, 61, 291)
        private val LEFT_EYE = intArrayOf(362, 385, 387, 263, 373, 380)
        private val RIGHT_EYE = intArrayOf(33, 160, 158, 133, 153, 144)
        private val MEAN = floatArrayOf(0.485f, 0.456f, 0.406f)
        private val STD = floatArrayOf(0.229f, 0.224f, 0.225f)
        // eye crop = eye width ka itna guna. Phone par test karke badalna.
        private const val EYE_CROP_SCALE = 2.0
    }

    private var landmarker: FaceLandmarker? = null
    private var eyeNet: Interpreter? = null
    private var eyeNchw = true
    private var threshold = 0.53f
    private var lastTs = -1L
    private var bmp: Bitmap? = null
    private lateinit var inputBuf: ByteBuffer

    private val model3d by lazy {
        MatOfPoint3f(
            Point3(0.0, 0.0, 0.0), Point3(0.0, 330.0, -65.0),
            Point3(-225.0, -170.0, -135.0), Point3(225.0, -170.0, -135.0),
            Point3(-150.0, 150.0, -125.0), Point3(150.0, 150.0, -125.0),
        )
    }

    private fun loadAsset(name: String): ByteBuffer {
        val bytes = context.assets.open(name).use { it.readBytes() }
        return ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder())
            .also { it.put(bytes); it.rewind() }
    }

    fun init(thr: Double): Map<String, Any?> {
        if (!OpenCVLoader.initLocal()) return mapOf("ok" to false, "error" to "OpenCV load failed")
        threshold = thr.toFloat()
        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("models/face_landmarker.task").build())
            .setRunningMode(RunningMode.VIDEO)
            .setNumFaces(2)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinFacePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setOutputFaceBlendshapes(false)
            .build()
        landmarker = FaceLandmarker.createFromOptions(context, options)
        val net = Interpreter(loadAsset("eye_state.tflite"), Interpreter.Options().setNumThreads(2))
        eyeNet = net
        val inShape = net.getInputTensor(0).shape()
        eyeNchw = inShape.size == 4 && inShape[1] == 3
        inputBuf = ByteBuffer.allocateDirect(4 * 3 * 36 * 60).order(ByteOrder.nativeOrder())
        return mapOf(
            "ok" to true,
            "eyeIn" to inShape.toList(),
            "eyeOut" to net.getOutputTensor(0).shape().toList(),
        )
    }

    fun dispose() {
        try { landmarker?.close() } catch (_: Throwable) {}
        try { eyeNet?.close() } catch (_: Throwable) {}
        landmarker = null
        eyeNet = null
    }

    private fun fillYuv(yuv: Mat, nv21: ByteArray, w: Int, h: Int, stride: Int) {
        val need = w * h * 3 / 2
        if (stride == w) {
            yuv.put(0, 0, if (nv21.size == need) nv21 else nv21.copyOf(need))
        } else {
            val row = ByteArray(w)
            for (r in 0 until h) {
                System.arraycopy(nv21, r * stride, row, 0, w)
                yuv.put(r, 0, row)
            }
            for (r in 0 until h / 2) {
                System.arraycopy(nv21, h * stride + r * stride, row, 0, w)
                yuv.put(h + r, 0, row)
            }
        }
    }

    private fun faceHeight(f: List<NormalizedLandmark>): Float {
        var lo = Float.MAX_VALUE
        var hi = -Float.MAX_VALUE
        for (p in f) { lo = min(lo, p.y()); hi = max(hi, p.y()) }
        return hi - lo
    }

    fun process(nv21: ByteArray, w: Int, h: Int, stride: Int, rotation: Int, tMs: Long): Map<String, Any?> {
        val t0 = System.nanoTime()
        val lm = landmarker ?: return mapOf("error" to "not_initialized")
        val yuv = Mat(h + h / 2, w, CvType.CV_8UC1)
        val rgb = Mat()
        val up = Mat()
        try {
            fillYuv(yuv, nv21, w, h, stride)
            Imgproc.cvtColor(yuv, rgb, Imgproc.COLOR_YUV2RGB_NV21)
            when (rotation) {
                90 -> Core.rotate(rgb, up, Core.ROTATE_90_CLOCKWISE)
                180 -> Core.rotate(rgb, up, Core.ROTATE_180)
                270 -> Core.rotate(rgb, up, Core.ROTATE_90_COUNTERCLOCKWISE)
                else -> rgb.copyTo(up)
            }
            val iw = up.cols()
            val ih = up.rows()
            var b = bmp
            if (b == null || b.width != iw || b.height != ih) {
                b = Bitmap.createBitmap(iw, ih, Bitmap.Config.ARGB_8888)
                bmp = b
            }
            Utils.matToBitmap(up, b!!)
            val ts = max(tMs, lastTs + 1)
            lastTs = ts
            val faces = lm.detectForVideo(BitmapImageBuilder(b).build(), ts).faceLandmarks()
            if (faces.isEmpty()) {
                return mapOf("faceCount" to 0, "faceHeightFrac" to 0.0, "poseStatus" to "face_not_detected",
                    "eyeState" to "uncertain", "eyeConf" to 0.0, "inferMs" to ms(t0))
            }
            var best = faces[0]
            var bestH = faceHeight(best)
            for (f in faces.drop(1)) { val hh = faceHeight(f); if (hh > bestH) { best = f; bestH = hh } }

            val out = HashMap<String, Any?>()
            out["faceCount"] = faces.size
            out["faceHeightFrac"] = bestH.toDouble()
            pose(best, iw, ih, out)

            val pl = eyeClosedProb(up, best, LEFT_EYE, iw, ih)
            val pr = eyeClosedProb(up, best, RIGHT_EYE, iw, ih)
            val probs = listOfNotNull(pl, pr)
            if (probs.isEmpty()) {
                out["eyeState"] = "uncertain"; out["eyeConf"] = 0.0
            } else {
                val p = probs.average().toFloat()
                val closed = p >= threshold
                val conf = if (closed) p else 1f - p
                out["closedProb"] = p.toDouble()
                out["eyeConf"] = conf.toDouble()
                out["eyeState"] = if (conf >= 0.5f) (if (closed) "closed" else "open") else "uncertain"
            }
            out["inferMs"] = ms(t0)
            return out
        } finally {
            yuv.release(); rgb.release(); up.release()
        }
    }

    private fun ms(t0: Long) = ((System.nanoTime() - t0) / 1_000_000).toInt()

    /** pose_estimator.py ka same logic: 6 landmarks, solvePnP ITERATIVE, approx camera. */
    private fun pose(lms: List<NormalizedLandmark>, w: Int, h: Int, out: MutableMap<String, Any?>) {
        val pts = ArrayList<Point>()
        var minX = Double.MAX_VALUE; var maxX = -Double.MAX_VALUE
        var minY = Double.MAX_VALUE; var maxY = -Double.MAX_VALUE
        for (i in PNP_IDS) {
            val x = lms[i].x().toDouble(); val y = lms[i].y().toDouble()
            if (!x.isFinite() || !y.isFinite() || x < -0.05 || x > 1.05 || y < -0.05 || y > 1.05) {
                out["poseStatus"] = "unreliable_landmarks"; return
            }
            val px = x * w; val py = y * h
            pts.add(Point(px, py))
            minX = min(minX, px); maxX = max(maxX, px); minY = min(minY, py); maxY = max(maxY, py)
        }
        if (maxX - minX < w * 0.12 || maxY - minY < h * 0.12) {
            out["poseStatus"] = "face_too_small"; return
        }
        val imgPts = MatOfPoint2f(*pts.toTypedArray())
        val focal = max(w, h) * 1.2
        val k = Mat(3, 3, CvType.CV_64F)
        k.put(0, 0, focal, 0.0, w / 2.0, 0.0, focal, h / 2.0, 0.0, 0.0, 1.0)
        val dist = MatOfDouble(0.0, 0.0, 0.0, 0.0, 0.0)
        val rvec = Mat(); val tvec = Mat(); val rot = Mat(); val proj = MatOfPoint2f()
        try {
            val ok = Calib3d.solvePnP(model3d, imgPts, k, dist, rvec, tvec, false, Calib3d.SOLVEPNP_ITERATIVE)
            if (!ok) { out["poseStatus"] = "solvepnp_failed"; return }
            Calib3d.Rodrigues(rvec, rot)
            Calib3d.projectPoints(model3d, rvec, tvec, k, dist, proj)
            val pp = proj.toArray()
            var se = 0.0
            for (i in pp.indices) {
                val dx = pp[i].x - pts[i].x; val dy = pp[i].y - pts[i].y
                se += dx * dx + dy * dy
            }
            val err = sqrt(se / pp.size)
            val r = DoubleArray(9); rot.get(0, 0, r)
            val det = r[0] * (r[4] * r[8] - r[5] * r[7]) - r[1] * (r[3] * r[8] - r[5] * r[6]) +
                r[2] * (r[3] * r[7] - r[4] * r[6])
            val tz = DoubleArray(3); tvec.get(0, 0, tz)
            if (!err.isFinite() || err > 60.0 || det < 0.8 || det > 1.2 || tz[2] <= 0.0) {
                out["poseStatus"] = "invalid_pose"; return
            }
            out["yaw"] = Math.toDegrees(atan2(-r[6], hypot(r[0], r[3])))
            out["pitch"] = Math.toDegrees(atan2(r[7], r[8]))
            out["roll"] = Math.toDegrees(atan2(r[3], r[0]))
            out["reprojErr"] = err
            out["poseStatus"] = "tracked"
        } finally {
            imgPts.release(); k.release(); dist.release(); rvec.release(); tvec.release()
            rot.release(); proj.release()
        }
    }

    /** Ek aankh ka crop -> Model 1 -> CLOSED_OR_BLINK probability (null = crop nahi ban paya). */
    private fun eyeClosedProb(img: Mat, lms: List<NormalizedLandmark>, ids: IntArray, w: Int, h: Int): Float? {
        var minX = Double.MAX_VALUE; var maxX = -Double.MAX_VALUE
        var minY = Double.MAX_VALUE; var maxY = -Double.MAX_VALUE
        for (i in ids) {
            val x = lms[i].x() * w.toDouble(); val y = lms[i].y() * h.toDouble()
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
        val ew = maxX - minX
        if (!(ew > 4.0)) return null
        val cw = ew * EYE_CROP_SCALE
        val ch = cw * 36.0 / 60.0
        val cx = (minX + maxX) / 2; val cy = (minY + maxY) / 2
        val x1 = max(0, floor(cx - cw / 2).toInt()); val x2 = min(w, ceil(cx + cw / 2).toInt())
        val y1 = max(0, floor(cy - ch / 2).toInt()); val y2 = min(h, ceil(cy + ch / 2).toInt())
        if (x2 - x1 < 20 || y2 - y1 < 12) return null

        val roi = Mat(img, Rect(x1, y1, x2 - x1, y2 - y1))
        val small = Mat()
        val shrinking = roi.cols() > 60 || roi.rows() > 36
        Imgproc.resize(roi, small, Size(60.0, 36.0), 0.0, 0.0,
            if (shrinking) Imgproc.INTER_AREA else Imgproc.INTER_LINEAR)
        val px = ByteArray(60 * 36 * 3)
        small.get(0, 0, px)
        roi.release(); small.release()

        val buf = inputBuf
        buf.rewind()
        if (eyeNchw) {
            for (c in 0 until 3) for (y in 0 until 36) for (x in 0 until 60) {
                val v = (px[(y * 60 + x) * 3 + c].toInt() and 0xFF) / 255f
                buf.putFloat((v - MEAN[c]) / STD[c])
            }
        } else {
            for (y in 0 until 36) for (x in 0 until 60) for (c in 0 until 3) {
                val v = (px[(y * 60 + x) * 3 + c].toInt() and 0xFF) / 255f
                buf.putFloat((v - MEAN[c]) / STD[c])
            }
        }
        buf.rewind()
        val outArr = Array(1) { FloatArray(2) }
        eyeNet!!.run(buf, outArr)
        val a = outArr[0][0]; val b = outArr[0][1]
        val m = max(a, b)
        val ea = exp(a - m); val eb = exp(b - m)
        return eb / (ea + eb) // index 1 = CLOSED_OR_BLINK
    }
}