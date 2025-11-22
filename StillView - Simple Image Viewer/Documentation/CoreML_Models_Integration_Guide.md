# Core ML Models Integration Guide

## Project Structure for Core ML Models

### 1. Create Models Directory
```
StillView - Simple Image Viewer/
├── Resources/
│   ├── Assets.xcassets/
│   ├── CoreMLModels/           # New directory for Core ML models
│   │   ├── ObjectDetection/
│   │   │   ├── ObjectDetectionModel.mlmodelc
│   │   │   └── ObjectDetectionModel.mlmodel
│   │   ├── TextRecognition/
│   │   │   ├── TextRecognitionModel.mlmodelc
│   │   │   └── TextRecognitionModel.mlmodel
│   │   ├── SceneUnderstanding/
│   │   │   ├── SceneUnderstandingModel.mlmodelc
│   │   │   └── SceneUnderstandingModel.mlmodel
│   │   ├── CompositionAnalysis/
│   │   │   ├── CompositionAnalysisModel.mlmodelc
│   │   │   └── CompositionAnalysisModel.mlmodel
│   │   └── QualityAssessment/
│   │       ├── QualityAssessmentModel.mlmodelc
│   │       └── QualityAssessmentModel.mlmodel
│   └── whats-new.json
```

### 2. Xcode Project Configuration

#### Add Models to Xcode Project
1. **Open Xcode Project**: `StillView - Simple Image Viewer.xcodeproj`
2. **Right-click on Resources folder** → Add Files to "StillView - Simple Image Viewer"
3. **Select CoreMLModels directory** and ensure "Add to target" is checked
4. **Verify models are added** to the project navigator

#### Configure Build Settings
1. **Select project** in navigator
2. **Select target** "StillView - Simple Image Viewer"
3. **Build Settings** → Search for "Core ML"
4. **Set Core ML Model Compilation** to "Yes"
5. **Set Core ML Model Optimization** to "All"

#### Configure Info.plist
Add Core ML usage description:
```xml
<key>NSMLModelUsageDescription</key>
<string>This app uses Core ML models to enhance image analysis and provide better AI insights.</string>
```

### 3. Model Integration Code

#### Update CoreMLModelManager.swift
The CoreMLModelManager is already configured to load models from the bundle. Ensure the model names match:

```swift
enum CoreMLModelType: String, CaseIterable, Codable {
    case objectDetection = "object_detection"
    case textRecognition = "text_recognition"
    case sceneUnderstanding = "scene_understanding"
    case compositionAnalysis = "composition_analysis"
    case qualityAssessment = "quality_assessment"
    
    var modelName: String {
        switch self {
        case .objectDetection: return "ObjectDetectionModel"
        case .textRecognition: return "TextRecognitionModel"
        case .sceneUnderstanding: return "SceneUnderstandingModel"
        case .compositionAnalysis: return "CompositionAnalysisModel"
        case .qualityAssessment: return "QualityAssessmentModel"
        }
    }
}
```

### 4. Model Acquisition Steps

#### Step 1: Download Models from Apple Model Gallery
1. **Visit**: https://developer.apple.com/machine-learning/models/
2. **Download**: ResNet50, YOLOv3, MobileNet
3. **Place in**: `Resources/CoreMLModels/` directory

#### Step 2: Download Models from Hugging Face
1. **Visit**: https://huggingface.co/models?library=coreml
2. **Download**: CLIP, TrOCR, DETR models
3. **Convert if needed**: Use Core ML Tools for conversion

#### Step 3: Download Models from Awesome-CoreML-Models
1. **Visit**: https://github.com/likedan/Awesome-CoreML-Models
2. **Download**: YOLOv8, EfficientNet models
3. **Place in**: Appropriate subdirectories

### 5. Model Conversion (if needed)

#### Convert TensorFlow Models
```python
import coremltools as ct
import tensorflow as tf

# Load TensorFlow model
tf_model = tf.keras.models.load_model('path/to/model.h5')

# Convert to Core ML
coreml_model = ct.convert(
    tf_model,
    inputs=[ct.ImageType(shape=(1, 224, 224, 3), scale=1/255.0)]
)

# Save Core ML model
coreml_model.save('MyModel.mlmodel')
```

#### Convert PyTorch Models
```python
import coremltools as ct
import torch

# Load PyTorch model
pytorch_model = torch.load('path/to/model.pth')

# Convert to Core ML
coreml_model = ct.convert(
    pytorch_model,
    inputs=[ct.ImageType(shape=(1, 3, 224, 224), scale=1/255.0)]
)

# Save Core ML model
coreml_model.save('MyModel.mlmodel')
```

### 6. Model Testing and Validation

