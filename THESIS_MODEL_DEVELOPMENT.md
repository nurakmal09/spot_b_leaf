# Chapter 3: Banana Disease Image Classification Model Development

## 3.1 Model Architecture

The banana leaf disease classification system employs EfficientNet-B0 architecture with transfer learning. This approach leverages pre-trained ImageNet weights to overcome the limited dataset size (669 original images) while maintaining mobile deployment efficiency.

### 3.1.1 Architecture Overview

The model consists of two main components:

**1. EfficientNet-B0 Base (Feature Extractor)**
- Pre-trained on ImageNet (1.4M images)
- Mobile inverted bottleneck convolution (MBConv) blocks
- ~4M parameters, initially frozen to preserve learned features
- Global average pooling reduces output to 1280-dimensional features

**2. Custom Classification Head**
- Dense layers: 256 → 128 neurons with ReLU activation
- Batch normalization after each dense layer
- Progressive dropout (0.5 → 0.4 → 0.3) for regularization
- Softmax output layer for 6 disease classes

Transfer learning was chosen to leverage ImageNet knowledge and compensate for the limited dataset size, while the frozen base model prevents overfitting.

**Implementation:**

```python
def build_efficientnet_b0_model():
    """Build EfficientNet-B0 model with transfer learning"""
    # Load pre-trained EfficientNetB0 without top layers
    base_model = EfficientNetB0(
        include_top=False,
        weights='imagenet',
        input_shape=(224, 224, 3),
        pooling='avg'
    )
    
    # Freeze base model layers
    base_model.trainable = False
    
    # Build complete model with custom classification head
    model = models.Sequential([
        layers.Input(shape=(224, 224, 3)),
        base_model,
        layers.BatchNormalization(),
        layers.Dropout(0.5),
        layers.Dense(256, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.4),
        layers.Dense(128, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        layers.Dense(6, activation='softmax')  # 6 disease classes
    ])
    
    return model
```

### 3.1.2 Model Configuration

| Parameter | Value | Justification |
|-----------|-------|---------------|
| Input Size | 224×224×3 | Standard for EfficientNet-B0, mobile-optimized |
| Batch Size | 16 | Balanced for GPU memory and gradient stability |
| Epochs | 50 | Sufficient for transfer learning with early stopping |
| Learning Rate | 0.0005 | Conservative rate for fine-tuning |
| Data Split | 70-15-15 | Train-Validation-Test distribution |
| Total Parameters | ~5.3M | 4M (base) + 1.3M (classification head) |

**Disease Classes:** Black Sigatoka, Bract Mosaic Virus, Cordana, Healthy Leaf, Panama, Pestalotiopsis

## 3.2 Dataset Preparation

### 3.2.1 Dataset Overview

The banana leaf disease dataset consists of 669 original images distributed across six classes:

| Class Name | Original Images | Percentage |
|------------|----------------|------------|
| Black Sigatoka Disease | 90 | 13.45% |
| Bract Mosaic Virus Disease | 50 | 7.47% |
| Cordana Disease | 206 | 30.79% |
| Healthy Leaf | 109 | 16.29% |
| Panama Disease | 41 | 6.13% |
| Pestalotiopsis Disease | 173 | 25.86% |

### 3.2.2 Data Augmentation Strategy

To address class imbalance and limited dataset size, augmentation techniques were applied:

**Augmentation Techniques:**
- Geometric: Rotation (±30°), shifts (±20%), shear (20%), zoom (±20%)
- Photometric: Brightness adjustment (0.7-1.3x), horizontal/vertical flips
- Target: Minimum 300 samples per class
- Result: 669 original images → 2,654 augmented images

**Preprocessing:**
- Pixel normalization to [0, 1] range
- Real-time augmentation during training
- No augmentation on validation/test sets

**Implementation:**

```python
# Data augmentation configuration
train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=15,
    width_shift_range=0.1,
    height_shift_range=0.1,
    shear_range=0.1,
    zoom_range=0.1,
    horizontal_flip=True,
    fill_mode='nearest'
)

# Validation/Test data (no augmentation)
val_test_datagen = ImageDataGenerator(rescale=1./255)
```

## 3.3 Training Strategy

### 3.3.1 Training Configuration

**Optimization:**
- Optimizer: Adam with learning rate 0.0005
- Loss function: Categorical crossentropy
- Metrics: Accuracy and Top-2 accuracy

