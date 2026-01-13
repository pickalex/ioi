#ifndef VideoProcessing_hpp
#define VideoProcessing_hpp

#include <cstdint>

class VideoProcessing {
public:
  static void applySepiaFilter(uint8_t *yBuffer, uint8_t *uBuffer,
                               uint8_t *vBuffer, int yStride, int uStride,
                               int vStride, int width, int height);
};

#endif /* VideoProcessing_hpp */
