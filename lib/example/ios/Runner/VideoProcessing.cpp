#include "VideoProcessing.hpp"
#include <cstring> // for memset

void VideoProcessing::applySepiaFilter(uint8_t *yBuffer, uint8_t *uBuffer,
                                       uint8_t *vBuffer, int yStride,
                                       int uStride, int vStride, int width,
                                       int height) {
  if (!yBuffer || !uBuffer || !vBuffer)
    return;

  // Process Chroma (U and V) for Sepia Effect
  // Standard Neutral Gray is 128 (0x80).
  // Let's use: U = 100 (0x64), V = 160 (0xA0) for a warm, yellowish tint.

  // Calculate chroma dimensions. For I420, dimensions are typically half of Y.
  int chroma_width = (width + 1) / 2;
  int chroma_height = (height + 1) / 2;

  const uint8_t sepia_u = 100;
  const uint8_t sepia_v = 160;

  // Use memset for extremely fast filling
  // Note: This logic assumes stride == width for simplicity, which is true for
  // tight packing but we should respect strides in loop

  // Chroma width is half of Luma width
  // But stride is passed in (which is usually aligned)

  // We overwrite U buffer
  for (int r = 0; r < chroma_height; ++r) {
    uint8_t *row_u = uBuffer + r * uStride;
    memset(row_u, sepia_u, chroma_width);
  }

  // We overwrite V buffer
  for (int r = 0; r < chroma_height; ++r) {
    uint8_t *row_v = vBuffer + r * vStride;
    memset(row_v, sepia_v, chroma_width);
  }
}
