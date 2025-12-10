# Backend Resources - Model Training Pipeline

This folder contains resources for training and retraining the Custom CNN banana leaf disease detection model.

## 📁 Directory Structure

```
backend/
├── dataset/                              # Training dataset (669 images)
│   ├── Black Sigatoka Disease/          # 90 images
│   ├── Bract Mosaic Virus Disease/      # 50 images
│   ├── Cordana Disease/                 # 206 images
│   ├── Healthy Leaf/                    # 109 images
│   ├── Panama Disease/                  # 41 images
│   ├── Pestalotiopsis Disease/          # 173 images
│   ├── README.md                        # Dataset documentation
│   └── dataset_info.json                # Dataset metadata
├── dataset_augmented/                    # Auto-generated (300 images per class)
├── training_output/                      # Auto-generated training results
│   ├── models/                          # Saved models (.keras, .tflite)
│   ├── graphs/                          # Accuracy, loss, confusion matrix
│   └── logs/                            # Training logs, metrics
├── train_model.py                        # Python training script
├── config.py                            # Configuration settings
└── BACKEND_README.md                    # This file
```

## 🚀 Quick Start - Model Training

### Python Script (Automated)
```powershell
# Activate virtual environment (if using one)
.venv\Scripts\Activate.ps1

# Install dependencies
pip install tensorflow keras numpy pillow matplotlib seaborn scikit-learn pandas

# Run training
python train_model.py
```

## 📦 Required Installations

### Install Python Packages
```powershell
pip install tensorflow keras numpy pillow matplotlib seaborn scikit-learn pandas
```

**What gets installed:**
- `tensorflow>=2.20.0` - Deep learning framework
- `keras>=3.0.0` - Neural networks API
- `numpy>=1.24.0` - Numerical computing
- `pillow>=10.0.0` - Image processing
- `matplotlib>=3.8.0` - Graph plotting
- `seaborn>=0.13.0` - Statistical visualization
- `scikit-learn>=1.3.0` - ML metrics (confusion matrix)
- `pandas>=2.0.0` - Data analysis

## 🤖 Model Information

- **Architecture:** Custom CNN (4 convolutional blocks)
- **Input Size:** 224x224x3 RGB images
- **Output Classes:** 6 (1 Healthy + 5 diseases)
- **Training Strategy:** Built-from-scratch with heavy regularization
- **Current Model:** `../assets/models/customcnn_94.07.tflite`
- **Validation Accuracy:** 94.07%
- **Training Date:** December 11, 2025

### Model Architecture
```
Input (224x224x3)
├── Conv Block 1: Conv2D(32) → BatchNorm → MaxPool → Dropout(0.25)
├── Conv Block 2: Conv2D(64) → BatchNorm → MaxPool → Dropout(0.25)
├── Conv Block 3: Conv2D(128) → BatchNorm → MaxPool → Dropout(0.3)
├── Conv Block 4: Conv2D(256) → BatchNorm → MaxPool → Dropout(0.3)
├── Flatten
├── Dense(256) → BatchNorm → Dropout(0.5)
├── Dense(128) → BatchNorm → Dropout(0.5)
└── Dense(6, softmax)
```
## 🔄 Model Retraining Workflow

1. **Add New Images** to appropriate `dataset/` folders
2. **Clean Previous Augmented Data** (optional):
   ```powershell
   Remove-Item backend\dataset_augmented -Recurse -Force
├── Dense(128) → BatchNorm → Dropout(0.5)
└── Dense(6, softmax)
```

### Per-Class Performance
| Disease Class | Accuracy | Precision | Recall | F1-Score |
|---------------|----------|-----------|--------|----------|
| Black Sigatoka Disease | 97.78% | 90.72% | 97.78% | 94.12% |
| Bract Mosaic Virus Disease | 96.67% | 91.58% | 96.67% | 94.05% |
| Cordana Disease | 97.78% | 91.67% | 97.78% | 94.62% |
| Healthy Leaf | 98.89% | 96.74% | 98.89% | 97.80% |
| Panama Disease | 85.56% | 100.00% | 85.56% | 92.22% |
| Pestalotiopsis Disease | 87.78% | 95.18% | 87.78% | 91.33% |

## 📊 Dataset Statistics

- **Total Images:** 669 (original), 1,800 (after augmentation)
- **Classes:** 6
- **Augmentation Target:** 300 images per class
   # Copy labels
   Copy-Item "backend\training_output\models\labels_*.txt" `
             "assets\models\labels.txt" -Force
   ```
6. **Rebuild Flutter App:**
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

## 💡 Training Tips & Recommendations

### Data Augmentation Disease: 90 images (13.45%)
  - ❌ Bract Mosaic Virus Disease: 50 images (7.47%) - NEEDS MORE DATA
  - ✅ Cordana Disease: 206 images (30.79%)
  - ⚠️ Healthy Leaf: 109 images (16.29%)
  - ❌ Panama Disease: 41 images (6.13%) - SEVERELY UNDER-REPRESENTED
  - ⚠️ Pestalotiopsis Disease: 173 images (25.86%)

