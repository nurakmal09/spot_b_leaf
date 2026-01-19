"""
EfficientNet-B0 Training Pipeline for Banana Leaf Disease Classification

This script trains an EfficientNet-B0 model on the banana leaf disease dataset
and generates comprehensive analysis including:
- Training/Validation Accuracy & Loss graphs
- Confusion Matrix
- Classification Report
- Per-class accuracy metrics
"""

import os
import json
import time
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
from pathlib import Path

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, models
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau, CSVLogger

from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
from PIL import Image
import shutil

# Set random seeds for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

# Configuration
class Config:
    # Paths
    BASE_DIR = Path(__file__).parent
    DATASET_DIR = BASE_DIR / 'dataset'
    OUTPUT_DIR = BASE_DIR / 'training_output'
    MODELS_DIR = OUTPUT_DIR / 'models'
    GRAPHS_DIR = OUTPUT_DIR / 'graphs'
    LOGS_DIR = OUTPUT_DIR / 'logs'
    
    # Model parameters
    IMG_HEIGHT = 224
    IMG_WIDTH = 224
    CHANNELS = 3
    INPUT_SHAPE = (IMG_HEIGHT, IMG_WIDTH, CHANNELS)
    
    # Training parameters
    BATCH_SIZE = 16  # Reduced from 32 to prevent memory errors
    EPOCHS = 100
    LEARNING_RATE = 0.0005  # Balanced learning rate
    
    # Augmentation parameters
    MIN_SAMPLES_PER_CLASS = 300  # Target minimum samples per class
    AUGMENT_THRESHOLD = 300  # Augment classes with fewer than this many images
    
    # Data split
    TRAIN_SPLIT = 0.70
    VAL_SPLIT = 0.15
    TEST_SPLIT = 0.15
    
    # Class names (must match folder names)
    CLASS_NAMES = [
        'Black Sigatoka Disease',
        'Bract Mosaic Virus Disease',
        'Cordana Disease',
        'Healthy Leaf',
        'Panama Disease',
        'Pestalotiopsis Disease'
    ]
    
    def __init__(self):
        # Create output directories
        for dir_path in [self.OUTPUT_DIR, self.MODELS_DIR, self.GRAPHS_DIR, self.LOGS_DIR]:
            dir_path.mkdir(parents=True, exist_ok=True)

config = Config()


def load_dataset_info():
    """Load dataset information from JSON"""
    info_path = config.DATASET_DIR / 'dataset_info.json'
    with open(info_path, 'r') as f:
        return json.load(f)


