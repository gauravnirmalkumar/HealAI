from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from flask_cors import CORS  # Add this import
import os
from wound_analyzer import WoundAnalyzer

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configuration
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
API_KEY = "oTOJ7XFVwwGFuoiiBcs1"  # Move this to environment variables in production

# Create uploads directory if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/analyze-wound', methods=['POST', 'OPTIONS'])
def analyze_wound():
    if request.method == 'OPTIONS':
        return '', 204
        
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
        
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
        
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        try:
            analyzer = WoundAnalyzer(API_KEY)
            result = analyzer.analyze_image(filepath)
            areas = analyzer.calculate_real_world_areas(result)
            
            # Clean up uploaded file
            os.remove(filepath)
            
            if areas:
                return jsonify({
                    'ulcer_area_pixels': areas['ulcer_area_pixels'],
                    'sticker_area_pixels': areas['sticker_area_pixels'],
                    'ulcer_area_mm': areas['ulcer_area_mm'],
                    'sticker_area_mm': areas['sticker_area_mm']
                })
            else:
                return jsonify({'error': 'Could not calculate areas'}), 400
                
        except Exception as e:
            # Clean up uploaded file in case of error
            if os.path.exists(filepath):
                os.remove(filepath)
            return jsonify({'error': str(e)}), 500
            
    return jsonify({'error': 'Invalid file type'}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)