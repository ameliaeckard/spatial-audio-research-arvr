# YOLO Object Detection Training & Integration Guide

## Overview

Complete workflow for training and deploying a YOLO model to detect 3-5 objects (Mug, Water Bottle, Chair) in your Vision Pro app.

---

## Phase 1: Image Collection (Tomorrow)

### What You Need
- **3-5 physical objects** (already defined in app: Mug, Water Bottle, Chair)
- **iPhone/Camera** for capturing images
- **100-200 photos per object** (total: 300-1000 images)

### How to Capture Images

#### Best Practices
1. **Different angles**: Front, back, sides, top, bottom (360° coverage)
2. **Different distances**: Close-up (0.5m) to far (5m)
3. **Different lighting**: Bright, dim, natural light, artificial light
4. **Different backgrounds**: Tables, floors, shelves, counters
5. **Different contexts**: Alone, with other objects, in groups
6. **Different orientations**: Upright, tilted, on its side

#### Quick Capture Method
```
Per Object (20-30 minutes):
1. Place object on table
2. Walk around in circle, take 20-30 photos
3. Move to different location, repeat
4. Change lighting, repeat
5. Add different backgrounds, repeat
6. Result: 100-200 diverse images
```

#### Pro Tips
- **Use burst mode** on iPhone (hold shutter button)
- **Slightly blur/unfocus** some images (realistic conditions)
- **Include partial views** (object at edge of frame)
- **Vary object placement** (center, corners, edges)
- **NO need for vectorized images** - real photos work best!

### File Organization
```
dataset/
├── mug/
│   ├── mug_001.jpg
│   ├── mug_002.jpg
│   └── ... (100-200 images)
├── water_bottle/
│   ├── bottle_001.jpg
│   └── ... (100-200 images)
└── chair/
    ├── chair_001.jpg
    └── ... (100-200 images)
```

---

## Phase 2: Annotation (1-2 hours)

### Tool: Roboflow (FREE and easiest)

#### Setup (5 minutes)
1. Go to **https://roboflow.com**
2. Create free account
3. Create new project: "VisionPro-Objects"
4. Select: **Object Detection**

#### Upload Images (10 minutes)
1. Click "Upload Data"
2. Drag and drop your folders
3. Roboflow auto-organizes by folder name
4. Click "Finish Uploading"

#### Annotation Process (1-2 hours)

**Option 1: Manual Annotation**
```
For each image:
1. Click on image
2. Press 'B' for bounding box tool
3. Click and drag around object
4. Type label: "mug", "water_bottle", or "chair"
5. Press Enter
6. Next image (arrow key)

Time: ~1-2 seconds per image
Total: 300 images × 2 seconds = 10 minutes
```

**Option 2: Smart Annotation (Recommended)**
```
1. Manually annotate 20-30 images per class
2. Click "Generate" → "Use Roboflow Annotate"
3. AI auto-annotates remaining images
4. Review and correct (much faster)

Time: ~30 minutes total
```

#### Export Dataset
1. Click "Generate" → "Generate Version"
2. Preprocessing: Keep defaults or add:
   - Auto-Orient: ✅
   - Resize: 640×640 (YOLO standard)
3. Augmentation (Optional but recommended):
   - Flip: Horizontal ✅
   - Rotation: ±15°
   - Brightness: ±15%
   - Blur: Up to 1px
4. Click "Generate"
5. Export Format: **YOLOv8** ✅
6. Download ZIP file

---

## Phase 3: Training (30 min - 2 hours)

### Option A: Google Colab (FREE GPU - Recommended)

#### Setup (5 minutes)
1. Go to **https://colab.research.google.com**
2. Create new notebook
3. Runtime → Change runtime type → **T4 GPU** → Save

#### Training Code (Copy-Paste)
```python
# Install YOLOv8
!pip install ultralytics

# Import
from ultralytics import YOLO
from google.colab import files
import zipfile

# Upload your dataset ZIP from Roboflow
uploaded = files.upload()  # Click and select your ZIP

# Unzip dataset
!unzip -q your_dataset.zip -d dataset/

# Load YOLOv8 nano model (fastest for Vision Pro)
model = YOLO('yolov8n.pt')

# Train (adjust epochs based on time)
results = model.train(
    data='dataset/data.yaml',  # Roboflow provides this
    epochs=50,                 # Start with 50, increase if needed
    imgsz=640,                 # Image size
    batch=16,                  # Batch size
    name='visionpro_objects',
    patience=10,               # Early stopping
    device=0                   # Use GPU
)

# Export to CoreML for Vision Pro
model.export(format='coreml', nms=True, imgsz=640)

# Download the model
!zip -r visionpro_model.zip runs/detect/visionpro_objects/weights/best.mlmodel
files.download('visionpro_model.zip')
```