def augment_minority_classes():
    """Generate augmented images for minority classes"""
    print("\n🔄 Augmenting minority classes...")
    
    # Create augmented dataset directory
    augmented_dir = config.BASE_DIR / 'dataset_augmented'
    
    # Check if already augmented
    if augmented_dir.exists():
        print(f"⚠️  Augmented dataset already exists at {augmented_dir}")
        print("🔄 Removing old augmented dataset to recreate with updated parameters...")
        shutil.rmtree(augmented_dir)
    
    augmented_dir.mkdir(parents=True, exist_ok=True)
    
    # Heavy augmentation for generating new samples
    augmentation_gen = ImageDataGenerator(
        rotation_range=30,
        width_shift_range=0.2,
        height_shift_range=0.2,
        shear_range=0.2,
        zoom_range=0.2,
        horizontal_flip=True,
        vertical_flip=True,
        brightness_range=[0.7, 1.3],
        fill_mode='nearest'
    )
    
    # Process each class
    for class_name in config.CLASS_NAMES:
        class_dir = config.DATASET_DIR / class_name
        augmented_class_dir = augmented_dir / class_name
        augmented_class_dir.mkdir(parents=True, exist_ok=True)
        
        # Count existing images
        original_images = list(class_dir.glob('*.jpg')) + list(class_dir.glob('*.jpeg')) + list(class_dir.glob('*.png'))
        original_count = len(original_images)
        
        print(f"\n  Processing {class_name}: {original_count} images")
        
        # Copy all original images first
        for img_path in original_images:
            shutil.copy2(img_path, augmented_class_dir / img_path.name)
        
        # Determine if augmentation is needed
        if original_count < config.AUGMENT_THRESHOLD:
            target_count = config.MIN_SAMPLES_PER_CLASS
            needed_count = target_count - original_count
            augmentations_per_image = (needed_count // original_count) + 1
            
            print(f"    ➡️  Generating {needed_count} augmented images ({augmentations_per_image} per original)")
            
            generated = 0
            for img_path in original_images:
                if generated >= needed_count:
                    break
                
                # Load image
                img = Image.open(img_path)
                img_array = np.array(img)
                img_array = np.expand_dims(img_array, 0)
                
                # Generate augmented versions
                aug_iter = augmentation_gen.flow(
                    img_array,
                    batch_size=1,
                    save_to_dir=augmented_class_dir,
                    save_prefix=f'aug_{img_path.stem}',
                    save_format='jpg'
                )
                
                for i in range(augmentations_per_image):
                    if generated >= needed_count:
                        break
                    next(aug_iter)
                    generated += 1
            
            final_count = len(list(augmented_class_dir.glob('*.jpg'))) + len(list(augmented_class_dir.glob('*.jpeg'))) + len(list(augmented_class_dir.glob('*.png')))
            print(f"    ✅ Total images after augmentation: {final_count}")
        else:
            print(f"    ✅ No augmentation needed (above threshold)")
    
    print(f"\n✅ Augmented dataset created at {augmented_dir}")
    return augmented_dir


def create_data_generators(dataset_path=None):
    """Create data generators with augmentation for training"""
    print("\n📊 Creating data generators...")
    
    if dataset_path is None:
        dataset_path = config.DATASET_DIR
    
    # Training data generator with moderate augmentation
    train_datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=15,
        width_shift_range=0.1,
        height_shift_range=0.1,
        shear_range=0.1,
        zoom_range=0.1,
        horizontal_flip=True,
        fill_mode='nearest',
        validation_split=config.VAL_SPLIT + config.TEST_SPLIT
    )
    
    # Validation/Test data generator (no augmentation)
    val_test_datagen = ImageDataGenerator(
        rescale=1./255,
        validation_split=config.VAL_SPLIT + config.TEST_SPLIT
    )
    
    # Training generator
    train_generator = train_datagen.flow_from_directory(
        dataset_path,
        target_size=(config.IMG_HEIGHT, config.IMG_WIDTH),
        batch_size=config.BATCH_SIZE,
        class_mode='categorical',
        subset='training',
        shuffle=True,
        seed=42
    )
    
    # Validation generator
    val_generator = val_test_datagen.flow_from_directory(
        dataset_path,
        target_size=(config.IMG_HEIGHT, config.IMG_WIDTH),
        batch_size=config.BATCH_SIZE,
        class_mode='categorical',
        subset='validation',
        shuffle=False,
        seed=42
    )
    
    print(f"✅ Training samples: {train_generator.samples}")
    print(f"✅ Validation samples: {val_generator.samples}")
    print(f"✅ Classes: {train_generator.class_indices}")
    
    return train_generator, val_generator


def compute_class_weights(train_generator):
    """Compute class weights to handle imbalanced dataset"""
    print("\n⚖️  Computing class weights for imbalanced dataset...")
    
    class_weights = compute_class_weight(
        class_weight='balanced',
        classes=np.unique(train_generator.classes),
        y=train_generator.classes
    )
    
    # Use standard balanced weights without additional boosting
    class_weight_dict = {idx: weight for idx, weight in enumerate(class_weights)}
    
    print("Class weights:")
    for class_name, idx in train_generator.class_indices.items():
        print(f"  {class_name}: {class_weight_dict[idx]:.2f}")
    
    return class_weight_dict


