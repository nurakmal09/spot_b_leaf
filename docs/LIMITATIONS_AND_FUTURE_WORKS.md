# Limitations and Future Works - Spot B-Leaf

> **Project:** Banana Leaf Disease Detection Mobile Application  
> **Last Updated:** January 25, 2026

---

## 🎯 Top 3 Main Limitations and Future Works

These are the **most critical** limitations that directly impact the project's effectiveness and should be prioritized for future development:

### 1. Limited Training Dataset and Class Imbalance

| Aspect | Details |
|--------|---------|
| **Limitation** | The model was trained on only **669 original images** with significant class imbalance. Panama Disease has only **41 images (6.13%)**, resulting in lower detection accuracy (85.56%) compared to other diseases. This limits the model's ability to generalize across diverse real-world conditions. |
| **Impact** | Reduced reliability for farmers dealing with Panama Disease, which is ironically one of the most destructive banana diseases worldwide. |
| **Future Work** | Expand the dataset to **2,000+ original images** through partnerships with agricultural research institutions and field data collection programs. Prioritize collecting **250+ Panama Disease images** and **200+ Bract Mosaic Virus images** to address the class imbalance. Implement active learning to continuously improve the model from verified field data. |

---

### 2. Single Disease Detection Per Scan (No Multi-Disease Detection)

| Aspect | Details |
|--------|---------|
| **Limitation** | The current system can only **identify one disease per scan**. In real-world scenarios, banana leaves may exhibit symptoms of multiple diseases simultaneously, or the user may want to scan an entire plant with multiple affected leaves. |
| **Impact** | Farmers may need to perform multiple scans to get a complete health assessment, reducing efficiency and potentially missing co-occurring infections. |
| **Future Work** | Develop an **object detection model** (using YOLO or SSD architecture) that can identify and localize multiple diseases within a single image. Implement **Grad-CAM or attention heatmaps** to visually highlight affected regions on the leaf, providing farmers with precise information about disease location and spread. |

---

### 3. No Treatment Progress Tracking and Predictive Analytics

| Aspect | Details |
|--------|---------|
| **Limitation** | The application only provides **diagnosis without follow-up tracking**. There is no mechanism to monitor whether treatments are effective, track disease progression over time, or predict potential outbreaks based on historical patterns. |
| **Impact** | Farmers cannot assess treatment effectiveness, leading to potential overuse of fungicides or delayed intervention. No early warning system exists to prevent disease spread across plantations. |
| **Future Work** | Implement a **treatment logging feature** with before/after comparison photos and recovery monitoring. Develop **predictive analytics** using historical scan data combined with weather API integration to create an **early warning system** that alerts farmers to potential disease outbreaks based on environmental conditions and regional disease trends. |

---

## 📋 Complete List of Limitations and Future Works

### Machine Learning Model Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **Limited disease classes** - Only 6 classes (5 diseases + healthy) | Expand to include more banana diseases like Bunchy Top Virus, Moko Disease, Anthracnose, and Banana Streak Virus |
| 2 | **Low accuracy for Panama Disease (85.56%)** - Due to only 41 training samples | Collect 250+ more diverse Panama Disease images and retrain the model |
| 3 | **Small training dataset (669 images)** - Limits model generalization | Expand the dataset to 2,000+ original images through field data collection partnerships |
| 4 | **Overfitting indicated** (97.94% train vs 89.07% validation) | Implement fine-tuning of base model layers and apply stronger regularization techniques |
| 5 | **No severity-level classification** - Cannot distinguish early vs. advanced disease stages | Train multi-label model that predicts disease type AND severity stage |
| 6 | **Single crop support** - Only works for banana leaves | Extend to other crops (cassava, tomato, rice) for broader agricultural application |

---

### Image Processing & Detection Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **Quality dependent** - Performance varies with lighting and image quality | Implement real-time image quality assessment and guided capture with exposure/focus hints |
| 2 | **No multi-disease detection** - Only detects one disease per scan | Develop object detection model (YOLO/SSD) to identify multiple diseases in single leaf |
| 3 | **Fixed input size (224×224)** - May lose detail in high-res images | Implement sliding window or multi-scale inference for better detection on high-resolution images |
| 4 | **No localization** - Doesn't show WHERE the disease is on the leaf | Add Grad-CAM or attention heatmaps to highlight affected leaf regions |

