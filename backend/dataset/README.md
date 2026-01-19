# Banana Leaf Disease Dataset v2.0

## Overview
This dataset contains images of banana leaves for disease classification using machine learning. The dataset includes 6 different classes representing various diseases and healthy leaves.

## Dataset Statistics
- **Total Images**: 669
- **Number of Classes**: 6
- **Image Format**: JPG/JPEG/PNG
- **Created Date**: 2025-12-11

## Class Distribution

| Class Name | Number of Images | Percentage |
|------------|-----------------|------------|
| Black Sigatoka Disease | 90 | 13.45% |
| Bract Mosaic Virus Disease | 50 | 7.47% |
| Cordana Disease | 206 | 30.79% |
| Healthy Leaf | 109 | 16.29% |
| Panama Disease | 41 | 6.13% |
| Pestalotiopsis Disease | 173 | 25.86% |

## Directory Structure
```
dataset/
├── README.md
├── dataset_info.json
├── Black Sigatoka Disease/
│   └── [90 images]
├── Bract Mosaic Virus Disease/
│   └── [50 images]
├── Cordana Disease/
│   └── [206 images]
├── Healthy Leaf/
│   └── [109 images]
├── Panama Disease/
│   └── [41 images]
└── Pestalotiopsis Disease/
    └── [173 images]
```

## Disease Descriptions

### 1. Black Sigatoka Disease
Black Sigatoka (Mycosphaerella fijiensis) is one of the most destructive diseases of banana plants. It causes dark streaks and spots on leaves, eventually leading to leaf death.

### 2. Bract Mosaic Virus Disease
Banana Bract Mosaic Virus (BBrMV) causes mosaic patterns on leaves and bracts. It can significantly reduce fruit quality and yield.

### 3. Cordana Disease
Cordana leaf spot is caused by the fungus Cordana musae. It appears as small, circular, dark brown spots on banana leaves.

### 4. Healthy Leaf
Normal, disease-free banana leaves showing no symptoms of infection or damage.

### 5. Panama Disease
Panama disease (Fusarium wilt) is a soil-borne fungal disease that affects the vascular system of banana plants, causing wilting and eventual plant death.

### 6. Pestalotiopsis Disease
Pestalotiopsis leaf spot causes irregular lesions on banana leaves, often with a characteristic yellow halo around the spots.

## Data Augmentation
The training pipeline automatically applies data augmentation to balance the dataset and increase the number of training samples to 300 images per class. Augmentation techniques include:
- Rotation (±30°)
- Width/Height shifts (±20%)
- Zoom (±20%)
- Horizontal flips
- Brightness adjustment (70-130%)

## Model Performance
**Latest Model**: EfficientNet-B0 (efficientnet_b0_94.07.tflite)
- **Overall Accuracy**: 94.07%
- **Training Date**: 2025-12-11

### Per-Class Accuracy:
- Black Sigatoka Disease: 97.78%
- Bract Mosaic Virus Disease: 96.67%
- Cordana Disease: 97.78%
- Healthy Leaf: 98.89%
- Panama Disease: 85.56%
- Pestalotiopsis Disease: 87.78%

## Usage Notes
1. Images should be clear and properly focused on the leaf
2. Ensure good lighting conditions for best results
3. The model works best with images similar to the training data distribution
4. Classes with fewer samples (Panama Disease, Bract Mosaic Virus Disease) may have slightly lower accuracy

## Citation
If you use this dataset, please cite:
```
Banana Leaf Disease Dataset v2.0
Created: December 11, 2025
Total Images: 669
Classes: 6 (Black Sigatoka, Bract Mosaic Virus, Cordana, Healthy, Panama, Pestalotiopsis)
```

## License
This dataset is intended for educational and research purposes.

## Updates
- **2025-12-11**: Initial dataset creation with 669 images across 6 disease classes
- **2025-12-11**: Custom CNN model trained achieving 94.07% accuracy