#### Run Training
1. Copy code above into Colab cell
2. Click Run (▶)
3. Upload your dataset ZIP when prompted
4. Wait 30 min - 2 hours (Colab will show progress)
5. Download `visionpro_model.zip` when complete

### Training Time Estimates
- **300 images, 50 epochs**: ~30 minutes
- **600 images, 100 epochs**: ~1-2 hours
- **1000 images, 100 epochs**: ~2-3 hours

---

## Phase 4: Integration (10 minutes)

### Add Model to Xcode

1. **Unzip** the downloaded model
2. **Rename** `best.mlmodel` → `CustomObjectDetector.mlmodel`
3. **Drag into Xcode**:
   - Open your project
   - Drag `CustomObjectDetector.mlmodel` into Project Navigator
   - ✅ Copy items if needed
   - ✅ Add to targets: Spatial-Audio-Research-ARVR
   - Click "Add"

4. **Switch to YOLO mode** in `AppModel.swift`:
   ```swift
   // Line 65: Change from .mock to .yolo
   var detectionMode: DetectionMode = .yolo  // ← Change this
   ```

5. **Build and Run** on Vision Pro
   - ⌘R or click Play
   - App will automatically load YOLO model
   - Should see: "✅ YOLO model loaded successfully"

---

## Phase 5: Testing & Validation

### Quick Test
```
1. Place real water bottle on table
2. Launch app on Vision Pro
3. Check console for: "🎯 Detected 1 objects: Water Bottle"
4. Verify:
   - Green bounding box appears
   - Spatial audio plays from bottle direction
   - Distance shown in UI
```

### Validate Accuracy
```
1. Place all 3 objects at known positions
2. Run detection for 1 minute
3. Count: Correct detections / Total detections
4. Target: >85% accuracy

If accuracy is low:
- Collect more images (especially missed cases)
- Train longer (100+ epochs)
- Check lighting in test environment
```

---

## Troubleshooting

### "Model not found" Error
- Verify file named exactly: `CustomObjectDetector.mlmodel`
- Check it's in project target membership
- Clean build folder (⇧⌘K) and rebuild

### Low Detection Accuracy
- **More training data**: Collect 200+ images per object
- **Better annotations**: Review bounding boxes are tight
- **More epochs**: Train for 100 epochs instead of 50
- **Augmentation**: Enable more in Roboflow

### Detection Too Slow
- Model already uses YOLOv8-nano (fastest)
- Reduce processing frequency (line 22 in YOLOObjectDetector)
- Ensure running on device, not simulator

### Wrong Object Labels
- Check label names match exactly:
  - "Mug" (capital M)
  - "Water Bottle" (capital W and B, with space)
  - "Chair" (capital C)
- Re-export dataset with correct labels

---

## Summary Timeline

| Phase | Time | Tools |
|-------|------|-------|
| **Image Collection** | 1-2 hours | iPhone camera |
| **Annotation** | 30-60 min | Roboflow |
| **Training** | 30 min - 2 hrs | Google Colab (free GPU) |
| **Integration** | 10 minutes | Xcode |
| **Testing** | 30 minutes | Vision Pro |
| **TOTAL** | **3-6 hours** | All free! |

---

## Key Points

✅ **No manual annotation needed** - Roboflow AI helps  
✅ **No GPU required** - Google Colab provides free GPU  
✅ **No coding needed** - Copy-paste training script  
✅ **Real photos > vectorized** - Use actual camera photos  
✅ **Already integrated** - Just add model file and flip switch  

---

## Next Steps

**Tomorrow:**
1. Take photos of your 3-5 objects (1-2 hours)
2. Upload to Roboflow and annotate (30-60 min)
3. Train in Colab (run and wait 30 min - 2 hrs)
4. Download model, add to Xcode (10 min)
5. Test on Vision Pro! 🎉

**Questions?** Check console logs for helpful messages from YOLOObjectDetector.