def build_efficientnet_b0_model():
    """Build EfficientNet-B0 model with transfer learning"""
    print("\n🏗️  Building EfficientNet-B0 model with transfer learning...")
    
    # Load pre-trained EfficientNetB0 without top layers
    base_model = EfficientNetB0(
        include_top=False,
        weights='imagenet',
        input_shape=config.INPUT_SHAPE,
        pooling='avg'  # Global average pooling
    )
    
    # Freeze base model layers initially
    base_model.trainable = False
    
    # Build the complete model
    model = models.Sequential([
        # Input layer
        layers.Input(shape=config.INPUT_SHAPE),
        
        # EfficientNetB0 base
        base_model,
        
        # Custom classification head
        layers.BatchNormalization(),
        layers.Dropout(0.5),
        layers.Dense(256, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.4),
        layers.Dense(128, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        
        # Output layer
        layers.Dense(len(config.CLASS_NAMES), activation='softmax')
    ])
    
    print(f"✅ EfficientNet-B0 built with {len(config.CLASS_NAMES)} output classes")
    print(f"📊 Base model: {base_model.name}")
    print(f"🔒 Base model frozen: {not base_model.trainable}")
    print(f"📈 Trainable parameters: {model.count_params():,}")
    
    return model


def compile_model(model, learning_rate=None):
    """Compile the model with optimizer and loss function"""
    if learning_rate is None:
        learning_rate = config.LEARNING_RATE
    
    print(f"\n⚙️  Compiling model with learning rate: {learning_rate}...")
    
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=learning_rate),
        loss='categorical_crossentropy',
        metrics=['accuracy', keras.metrics.TopKCategoricalAccuracy(k=2, name='top_2_accuracy')]
    )
    
    print("✅ Model compiled")
    return model


