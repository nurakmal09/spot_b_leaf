# Banana Leaf Disease Dataset

## Overview
This dataset contains images of banana leaves for disease classification using the MobileNetV3 model.

## Dataset Statistics

| Disease Class | Number of Images | Percentage |
|---------------|-----------------|------------|
| **Healthy** | 632 | 23.8% |
| **Sigatoka** | 661 | 24.9% |
| **Panama Disease** | 634 | 23.9% |
| **Cordana** | 504 | 19.0% |
| **Pestalotiopsis** | 173 | 6.5% |
| **Bract Mosaic Virus** | 50 | 1.9% |
| **TOTAL** | **2,654** | **100%** |

## Directory Structure

```
backend/dataset/
├── Bract Mosaic Virus/     # 50 images - High Risk
├── Cordana/                # 504 images - Medium Risk
├── Healthy/                # 632 images - Healthy
├── Panama Disease/         # 634 images - High Risk
├── Pestalotiopsis/         # 173 images - Low Risk
└── sigatoka/               # 661 images - Medium Risk
```

## Disease Descriptions

### 1. Healthy (632 images)
- **Status**: Healthy leaves with no disease symptoms
- **Risk Level**: None
- **Color Code**: Green 🟢

### 2. Sigatoka (661 images)
- **Full Name**: Black Sigatoka (Mycosphaerella fijiensis)
- **Symptoms**: Dark brown/black streaks and spots on leaves
- **Risk Level**: Medium 🟠
- **Impact**: Reduces photosynthesis, premature leaf death

### 3. Panama Disease (634 images)
- **Full Name**: Fusarium Wilt (Fusarium oxysporum)
- **Symptoms**: Yellowing and wilting of leaves
- **Risk Level**: High 🔴
- **Impact**: Fatal to plants, spreads through soil

### 4. Cordana (504 images)
- **Full Name**: Cordana Leaf Spot (Cordana musae)
- **Symptoms**: Small dark spots with yellow halos
- **Risk Level**: Medium 🟠
- **Impact**: Reduces leaf area and fruit quality

### 5. Pestalotiopsis (173 images)
- **Full Name**: Pestalotiopsis Leaf Spot
- **Symptoms**: Brown lesions with concentric rings
- **Risk Level**: Low 🟡
- **Impact**: Minor cosmetic damage

### 6. Bract Mosaic Virus (50 images)
- **Full Name**: Banana Bract Mosaic Virus (BBrMV)
- **Symptoms**: Mosaic patterns on bracts and leaves
- **Risk Level**: High 🔴
- **Impact**: Reduces fruit quality and yield

## Model Training Notes

### Class Imbalance
- **Well-represented**: Healthy, Sigatoka, Panama Disease, Cordana (500-660 images each)
- **Under-represented**: 
  - Pestalotiopsis (173 images) - Consider data augmentation
  - Bract Mosaic Virus (50 images) - May need more samples for better accuracy

### Recommendations
1. **Data Augmentation** for Bract Mosaic Virus (only 50 samples)
2. **Weighted Loss Function** to handle class imbalance
3. **Stratified Split** for train/validation/test sets
4. **Monitor per-class accuracy** especially for minority classes

## Data Augmentation Strategies

For under-represented classes (Pestalotiopsis, Bract Mosaic Virus):
- Random rotation (±15°)
- Horizontal flip
- Random brightness/contrast adjustment
- Random zoom (0.9-1.1x)
- Gaussian noise

## Usage

### For Model Training
```python
# Recommended split ratios
Train: 70% (1,858 images)
Validation: 15% (398 images)
Test: 15% (398 images)
```

### For App Integration
The trained model (`spotbleaf_model_50epochs.tflite`) is already integrated in:
- `assets/models/spotbleaf_model_50epochs.tflite`
- `assets/models/spotbleaf_model_labels.txt`

## Dataset Version
- **Version**: 2.0
- **Date**: December 2025
- **Total Images**: 2,654
- **Image Format**: JPG/PNG
- **Resolution**: Variable (preprocessed to 224x224 for model)

## License & Attribution
This dataset is for educational and research purposes for the Spot B-Leaf banana disease detection project.

---
**Note**: This dataset supports the MobileNetV3 model deployed in the mobile application for real-time banana leaf disease detection.
