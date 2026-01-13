#include <cstdint>
#include <cstring> // for memset
#include <jni.h>

extern "C" {

// JNI Function:
// Java_io_agora_agora_1rtc_1flutter_1example_VideoRawDataController_nativeApplySepiaFilter
// Corresponds to Kotlin class:
// io.agora.agora_rtc_flutter_example.VideoRawDataController
JNIEXPORT void JNICALL
Java_io_agora_agora_1rtc_1flutter_1example_VideoRawDataController_nativeApplySepiaFilter(
    JNIEnv *env, jobject thiz, jobject y_buffer, jobject u_buffer,
    jobject v_buffer, jint y_stride, jint u_stride, jint v_stride, jint width,
    jint height) {

  // 1. Get Direct Buffer Addresses (Zero-copy)
  uint8_t *src_y = (uint8_t *)env->GetDirectBufferAddress(y_buffer);
  uint8_t *src_u = (uint8_t *)env->GetDirectBufferAddress(u_buffer);
  uint8_t *src_v = (uint8_t *)env->GetDirectBufferAddress(v_buffer);

  if (!src_y || !src_u || !src_v)
    return;

  // 2. Process Chroma (U and V) for Sepia Effect
  // Sepia Tone: U (Blue-difference) tends lower, V (Red-difference) tends
  // higher. Standard Neutral Gray is 128 (0x80). Let's use: U = 100 (0x64), V =
  // 160 (0xA0) for a warm, yellowish tint.

  // Calculate chroma dimensions. For I420, dimensions are typically half of Y.
  // Note: The provided width/height are the frame dimensions (Y dimensions).
  // The exact chroma size depends on the actual buffer capacity or stride,
  // but assuming standard I420 packing for the active region:
  int chroma_width = (width + 1) / 2;
  int chroma_height = (height + 1) / 2;

  // We process row by row to respect the stride (though typically stride ==
  // width for chroma often)
  const uint8_t sepia_u = 100;
  const uint8_t sepia_v = 160;

  for (int r = 0; r < chroma_height; ++r) {
    uint8_t *row_u = src_u + r * u_stride;
    uint8_t *row_v = src_v + r * v_stride;

    // Use memset for extremely fast filling
    memset(row_u, sepia_u, chroma_width);
    memset(row_v, sepia_v, chroma_width);
  }
}
}