def get_callbacks():
    """Create training callbacks"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    callbacks = [
        # Save best model
        ModelCheckpoint(
            filepath=config.MODELS_DIR / f'best_model_{timestamp}.keras',
            monitor='val_accuracy',
            save_best_only=True,
            mode='max',
            verbose=1
        ),
        
        # Early stopping
        EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True,
            verbose=1
        ),
        
        # Reduce learning rate
        ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=8,
            min_lr=1e-8,
            verbose=1
        ),
        
        # CSV logger
        CSVLogger(
            filename=config.LOGS_DIR / f'training_log_{timestamp}.csv',
            separator=',',
            append=False
        )
    ]
    
    return callbacks


def plot_training_history(history, timestamp):
    """Plot and save training history graphs"""
    print("\n📈 Generating training graphs...")
    
    # Create figure with subplots
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('EfficientNet-B0 Training Analysis', fontsize=16, fontweight='bold')
    
    # Plot 1: Accuracy
    axes[0, 0].plot(history.history['accuracy'], label='Train Accuracy', linewidth=2)
    axes[0, 0].plot(history.history['val_accuracy'], label='Val Accuracy', linewidth=2)
    axes[0, 0].set_title('Model Accuracy', fontsize=12, fontweight='bold')
    axes[0, 0].set_xlabel('Epoch')
    axes[0, 0].set_ylabel('Accuracy')
    axes[0, 0].legend(loc='lower right')
    axes[0, 0].grid(True, alpha=0.3)
    
    # Plot 2: Loss
    axes[0, 1].plot(history.history['loss'], label='Train Loss', linewidth=2)
    axes[0, 1].plot(history.history['val_loss'], label='Val Loss', linewidth=2)
    axes[0, 1].set_title('Model Loss', fontsize=12, fontweight='bold')
    axes[0, 1].set_xlabel('Epoch')
    axes[0, 1].set_ylabel('Loss')
    axes[0, 1].legend(loc='upper right')
    axes[0, 1].grid(True, alpha=0.3)
    
    # Plot 3: Top-2 Accuracy
    axes[1, 0].plot(history.history['top_2_accuracy'], label='Train Top-2', linewidth=2)
    axes[1, 0].plot(history.history['val_top_2_accuracy'], label='Val Top-2', linewidth=2)
    axes[1, 0].set_title('Top-2 Accuracy', fontsize=12, fontweight='bold')
    axes[1, 0].set_xlabel('Epoch')
    axes[1, 0].set_ylabel('Accuracy')
    axes[1, 0].legend(loc='lower right')
    axes[1, 0].grid(True, alpha=0.3)
    
    # Plot 4: Learning Rate (if available)
    axes[1, 1].plot(history.history.get('lr', [config.LEARNING_RATE] * len(history.history['loss'])), 
                    label='Learning Rate', linewidth=2, color='orange')
    axes[1, 1].set_title('Learning Rate Schedule', fontsize=12, fontweight='bold')
    axes[1, 1].set_xlabel('Epoch')
    axes[1, 1].set_ylabel('Learning Rate')
    axes[1, 1].set_yscale('log')
    axes[1, 1].legend()
    axes[1, 1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    # Save figure
    graph_path = config.GRAPHS_DIR / f'training_history_{timestamp}.png'
    plt.savefig(graph_path, dpi=300, bbox_inches='tight')
    print(f"✅ Training graphs saved to {graph_path}")
    
    plt.close()


def evaluate_model(model, val_generator, timestamp):
    """Evaluate model and generate confusion matrix"""
    print("\n🎯 Evaluating model...")
    
    # Get predictions
    val_generator.reset()
    predictions = model.predict(val_generator, verbose=1)
    predicted_classes = np.argmax(predictions, axis=1)
    true_classes = val_generator.classes
    
    # Class names
    class_names = list(val_generator.class_indices.keys())
    
    # Classification Report
    print("\n📊 Classification Report:")
    report = classification_report(
        true_classes, 
        predicted_classes, 
        target_names=class_names,
        digits=4
    )
    print(report)
    
    # Save report
    report_path = config.LOGS_DIR / f'classification_report_{timestamp}.txt'
    with open(report_path, 'w') as f:
        f.write(report)
    
    # Confusion Matrix
    cm = confusion_matrix(true_classes, predicted_classes)
    
    # Plot confusion matrix
    plt.figure(figsize=(12, 10))
    sns.heatmap(
        cm, 
        annot=True, 
        fmt='d', 
        cmap='Blues',
        xticklabels=class_names,
        yticklabels=class_names,
        cbar_kws={'label': 'Count'}
    )
    plt.title('Confusion Matrix', fontsize=16, fontweight='bold', pad=20)
    plt.ylabel('True Label', fontsize=12)
    plt.xlabel('Predicted Label', fontsize=12)
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    plt.tight_layout()
    
    # Save confusion matrix
    cm_path = config.GRAPHS_DIR / f'confusion_matrix_{timestamp}.png'
    plt.savefig(cm_path, dpi=300, bbox_inches='tight')
    print(f"✅ Confusion matrix saved to {cm_path}")
    
    plt.close()
    
    # Per-class accuracy
    class_accuracy = cm.diagonal() / cm.sum(axis=1)
    
    print("\n📈 Per-Class Accuracy:")
    for class_name, accuracy in zip(class_names, class_accuracy):
        print(f"  {class_name}: {accuracy*100:.2f}%")
    
    return {
        'confusion_matrix': cm.tolist(),
        'class_accuracy': {name: float(acc) for name, acc in zip(class_names, class_accuracy)},
        'classification_report': report
    }


def convert_to_tflite(model, timestamp, best_val_accuracy):
    """Convert Keras model to TensorFlow Lite format"""
    print("\n🔄 Converting model to TensorFlow Lite...")
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    # Create model name with accuracy
    accuracy_pct = f"{best_val_accuracy * 100:.2f}"
    model_name = f'efficientnet_b0_{accuracy_pct}'
    
    # Save TFLite model
    tflite_path = config.MODELS_DIR / f'{model_name}.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✅ TFLite model saved to {tflite_path}")
    
    # Also save labels
    labels_path = config.MODELS_DIR / f'labels_{timestamp}.txt'
    with open(labels_path, 'w') as f:
        for class_name in config.CLASS_NAMES:
            f.write(f"{class_name}\n")
    
    print(f"✅ Labels saved to {labels_path}")
    
    return tflite_path, labels_path, model_name


def save_training_summary(history, evaluation_results, timestamp, training_duration=None):
    """Save comprehensive training summary"""
    summary = {
        'timestamp': timestamp,
        'model': 'EfficientNet-B0',
        'dataset': {
            'total_images': 2654,
            'train_samples': history.params['steps'] * config.BATCH_SIZE,
            'val_samples': len(evaluation_results['class_accuracy']) * config.BATCH_SIZE
        },
        'hyperparameters': {
            'batch_size': config.BATCH_SIZE,
            'epochs': len(history.history['loss']),
            'initial_learning_rate': config.LEARNING_RATE,
            'image_size': f"{config.IMG_HEIGHT}x{config.IMG_WIDTH}"
        },
        'training_duration': training_duration,
        'final_metrics': {
            'train_accuracy': float(history.history['accuracy'][-1]),
            'val_accuracy': float(history.history['val_accuracy'][-1]),
            'train_loss': float(history.history['loss'][-1]),
            'val_loss': float(history.history['val_loss'][-1])
        },
        'per_class_accuracy': evaluation_results['class_accuracy'],
        'best_epoch': int(np.argmax(history.history['val_accuracy'])) + 1,
        'best_val_accuracy': float(max(history.history['val_accuracy']))
    }
    
    summary_path = config.LOGS_DIR / f'training_summary_{timestamp}.json'
    with open(summary_path, 'w', encoding='utf-8') as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Training summary saved to {summary_path}")
    
    return summary


def main():
    """Main training pipeline"""
    print("=" * 80)
    print("🍌 BANANA LEAF DISEASE DETECTION - EfficientNet-B0 Training Pipeline")
    print("=" * 80)
    
    # Start timing
    start_time = time.time()
    start_datetime = datetime.now()
    timestamp = start_datetime.strftime('%Y%m%d_%H%M%S')
    
    print(f"\n⏱️  Training started at: {start_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 1. Load dataset info
    dataset_info = load_dataset_info()
    print(f"\n📂 Dataset: {dataset_info['dataset_name']}")
    print(f"📊 Total images: {dataset_info['total_images']}")
    
    # 2. Augment minority classes
    print("\n" + "="*80)
    augmented_dataset_path = augment_minority_classes()
    print("="*80)
    
    # 3. Create data generators with augmented dataset
    train_gen, val_gen = create_data_generators(augmented_dataset_path)
    
    # 3. Compute class weights
    class_weights = compute_class_weights(train_gen)
    
    # 4. Build model
    model = build_efficientnet_b0_model()
    model = compile_model(model)
    
    # Print model summary
    print("\n📋 Model Summary:")
    model.summary()
    
    # 5. Get callbacks
    callbacks = get_callbacks()
    
    # 6. Train model
    print("\n🚀 Starting training...")
    print("="*80)
    
    training_start = time.time()
    
    history = model.fit(
        train_gen,
        validation_data=val_gen,
        epochs=config.EPOCHS,
        callbacks=callbacks,
        class_weight=class_weights,
        verbose=1
    )
    
    training_end = time.time()
    training_duration_seconds = training_end - training_start
    
    print("\n✅ Training completed!")
    print(f"⏱️  Training time: {training_duration_seconds/3600:.2f} hours ({training_duration_seconds/60:.1f} minutes)")
    
    # 7. Plot training history
    plot_training_history(history, timestamp)
    
    # 8. Evaluate model
    evaluation_results = evaluate_model(model, val_gen, timestamp)
    
    # Get best validation accuracy
    best_val_accuracy = max(history.history['val_accuracy'])
    
    # 9. Convert to TFLite
    tflite_path, labels_path, model_name = convert_to_tflite(model, timestamp, best_val_accuracy)
    
    # 10. Calculate total duration
    total_duration_seconds = time.time() - start_time
    end_datetime = datetime.now()
    
    # Format training duration
    training_duration = {
        'total_seconds': float(training_duration_seconds),
        'total_minutes': float(training_duration_seconds / 60),
        'total_hours': float(training_duration_seconds / 3600),
        'formatted': f"{int(training_duration_seconds // 3600)}h {int((training_duration_seconds % 3600) // 60)}m {int(training_duration_seconds % 60)}s"
    }
    
    # Save training summary
    summary = save_training_summary(history, evaluation_results, timestamp, training_duration)
    
    # Final summary
    print("\n" + "=" * 80)
    print("🎉 TRAINING PIPELINE COMPLETED SUCCESSFULLY!")
    print("=" * 80)
    print(f"\n⏱️  Timeline:")
    print(f"  Started: {start_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Ended: {end_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Training Duration: {training_duration['formatted']}")
    print(f"  Total Pipeline Duration: {int(total_duration_seconds // 3600)}h {int((total_duration_seconds % 3600) // 60)}m {int(total_duration_seconds % 60)}s")
    print(f"\n📊 Final Results:")
    print(f"  Model Name: {model_name}")
    print(f"  Best Validation Accuracy: {summary['best_val_accuracy']*100:.2f}%")
    print(f"  Best Epoch: {summary['best_epoch']}")
    print(f"\n📁 Output Files:")
    print(f"  Models: {config.MODELS_DIR}")
    print(f"  Graphs: {config.GRAPHS_DIR}")
    print(f"  Logs: {config.LOGS_DIR}")
    print(f"\n🔄 Next Steps:")
    print(f"  1. Copy {tflite_path} to assets/models/")
    print(f"  2. Copy {labels_path} to assets/models/")
    print(f"  3. Run the Flutter app to test disease detection!")
    print("=" * 80)


if __name__ == '__main__':
    main()