#### Create Model Test Suite
```swift
import XCTest
import CoreML

class CoreMLModelTests: XCTestCase {
    
    func testObjectDetectionModel() throws {
        let model = try MLModel(contentsOf: Bundle.main.url(forResource: "ObjectDetectionModel", withExtension: "mlmodelc")!)
        XCTAssertNotNil(model)
        
        // Test model input/output descriptions
        let inputDescription = model.modelDescription.inputDescriptionsByName["image"]
        XCTAssertNotNil(inputDescription)
    }
    
    func testTextRecognitionModel() throws {
        let model = try MLModel(contentsOf: Bundle.main.url(forResource: "TextRecognitionModel", withExtension: "mlmodelc")!)
        XCTAssertNotNil(model)
    }
    
    func testSceneUnderstandingModel() throws {
        let model = try MLModel(contentsOf: Bundle.main.url(forResource: "SceneUnderstandingModel", withExtension: "mlmodelc")!)
        XCTAssertNotNil(model)
    }
    
    func testCompositionAnalysisModel() throws {
        let model = try MLModel(contentsOf: Bundle.main.url(forResource: "CompositionAnalysisModel", withExtension: "mlmodelc")!)
        XCTAssertNotNil(model)
    }
    
    func testQualityAssessmentModel() throws {
        let model = try MLModel(contentsOf: Bundle.main.url(forResource: "QualityAssessmentModel", withExtension: "mlmodelc")!)
        XCTAssertNotNil(model)
    }
}
```

### 7. Performance Optimization

#### Model Optimization Settings
```swift
private func getOptimalComputeUnits() -> MLComputeUnits {
    // Use Neural Engine if available, otherwise GPU, fallback to CPU
    if MLModel.availableComputeDevices.contains(.neuralEngine) {
        return .all
    } else if MLModel.availableComputeDevices.contains(.gpu) {
        return .cpuAndGPU
    } else {
        return .cpuOnly
    }
}
```

#### Memory Management
```swift
private func optimizeModelForMemory(_ model: MLModel) -> MLModel {
    let config = MLModelConfiguration()
    config.computeUnits = getOptimalComputeUnits()
    
    // Configure memory optimization
    config.allowLowPrecisionAccumulationOnGPU = true
    
    return model
}
```

### 8. Integration with Existing Services

#### Update AIImageAnalysisService
```swift
// Add Core ML integration to existing service
private func enhanceWithCoreML(_ result: ImageAnalysisResult) async throws -> ImageAnalysisResult {
    let coreMLManager = CoreMLModelManager.shared
    
    // Enhance with Core ML models
    if let objectModel = try? await coreMLManager.loadModel(.objectDetection) {
        // Process with Core ML model
    }
    
    return result
}
```

#### Update HybridImageAnalysisService
The HybridImageAnalysisService is already configured to use Core ML models through the CoreMLModelManager.

### 9. Deployment Considerations

#### App Store Requirements
- **Model Size**: Keep individual models under 50MB
- **Total Size**: Keep total model size under 200MB
- **Compression**: Use compressed models (.mlmodelc) for production

#### User Experience
- **Loading Time**: Show progress during model loading
- **Fallbacks**: Graceful degradation when models fail
- **Caching**: Efficient model caching for better performance

### 10. Monitoring and Analytics

#### Model Performance Tracking
```swift
func trackModelPerformance(_ modelType: CoreMLModelType, processingTime: TimeInterval, success: Bool) {
    AnalyticsService.shared.trackEvent("coreml_model_performance", properties: [
        "model_type": modelType.rawValue,
        "processing_time": processingTime,
        "success": success
    ])
}
```

#### Error Tracking
```swift
func trackModelError(_ modelType: CoreMLModelType, error: Error) {
    AnalyticsService.shared.trackEvent("coreml_model_error", properties: [
        "model_type": modelType.rawValue,
        "error": error.localizedDescription
    ])
}
```

### 11. Testing Checklist

#### Pre-Deployment Testing
- [ ] All models load successfully
- [ ] Models process images correctly
- [ ] Performance meets requirements
- [ ] Memory usage is acceptable
- [ ] Error handling works properly
- [ ] Fallbacks function correctly
- [ ] User experience is smooth

#### Post-Deployment Monitoring
- [ ] Model loading success rate
- [ ] Processing time metrics
- [ ] Memory usage patterns
- [ ] Error rates and types
- [ ] User satisfaction scores
- [ ] Performance across different hardware

### 12. Troubleshooting

#### Common Issues
1. **Model Loading Failures**: Check model file paths and bundle inclusion
2. **Performance Issues**: Optimize model configuration and compute units
3. **Memory Problems**: Implement model caching and cleanup
4. **Compatibility Issues**: Check macOS version requirements

#### Debug Tools
- **Instruments**: Profile memory and CPU usage
- **Core ML Playground**: Test models interactively
- **Console Logs**: Monitor model loading and processing

This guide provides a complete framework for integrating Core ML models into your StillView project. The implementation is designed to be modular, performant, and user-friendly while maintaining backward compatibility.

