import 'mock_pipeline.dart';
import 'vision_models.dart';

const bool kUseMock = true; // asli models judne par false

VisionPipeline createPipeline() {
  // TODO: kUseMock false ho to TfliteVisionPipeline() return karo
  return MockVisionPipeline();
}