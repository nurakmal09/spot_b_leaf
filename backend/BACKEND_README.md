# Backend Resources - Model Training Pipeline

This folder contains resources for training and retraining the MobileNetV3 banana leaf disease detection model.

## 📁 Directory Structure

```
backend/
├── dataset/                     # Training dataset (2,654 images)
│   ├── Bract Mosaic Virus/     # 50 images
│   ├── Cordana/                # 504 images
│   ├── Healthy/                # 632 images
│   ├── Panama Disease/         # 634 images
│   ├── Pestalotiopsis/         # 173 images
│   ├── sigatoka/               # 661 images
│   ├── README.md               # Dataset documentation
│   └── dataset_info.json       # Dataset metadata
├── training_output/            # Auto-generated training results
│   ├── models/                 # Saved models (.keras, .tflite)
│   ├── graphs/                 # Accuracy, loss, confusion matrix
│   └── logs/                   # Training logs, metrics
├── train_model.py              # Python training script
├── train_mobilenetv3.ipynb     # Jupyter notebook (interactive)
├── requirements.txt            # Python dependencies
└── BACKEND_README.md           # This file
```

## 🚀 Quick Start - Model Training

### Option 1: Jupyter Notebook (Recommended for beginners)
```powershell
# Install dependencies
pip install -r requirements.txt

# Launch Jupyter notebook
jupyter notebook train_mobilenetv3.ipynb
```

### Option 2: Python Script (Automated)
```powershell
# Install dependencies
pip install -r requirements.txt

# Run training
python train_model.py
```

## 🚀 Quick Start - Model Training

### Option 1: Jupyter Notebook (Recommended for beginners)
```powershell
# Install dependencies
pip install -r requirements.txt

# Launch Jupyter notebook
jupyter notebook train_mobilenetv3.ipynb
```

### Option 2: Python Script (Automated)
```powershell
# Install dependencies
pip install -r requirements.txt

# Run training
python train_model.py
```

## 📦 Required Installations

### Step 1: Install Python Packages
```powershell
pip install -r requirements.txt
```

**What gets installed:**
- `tensorflow>=2.15.0` - Deep learning framework
- `keras>=3.0.0` - Neural networks API
- `numpy>=1.24.0` - Numerical computing
- `matplotlib>=3.8.0` - Graph plotting
- `seaborn>=0.13.0` - Statistical visualization
- `scikit-learn>=1.3.0` - ML metrics (confusion matrix)
- `jupyter>=1.0.0` - Interactive notebooks
- And more (see requirements.txt)

### Step 2 (Optional): VS Code Extensions
For the best experience, install these VS Code extensions:
- **Jupyter** (`ms-toolsai.jupyter`) - Run .ipynb notebooks
- **Python** (`ms-python.python`) - Python language support

## 📊 Training Outputs

After running the training, you'll get:

### 1. **Accuracy Graph** 📈
- Shows training vs validation accuracy over epochs
- Helps identify if model is learning properly
- Saved as `training_output/graphs/training_history_*.png`

### 2. **Loss Graph** 📉
- Training vs validation loss curves
- Lower is better - indicates model error
- Helps detect overfitting

### 3. **Confusion Matrix** 🎯
- Shows which diseases get confused with each other
- Diagonal = correct predictions
- Off-diagonal = misclassifications
- Saved as `training_output/graphs/confusion_matrix_*.png`

### 4. **Classification Report** 📊
- Precision, Recall, F1-score for each disease
- Overall accuracy percentage
- Per-class performance breakdown

### 5. **Model Files** 💾
- `.keras` file - Full model (for future retraining)
- `.tflite` file - Mobile-optimized (for Flutter app)
- `labels.txt` - Disease class names

## 🤖 Model Information

## 🤖 Model Information

- **Architecture:** MobileNetV3Large (pre-trained on ImageNet)
- **Input Size:** 224x224x3 RGB images
- **Output Classes:** 6 (1 Healthy + 5 diseases)
- **Training Strategy:** Transfer learning + custom classification head
- **Current Model:** `../assets/models/spotbleaf_model_50epochs.tflite`

## 📊 Dataset Statistics

- **Total Images:** 2,654
- **Classes:** 6
- **Distribution:**
  - ✅ Healthy: 632 images (23.8%)
  - ⚠️ Sigatoka: 661 images (24.9%)
  - ❌ Panama Disease: 634 images (23.9%)
  - ⚠️ Cordana: 504 images (19.0%)
  - ⚠️ Pestalotiopsis: 173 images (6.5%) - NEEDS MORE DATA
  - ❌ Bract Mosaic Virus: 50 images (1.9%) - SEVERELY UNDER-REPRESENTED

## 🔄 Model Retraining Workflow

1. **Add New Images** to appropriate `dataset/` folders
2. **Run Training:**
   ```powershell
   python train_model.py
   # OR open train_mobilenetv3.ipynb in Jupyter
   ```
3. **Review Results** in `training_output/graphs/`
4. **Copy Best Model to App:**
   ```powershell
   # Find the timestamp from training output
   $timestamp = "20251203_143000"  # Example - use your actual timestamp
   
   # Copy TFLite model
   Copy-Item "backend\training_output\models\spotbleaf_model_$timestamp.tflite" `
             "assets\models\spotbleaf_model_50epochs.tflite" -Force
   
   # Copy labels
   Copy-Item "backend\training_output\models\labels_$timestamp.txt" `
             "assets\models\spotbleaf_model_labels.txt" -Force
   ```
5. **Rebuild Flutter App:**
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

## 💡 Training Tips & Recommendations

### Data Augmentation
The training script automatically applies:
- ✅ Rotation (±15°)
- ✅ Horizontal flips
- ✅ Width/Height shifts (±10%)
- ✅ Zoom (±10%)
- ✅ Shear transformations

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
EPOCHS = 50               # Training iterations
LEARNING_RATE = 0.001     # Step size for optimization
IMAGE_SIZE = 224x224      # Input resolution
OPTIMIZER = Adam          # Optimization algorithm
```

### Training Callbacks
- **Model Checkpoint:** Saves best model (highest validation accuracy)
- **Early Stopping:** Stops if no improvement for 10 epochs
- **Learning Rate Reduction:** Reduces LR by 50% if loss plateaus

## 🎯 Target Performance Metrics

- **Overall Accuracy:** >90%
- **Per-Class Accuracy:** >85% for all diseases
- **Confidence Threshold:** >70% for app predictions
- **Top-2 Accuracy:** >95% (correct answer in top 2 guesses)

## 🐛 Troubleshooting

### "No module named tensorflow"
```powershell
pip install tensorflow
```

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
```

### Low Accuracy on Specific Disease
- ✅ Collect more images for that class
- ✅ Check for blurry/mislabeled images
- ✅ Review confusion matrix to see patterns

## 📝 What the Graphs Mean

### Accuracy Graph
- **High train, low val:** Overfitting (model memorizing)
- **Both low:** Underfitting (model not learning)
- **Both high:** Good fit! ✅

### Loss Graph
- Should steadily decrease
- Val loss < train loss = very good
- Val loss >> train loss = overfitting

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