---

### Offline Mode Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **No conflict resolution** - If same scan edited on multiple devices | Implement conflict detection and merge strategies for edited scans |
| 2 | **No selective sync** - All pending scans sync at once | Add option to choose which scans to sync (prioritize important ones) |
| 3 | **No data export** - Cannot export local data | Enable CSV/JSON export of scan history for external analysis |
| 4 | **No P2P sync** - Requires internet for device-to-device sync | Implement Bluetooth/WiFi Direct peer-to-peer sync between nearby devices |
| 5 | **Base64 image storage** - Inefficient and increases database size | Implement image compression before caching and use binary blob storage |

---

### User Experience Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **Manual QR linking** - Must manually link plants to scans | Implement automatic plant recognition from previous scans (plant fingerprinting) |
| 2 | **No treatment tracking** - Only diagnoses, doesn't track treatment progress | Add treatment logging feature with before/after comparison and recovery monitoring |
| 3 | **Limited reporting** - Basic weekly reports only | Develop advanced analytics with disease trend forecasting, seasonal patterns, and alerts |
| 4 | **No multi-language support** | Implement localization for Malay, Tamil, Mandarin for Malaysian farmers |
| 5 | **No accessibility features** | Add voice feedback, high contrast mode, and screen reader support |

---

### Platform & Technical Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **Web platform has limited camera support** | Optimize web version with WebRTC/MediaStream API for better camera handling |
| 2 | **No iOS optimization** - Primary focus on Android | Perform iOS-specific testing and performance optimization for iPhone deployment |
| 3 | **No background processing** - Sync only when app is active | Implement WorkManager (Android) / Background Fetch (iOS) for background sync |
| 4 | **Single user per device** - No multi-user support | Add user profile switching for shared device usage (farm cooperatives) |
| 5 | **No API rate limiting** - Could face Firebase quotas | Implement request batching and caching to optimize Firebase usage |

---

### Data & Analytics Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **No weather correlation** - Disease outbreaks not linked to weather | Integrate weather API data to correlate disease occurrence with weather patterns |
| 2 | **No geographic mapping** - GPS data not visualized | Develop interactive disease distribution maps with GIS integration |
| 3 | **Limited insight sharing** - Data stays per-user | Create community/cooperative-level dashboards for regional disease monitoring |
| 4 | **No predictive analytics** - Reactive detection only | Develop AI-based early warning system that predicts disease outbreaks based on historical data |

---

### Model Deployment & Maintenance Limitations

| # | Limitation | Future Work |
|---|------------|-------------|
| 1 | **No in-app model updates** - Requires app update for new model | Implement over-the-air (OTA) model updates via Firebase Remote Config |
| 2 | **No continuous learning** - Model doesn't improve from user data | Develop federated learning pipeline to improve model from field data (with user consent) |
| 3 | **No model versioning in-app** - Cannot rollback to previous model | Add model version management with A/B testing capabilities |

---

## 📊 Summary Statistics

| Category | Total Limitations | Priority Level |
|----------|-------------------|----------------|
| Machine Learning Model | 6 | 🔴 High |
| Image Processing | 4 | 🔴 High |
| Offline Mode | 5 | 🟡 Medium |
| User Experience | 5 | 🟡 Medium |
| Platform & Technical | 5 | 🟢 Low |
| Data & Analytics | 4 | 🟡 Medium |
| Model Deployment | 3 | 🟢 Low |
| **Total** | **32** | - |

---

## 🎓 For Thesis Documentation

When writing your thesis, focus on the **Top 3 Main Limitations** as they represent:

1. **Data Quality Issues** - A fundamental challenge in machine learning applications
2. **Detection Capability** - Core functionality improvement
3. **Practical Utility** - Real-world agricultural impact

These limitations and corresponding future works demonstrate:
- Critical thinking about system capabilities
- Understanding of real-world deployment challenges  
- Clear roadmap for system improvement
- Awareness of agricultural technology requirements

---

**Document Version:** 1.0  
**Created:** January 25, 2026  
**Author:** Generated for Spot B-Leaf Project
