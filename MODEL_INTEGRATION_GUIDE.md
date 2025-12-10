# MobileNetV3 Disease Detection Integration Guide

## Setup Complete! 🎉

Your MobileNetV3 model has been integrated into the app. Here's what you need to do:

## Step 1: Copy Your Model Files

Copy your two model files to the assets folder:

```
c:\src\repo\wowooo\assets\models\
├── spotbleaf_model_50epochs.tflite
└── spotbleaf_model_labels.txt
```

**Important:** Make sure the files are named exactly as shown above, or update the file names in `lib\services\disease_detection_service.dart` (lines 8-9).

## Step 2: Format Your Labels File

The `spotbleaf_model_labels.txt` file should contain one label per line:

```
Healthy
Black Sigatoka
Panama Disease
```

Example format - one disease name per line, no extra spaces or commas.

## Step 3: Install Dependencies

Run the following commands in your terminal:

```powershell
cd c:\src\repo\wowooo
flutter clean
flutter pub get
```

## Step 4: Configure Model Input Size

Check your model's input size (likely 224x224 or 299x299) and update if needed in:
- File: `lib\services\disease_detection_service.dart`
- Line: 17 - `static const int inputSize = 224;`

You can check your model's input size by looking at your training configuration.

## Step 5: Run the App

```powershell
flutter run
```

## How It Works

### Disease Detection Features:
1. **Camera Capture**: Take a photo of a banana leaf directly
2. **Gallery Upload**: Select an existing photo from your gallery
3. **Real-time Analysis**: AI model processes the image and returns:
   - Disease name
   - Confidence score (%)
   - Severity level (Healthy/Low Risk/Medium Risk/High Risk)
   - Treatment recommendations

### Using the Scanner:
1. Open the app and tap the camera button in the bottom navbar
2. Toggle to "Disease" mode
3. Position the leaf within the frame
4. Tap "Capture" or use "Upload from Gallery"
5. Wait for AI analysis (2-5 seconds)
6. View results with confidence score
7. Tap "Treatment" to see recommended actions

## Files Modified/Created:

### New Files:
- ✅ `lib/services/disease_detection_service.dart` - AI model service
- ✅ `assets/models/` - Model files folder
- ✅ Updated `pubspec.yaml` - Added TFLite dependencies

### Modified Files:
- ✅ `lib/pages/scanner_page.dart` - Integrated disease detection
- ✅ `pubspec.yaml` - Added dependencies and assets

## Troubleshooting

### Model Not Loading?
- Verify file paths in `pubspec.yaml` match your actual files
- Run `flutter clean` then `flutter pub get`
- Check that `.tflite` and `.txt` files are in `assets/models/`

### Wrong Predictions?
- Verify `inputSize` matches your model (line 17 in service)
- Check labels file format (one label per line, no extra characters)
- Ensure image preprocessing matches your training (normalization to [0,1])

### Low Confidence Scores?
- Take photos in good lighting
- Ensure leaf fills most of the frame
- Avoid blurry images
- Consider retraining with more diverse data

## Model Configuration

If your model has different specifications:

### Input Size
Default: 224x224
Update in `disease_detection_service.dart` line 17

### Number of Classes
Default: 3 classes
Update in `disease_detection_service.dart` line 19

### Normalization
Default: Divides by 255.0 (range [0,1])
Modify `_preprocessImage()` method if your model expects different normalization

## Next Steps (Optional Improvements)

1. **Save Detection Results**: Store disease detections in Firestore
2. **Detection History**: Show past scans and trends
3. **Offline Mode**: Model works offline by default!
4. **Batch Processing**: Detect multiple leaves at once
5. **Heatmap Visualization**: Show which parts of leaf are diseased

## Need Help?

If you encounter issues:
1. Check model file paths are correct
2. Verify labels file format
3. Review console logs for errors
4. Test with a sample image first

---

**Ready to test!** Copy your model files and run `flutter pub get` 🚀