**Regularization Techniques:**
- Early stopping (patience=15 epochs, monitors validation loss)
- Learning rate reduction on plateau (factor=0.5, patience=8 epochs)
- Class weight balancing for imbalanced dataset
- Progressive dropout in classification head

**Implementation:**

```python
# Model compilation
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.0005),
    loss='categorical_crossentropy',
    metrics=['accuracy', keras.metrics.TopKCategoricalAccuracy(k=2)]
)

# Training callbacks
callbacks = [
    ModelCheckpoint('best_model.keras', monitor='val_accuracy', 
                    save_best_only=True),
    EarlyStopping(monitor='val_loss', patience=15, 
                  restore_best_weights=True),
    ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=8)
]

# Train model
history = model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=100,
    callbacks=callbacks,
    class_weight=class_weights
)
```

## 3.4 Results and Performance

### 3.4.1 Overall Performance

- **Best Validation Accuracy**: 94.07% (Epoch 71)
- **Final Training Accuracy**: 97.94%
- **Final Validation Accuracy**: 89.07%
- **Training Duration**: 86 epochs (early stopped)
- **Model Size**: ~20 MB (TFLite format)

### 3.4.2 Per-Class Performance

| Disease Class | Accuracy | Original Samples |
|--------------|----------|------------------|
| Healthy Leaf | 98.89% | 109 (16.29%) |
| Black Sigatoka | 97.78% | 90 (13.45%) |
| Cordana | 97.78% | 206 (30.79%) |
| Bract Mosaic Virus | 96.67% | 50 (7.47%) |
| Pestalotiopsis | 87.78% | 173 (25.86%) |
| Panama | 85.56% | 41 (6.13%) |

Healthy leaves achieved the highest accuracy due to distinctive features. Panama Disease showed lower accuracy due to limited training samples (41 images) and symptom similarity with other diseases.

## 3.5 Mobile Deployment

The trained model was converted to TensorFlow Lite format for mobile deployment:

- **Format**: TensorFlow Lite (.tflite)
- **Model Size**: ~20 MB
- **Target Platform**: Android mobile devices
- **Inference Time**: < 500ms per image on mid-range devices
- **Optimization**: DEFAULT quantization for size reduction
- **Integration**: Flutter app with confidence threshold of 0.7

**Implementation:**

```python
# TensorFlow Lite conversion
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS
]

tflite_model = converter.convert()

# Save converted model
with open('efficientnet_b0_94.07.tflite', 'wb') as f:
    f.write(tflite_model)
```

## 3.6 Discussion

### 3.6.1 Model Strengths and Limitations

**Strengths:**
- Achieved 94.07% validation accuracy with limited training data (669 original images)
- Transfer learning leverages ImageNet knowledge, reducing training time and data requirements
- Mobile-optimized architecture (5.3M parameters, ~20 MB)
- Real-time inference capability (< 500ms on mid-range devices)
- Strong performance on diseases with distinctive visual symptoms (>97% for most classes)

**Limitations:**
- Lower accuracy on Panama Disease (85.56%) due to limited samples (41 images)
- Overfitting indicated by train-validation gap (97.94% vs 89.07%)
- Frozen base model may miss disease-specific low-level features
- Limited to 6 disease classes; requires retraining for expansion
- Performance dependent on image quality and lighting conditions

## 3.7 Conclusion

The EfficientNet-B0 transfer learning model achieved 94.07% validation accuracy in classifying six banana leaf disease categories. By leveraging pre-trained ImageNet weights, the model effectively addressed limited training data (669 original images) while maintaining mobile deployment efficiency (5.3M parameters, ~20 MB).

The model demonstrates strong performance on diseases with distinctive visual symptoms (>97% for most classes), though Panama Disease accuracy (85.56%) indicates the need for expanded training data. The transfer learning approach proved effective for this agricultural application, balancing accuracy, model size, and inference speed for real-world mobile deployment.

Future improvements could include fine-tuning the base model layers, expanding the Panama Disease dataset, and implementing attention mechanisms to enhance interpretability and classification accuracy.

---

## References

1. Tan, M., & Le, Q. (2019). EfficientNet: Rethinking Model Scaling for Convolutional Neural Networks. *Proceedings of the 36th International Conference on Machine Learning*.

2. Keras Applications - EfficientNet. TensorFlow Documentation. https://keras.io/api/applications/efficientnet/

3. TensorFlow Lite Converter. TensorFlow Documentation. https://www.tensorflow.org/lite/convert