## 🔄 Model Retraining Workflow
   python train_model.py
   ```
4. **Review Results** in `training_output/graphs/`
   - Check accuracy/loss curves
   - Review confusion matrix
   - Verify per-class performance
5. **Copy Best Model to App:**
   ```powershell
   # Model files are automatically named with accuracy
   # Example: customcnn_94.07.tflite
   
   # Copy TFLite model (use actual filename from training output)
   Copy-Item "backend\training_output\models\customcnn_*.tflite" `
             "assets\models\" -Force
   
   # Copy labels
### Data Augmentation
The training script automatically applies **two-phase augmentation**:

**Heavy Augmentation (for minority classes to reach 300 images):**
- ✅ Rotation (±30°)
- ✅ Width/Height shifts (±20%)
- ✅ Zoom (±20%)
- ✅ Horizontal flips
- ✅ Brightness adjustment (70-130%)

**Moderate Augmentation (during training):**
- ✅ Rotation (±15°)
- ✅ Width/Height shifts (±10%)
- ✅ Zoom (±10%)
- ✅ Horizontal flips

BATCH_SIZE = 16           # Reduced from 32 to prevent memory errors
EPOCHS = 100              # Max epochs (early stopping may stop sooner)
LEARNING_RATE = 0.0005    # Initial learning rate (reduced during training)
IMAGE_SIZE = 224x224      # Input resolution
OPTIMIZER = Adam          # Optimization algorithm
AUGMENTATION_TARGET = 300 # Images per class after augmentation
```

### Training Callbacks
- **Model Checkpoint:** Saves best model (highest validation accuracy)
- **Early Stopping:** Stops if no improvement for 15 epochs
- **ReduceLROnPlateau:** Reduces LR by 50% if loss plateaus (patience: 8 epochs)

## 🎯 Current Performance Metrics

- **Overall Accuracy:** ✅ 94.07% (Target: >90%)
- **Per-Class Accuracy:** ✅ 85-99% for all diseases
- **Best Classes:** Healthy Leaf (98.89%), Black Sigatoka (97.78%), Cordana (97.78%)
- **Challenging Classes:** Panama Disease (85.56%), Pestalotiopsis (87.78%)
- **Top-2 Accuracy:** ✅ 99%+ (correct answer in top 2 guesses)
### Class Balancing Strategy
**Current:** Weighted loss function (automatic)
- Gives higher importance to minority classes
- Prevents model bias toward majority classes

**Recommended Improvements:**
- 🎯 **Bract Mosaic Virus:** Collect 250-300+ more images
- 🎯 **Pestalotiopsis:** Collect 150-200+ more images

### Hyperparameters (Current Settings)
```python
BATCH_SIZE = 32           # Number of images per training step
## 🐛 Troubleshooting

### "No module named tensorflow"
```powershell
pip install tensorflow keras
```

### JSONDecodeError when loading dataset_info.json
The file may have BOM encoding. Recreate it:
```powershell
cd backend
$content = '{"dataset_name":"Banana Leaf Disease Dataset v2.0","total_images":669,"num_classes":6,"classes":{"Black Sigatoka Disease":90,"Bract Mosaic Virus Disease":50,"Cordana Disease":206,"Healthy Leaf":109,"Panama Disease":41,"Pestalotiopsis Disease":173},"created_date":"2025-12-11"}'
[System.IO.File]::WriteAllText('dataset\dataset_info.json', $content, [System.Text.UTF8Encoding]::new($false))
```

### Out of Memory Error
The batch size is already optimized at 16. If still having issues:
```python
# Edit train_model.py
BATCH_SIZE = 8  # Reduce from 16 to 8
```

### Model Predicting Only One Class
- ✅ Check class weights are balanced (script does this automatically)
- ✅ Ensure data augmentation is working
- ✅ Verify all classes have sufficient samples after augmentation

### Low Accuracy on Specific Disease
- ✅ Collect more **diverse** original images for that class
- ✅ Check for blurry/mislabeled images
- ✅ Review confusion matrix to see which classes get confused
- ✅ Increase augmentation target in config.py
### Out of Memory Error
Edit `train_model.py` or notebook cell:
```python
BATCH_SIZE = 16  # Reduce from 32 to 16 (or 8)
```

### Jupyter Won't Open
```powershell
# Install Jupyter
pip install jupyter notebook

# Or use VS Code's Jupyter extension
- ✅ Review confusion matrix to see which classes get confused
- ✅ Increase augmentation target in config.py

## 🔗 Integration with Flutter Appng on small dataset
- Lessons: Pre-trained models too complex for 669-image dataset

### ❌ Attempt 2: EfficientNetB0 (Dec 10, 2025)
- First try: 27.22% (model collapse - predicted only one class)
- Second try: 16.85% (after fixing class weights)
- Issues: Still too complex, severe class imbalance problems

### ✅ Attempt 3: Custom CNN (Dec 11, 2025)
- Accuracy: **94.07%**
- Solution: Lightweight architecture, heavy regularization, balanced augmentation
- Training time: 86 epochs (early stopped at best: epoch 71)

---
**Last Updated:** December 11, 2025  
**Model Version:** Custom CNN (94.07% accuracy)  
**Best Epoch:** 71/86

### Confusion Matrix
- **Diagonal (bright):** Correct predictions ✅
- **Off-diagonal (dark):** Misclassifications ❌
- Look for patterns (e.g., "Panama confused with Sigatoka")

## 🔗 Integration with Flutter App

After training successfully:
1. ✅ Locate files in `training_output/models/`
2. ✅ Copy `.tflite` to `assets/models/spotbleaf_model_50epochs.tflite`
3. ✅ Copy `labels.txt` to `assets/models/spotbleaf_model_labels.txt`
4. ✅ Rebuild app: `flutter clean && flutter build apk`
5. ✅ Test in Scanner page (Disease mode)

---
**Last Updated:** December 2025  
**Model Version:** MobileNetV3Large (50 epochs)
---
**Last Updated:** December 11, 2025  
**Model Version:** Custom CNN (94.07% accuracy)  
**Best Epoch:** 71/86