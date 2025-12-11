"""
Reconvert Keras model to TFLite with better compatibility for mobile devices
"""

import tensorflow as tf
from pathlib import Path

# Paths
BACKEND_DIR = Path(__file__).parent
MODEL_PATH = BACKEND_DIR / 'training_output' / 'models' / 'best_model_20251211_001504.keras'
OUTPUT_DIR = BACKEND_DIR / 'training_output' / 'models'

print(f"Looking for model at: {MODEL_PATH}")
print(f"Model exists: {MODEL_PATH.exists()}")

def convert_model_compatible():
    """Convert model with better mobile compatibility"""
    print("🔄 Loading Keras model...")
    model = tf.keras.models.load_model(MODEL_PATH)
    
    print("📊 Model loaded successfully!")
    print(f"Input shape: {model.input_shape}")
    print(f"Output shape: {model.output_shape}")
    
    # Convert to TFLite with different optimization settings
    print("\n🔄 Converting to TFLite (Mobile Compatible)...")
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Try without optimization first for maximum compatibility
    converter.optimizations = []
    
    # Set supported ops to include TensorFlow ops if needed
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,  # Enable TensorFlow Lite ops
        tf.lite.OpsSet.SELECT_TF_OPS     # Enable TensorFlow ops (fallback)
    ]
    
    # Allow custom ops
    converter.allow_custom_ops = True
    
    # Experimental features for better compatibility
    converter.experimental_new_converter = True
    
    tflite_model = converter.convert()
    
    # Save the new model
    output_path = OUTPUT_DIR / 'customcnn_94.07_compatible.tflite'
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✅ Compatible TFLite model saved to: {output_path}")
    print(f"📦 Model size: {len(tflite_model) / (1024*1024):.2f} MB")
    
    # Also try with quantization for smaller size
    print("\n🔄 Converting with quantization (smaller size)...")
    converter2 = tf.lite.TFLiteConverter.from_keras_model(model)
    converter2.optimizations = [tf.lite.Optimize.DEFAULT]
    converter2.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
        tf.lite.OpsSet.TFLITE_BUILTINS
    ]
    
    # Representative dataset for quantization
    import numpy as np
    def representative_dataset():
        for _ in range(100):
            # Generate random data matching your input shape
            data = np.random.rand(1, 224, 224, 3).astype(np.float32)
            yield [data]
    
    converter2.representative_dataset = representative_dataset
    converter2.target_spec.supported_types = [tf.float16]
    
    try:
        tflite_model_quant = converter2.convert()
        output_path_quant = OUTPUT_DIR / 'customcnn_94.07_quantized.tflite'
        with open(output_path_quant, 'wb') as f:
            f.write(tflite_model_quant)
        print(f"✅ Quantized model saved to: {output_path_quant}")
        print(f"📦 Model size: {len(tflite_model_quant) / (1024*1024):.2f} MB")
    except Exception as e:
        print(f"⚠️  Quantization failed: {e}")
    
    print("\n" + "="*80)
    print("✨ Conversion complete!")
    print("="*80)
    print("\n📝 Next steps:")
    print("1. Copy the compatible model to assets:")
    print(f"   Copy-Item '{output_path}' 'C:\\src\\repo\\wowooo\\assets\\models\\customcnn_94.07.tflite' -Force")
    print("\n2. Restart the Flutter app")
    print("="*80)

if __name__ == '__main__':
    try:
        convert_model_compatible()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
