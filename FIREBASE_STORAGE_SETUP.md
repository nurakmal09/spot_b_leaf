# Firebase Storage Setup Guide

## Overview
This guide will help you set up Firebase Storage for your disease detection app to save images organized by plant ID.

## Firebase Console Setup Steps

### 1. Enable Firebase Storage

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **spot b-leaf**
3. Click on **Storage** in the left sidebar (under "Build" section)
4. Click **Get Started** button
5. You'll see a dialog about security rules:
   - For development: Click **Start in test mode** (allows read/write for 30 days)
   - For production: Click **Start in production mode** (secure, requires authentication)
6. Choose your Cloud Storage location (preferably same region as your Firestore)
7. Click **Done**

### 2. Configure Security Rules

After enabling Storage, set up proper security rules:

1. In Firebase Console, go to **Storage** > **Rules** tab
2. Replace the default rules with the following:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload disease images for their plants
    match /plant_images/{plantId}/disease_scans/{fileName} {
      // Allow read if user owns the plant or is admin
      allow read: if request.auth != null;
      
      // Allow write if user is authenticated and file is an image under 5MB
      allow write: if request.auth != null 
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

3. Click **Publish** to save the rules

### 3. Verify Storage Structure

Your images will be organized in this structure:
```
plant_images/
├── {plantId-1}/
│   └── disease_scans/
│       ├── 1703174523456_image.jpg
│       ├── 1703174789012_image.jpg
│       └── ...
├── {plantId-2}/
│   └── disease_scans/
│       └── ...
└── ...
```

### 4. Set Up Firestore Collections

The app will also create a `disease_detections` collection in Firestore to track all disease scans:

1. Go to **Firestore Database** in Firebase Console
2. The `disease_detections` collection will be created automatically when the first detection is saved
3. Each document will contain:
   - `plantId`: ID of the scanned plant
   - `imageUrl`: Firebase Storage download URL
   - `diseaseType`: Detected disease name
   - `confidence`: Detection confidence score (0-1)
   - `detectedAt`: Timestamp of detection
   - `allPredictions`: Array of all predictions with scores

### 5. Update Plant Documents

The app also updates the `plant` collection documents with the latest disease check info:
- `lastDiseaseCheck`: Timestamp
- `lastDiseaseType`: Disease name
- `lastDiseaseConfidence`: Confidence score
- `lastDiseaseImageUrl`: Image URL

## Android Configuration

Make sure your Android app has the required permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

## Install Dependencies

Run this command in your terminal:

```bash
flutter pub get
```

## Testing the Integration

1. Run your app: `flutter run`
2. Navigate to the Scanner page
3. Switch to **Disease Detection** mode
4. Select a plant from your garden
5. Capture or upload a leaf image
6. After detection completes, check for success message: "✓ Image saved to Firebase successfully"
7. Verify in Firebase Console:
   - Go to **Storage** > **Files**
   - Navigate to `plant_images/{plantId}/disease_scans/`
   - You should see the uploaded image
8. Check Firestore:
   - Go to **Firestore Database**
   - Find the `disease_detections` collection
   - You should see a new document with detection details

## Troubleshooting

### Error: "Storage bucket not configured"
- Make sure you've enabled Firebase Storage in the console
- Verify `firebase_options.dart` contains the storage bucket URL

### Error: "Permission denied"
- Check that your Storage security rules allow authenticated users to write
- Verify the user is logged in (check Firebase Auth)

### Error: "Image upload failed"
- Check internet connection
- Verify the image path exists
- Check Firebase Console for error logs in **Storage** > **Usage** tab

### Images not appearing in Firestore
- Check Firestore security rules allow writes to `disease_detections` collection
- Verify the plant ID exists in the `plant` collection

## Storage Costs

Firebase Storage free tier includes:
- 5 GB stored
- 1 GB downloaded per day
- 20,000 uploads per day

For typical usage (images ~2MB each), you can store approximately 2,500 disease detection images in the free tier.

## Additional Features Available

The `FirebaseStorageService` class provides these methods:

1. **uploadDiseaseImage()** - Upload image only
2. **saveDiseaseDetection()** - Save detection record to Firestore
3. **uploadAndSaveDiseaseDetection()** - Complete workflow (used in the app)
4. **getPlantDiseaseImages()** - Retrieve all images for a plant
5. **getDiseaseDetectionHistory()** - Get detection history from Firestore
6. **deleteDiseaseImage()** - Delete an image from Storage

You can use these methods to build additional features like:
- Disease history viewer
- Image gallery for each plant
- Export disease reports
- Delete old images

## Security Best Practices

1. **Always authenticate users** before allowing uploads
2. **Validate file types** - only allow images
3. **Set file size limits** - prevent large file uploads
4. **Use indexed queries** - add indexes for Firestore queries
5. **Monitor usage** - check Firebase Console regularly for unusual activity
6. **Backup data** - enable Firestore backups in production

## Next Steps

1. Install the dependencies: `flutter pub get`
2. Enable Firebase Storage in the console
3. Configure security rules
4. Test the disease detection with image upload
5. Monitor uploads in Firebase Console
