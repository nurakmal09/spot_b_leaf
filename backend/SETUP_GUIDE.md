# 🚀 Setup Instructions for Model Training

## What You Need to Install

### 1️⃣ Python Packages (REQUIRED)

Open PowerShell in the `backend` folder and run:

```powershell
pip install -r requirements.txt
```

This installs:
- ✅ TensorFlow 2.15+ (Deep learning framework)
- ✅ Keras 3.0+ (Neural network API)
- ✅ NumPy (Numerical computing)
- ✅ Pandas (Data analysis)
- ✅ Matplotlib (Graph plotting)
- ✅ Seaborn (Statistical visualization)
- ✅ Scikit-learn (ML metrics)
- ✅ Pillow (Image processing)
- ✅ Jupyter (Interactive notebooks)
- ✅ OpenCV (Computer vision)

**Installation time:** ~5-10 minutes (depending on internet speed)

---

### 2️⃣ VS Code Extensions (OPTIONAL but Recommended)

#### For Jupyter Notebook Support:
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search and install:
   - **Jupyter** (Publisher: Microsoft)
   - **Python** (Publisher: Microsoft)

These extensions let you run the `train_mobilenetv3.ipynb` notebook directly in VS Code!

---

## How to Train the Model

### Method 1: Jupyter Notebook (Interactive, Best for Beginners)

```powershell
# Navigate to backend folder
cd backend

# Launch Jupyter
jupyter notebook train_mobilenetv3.ipynb
```

This opens a web browser with the notebook. Run each cell step-by-step to see:
- 📊 Dataset visualization
- 📈 Training progress
- 🎯 Accuracy/Loss graphs
- 🔥 Confusion matrix

### Method 2: Python Script (Automated, Best for Batch Training)

```powershell
# Navigate to backend folder
cd backend

# Run training script
python train_model.py
```

This runs the entire training pipeline automatically and saves all outputs to `training_output/`.

---

## What Gets Generated

After training completes, you'll find:

```
backend/training_output/
├── models/
│   ├── best_model_20251203_143000.keras      # Full Keras model
│   ├── spotbleaf_model_20251203_143000.tflite # Mobile model (for Flutter)
│   └── labels_20251203_143000.txt            # Class names
├── graphs/
│   ├── training_history_20251203_143000.png   # Accuracy/Loss graphs
│   ├── confusion_matrix_20251203_143000.png   # Confusion matrix
│   ├── per_class_accuracy_20251203_143000.png # Per-class metrics
│   ├── dataset_distribution.png               # Class distribution
│   └── sample_images.png                      # Sample training images
└── logs/
    ├── training_log_20251203_143000.csv       # Epoch-by-epoch metrics
    └── training_summary_20251203_143000.json  # Final summary
```

---

## Expected Training Time

| Hardware | Time |
|----------|------|
| CPU only | ~3-4 hours |
| GPU (NVIDIA) | ~30-45 minutes |

💡 **Tip:** If you have an NVIDIA GPU, TensorFlow will automatically use it for faster training!

---

## Understanding the Graphs

### 📈 Accuracy Graph
- **Y-axis:** Percentage of correct predictions
- **X-axis:** Training epochs (iterations)
- **Blue line:** Training accuracy
- **Orange line:** Validation accuracy
- **What to look for:** Both lines should increase and stabilize

### 📉 Loss Graph
- **Y-axis:** Error value (lower is better)
- **X-axis:** Training epochs
- **What to look for:** Both lines should decrease smoothly

### 🎯 Confusion Matrix
- **Rows:** True labels (actual disease)
- **Columns:** Predicted labels
- **Diagonal (bright):** Correct predictions ✅
- **Off-diagonal (dark):** Misclassifications ❌

---

## Common Issues & Fixes

### ❌ "ModuleNotFoundError: No module named 'tensorflow'"
**Fix:**
```powershell
pip install tensorflow
```

### ❌ "Out of memory" during training
**Fix:** Edit the config in `train_model.py` or notebook:
```python
BATCH_SIZE = 16  # Reduce from 32 to 16
```

### ❌ Jupyter notebook won't open
**Fix:**
```powershell
pip install --upgrade jupyter notebook
jupyter notebook
```

### ❌ Training stuck at 0% accuracy
**Fix:** 
- Check if dataset folder paths are correct
- Verify images can be loaded (not corrupted)
- Ensure class folders have images inside

---

## After Training: Deploy to Flutter App

1. **Find your trained model:**
   ```
   backend/training_output/models/spotbleaf_model_[timestamp].tflite
   ```

2. **Copy to assets:**
   ```powershell
   Copy-Item "backend\training_output\models\spotbleaf_model_*.tflite" `
             "assets\models\spotbleaf_model_50epochs.tflite" -Force
   
   Copy-Item "backend\training_output\models\labels_*.txt" `
             "assets\models\spotbleaf_model_labels.txt" -Force
   ```

3. **Rebuild Flutter app:**
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk
   ```

4. **Test in app:**
   - Open app → Scanner page
   - Switch to "Disease" mode
   - Capture or upload banana leaf image
   - See AI prediction! 🎉

---

## Need Help?

- 📚 **TensorFlow Docs:** https://www.tensorflow.org/tutorials
- 📓 **Jupyter Guide:** https://jupyter.org/try
- 🐍 **Python Installation:** https://www.python.org/downloads/
- 💬 **VS Code Jupyter:** https://code.visualstudio.com/docs/datascience/jupyter-notebooks

---

**Ready to train?** Run:
```powershell
cd backend
pip install -r requirements.txt
python train_model.py
```

Good luck! 🍌🔬✨
