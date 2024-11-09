import os
import json
import math
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
import requests
from io import BytesIO
from inference_sdk import InferenceHTTPClient

class WoundAnalyzer:
    def __init__(self, api_key):
        self.client = InferenceHTTPClient(
            api_url="https://detect.roboflow.com",
            api_key=api_key
        )

    def analyze_image(self, image_path):
        """
        Analyze wound image using the Roboflow API
        """
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image file not found: {image_path}")

        result = self.client.run_workflow(
            workspace_name="woundly",
            workflow_id="custom-workflow-fze",
            images={"image": image_path}
        )
        return result

    @staticmethod
    def draw_polygons_on_image(image_path, predictions):
        """
        Draw polygon overlays on the image for wounds and stickers
        """
        if image_path.startswith('http'):
            response = requests.get(image_path)
            image = Image.open(BytesIO(response.content))
        else:
            image = Image.open(image_path)

        fig, ax = plt.subplots(figsize=(10, 10))
        ax.imshow(image)

        class_info = {
            0: {'color': 'black', 'label': 'Diabetic Foot Ulcer'},
            1: {'color': 'green', 'label': 'Sticker'}
        }

        for prediction in predictions:
            class_id = prediction['class_id']
            points = prediction['points']
            polygon = [(point['x'], point['y']) for point in points]
            poly_patch = patches.Polygon(
                polygon,
                linewidth=2,
                edgecolor=class_info[class_id]['color'],
                facecolor='none',
                label=class_info[class_id]['label']
            )
            ax.add_patch(poly_patch)

        handles, labels = ax.get_legend_handles_labels()
        by_label = dict(zip(labels, handles))
        ax.legend(by_label.values(), by_label.keys())

        ax.axis('off')
        plt.show()

    @staticmethod
    def calculate_polygon_area(points):
        """
        Calculate polygon area using the Shoelace formula
        """
        n = len(points)
        area = 0.0
        for i in range(n):
            j = (i + 1) % n
            area += points[i]['x'] * points[j]['y']
            area -= points[j]['x'] * points[i]['y']
        return abs(area) / 2.0

    @staticmethod
    def calculate_real_world_areas(json_data):
        """
        Calculate real-world areas based on the sticker reference
        """
        sticker_image_area = 0
        ulcer_image_area = 0
        
        for entry in json_data:
            predictions = entry['predictions']['predictions']
            for prediction in predictions:
                points = prediction['points']
                area = WoundAnalyzer.calculate_polygon_area(points)
                if prediction['class_id'] == 0:  # Ulcer
                    ulcer_image_area += area
                elif prediction['class_id'] == 1:  # Sticker
                    sticker_image_area += area

        print(f"Relative Diabetic Foot Ulcer Area: {ulcer_image_area:.2f} square pixels")
        print(f"Relative Sticker Area: {sticker_image_area:.2f} square pixels")

        # Calculate the scale based on the sticker's known size
        actual_sticker_diameter_mm = 8
        if sticker_image_area > 0:
            sticker_diameter_pixels = 2 * math.sqrt(sticker_image_area / math.pi)
            scale_factor = sticker_diameter_pixels / actual_sticker_diameter_mm  # pixels per mm

            if scale_factor > 0:
                sticker_real_area = sticker_image_area / (scale_factor ** 2)
                ulcer_real_area = ulcer_image_area / (scale_factor ** 2)
                print(f"Sticker Area: {sticker_real_area:.2f} square mm")
                print(f"Diabetic Foot Ulcer Area: {ulcer_real_area:.2f} square mm")
                return {
                    'ulcer_area_pixels': ulcer_image_area,
                    'sticker_area_pixels': sticker_image_area,
                    'ulcer_area_mm': ulcer_real_area,
                    'sticker_area_mm': sticker_real_area
                }
            else:
                print("Scale factor is zero, cannot compute real areas.")
                return None
        else:
            print("Sticker image area is zero, cannot compute diameter or scale factor.")
            return None

def main():
    # Configuration
    API_KEY = "oTOJ7XFVwwGFuoiiBcs1"  # Consider moving this to environment variable
    IMAGE_PATH = "Untitled.jpg"  # Replace with your image path

    try:
        # Initialize analyzer
        analyzer = WoundAnalyzer(API_KEY)

        # Analyze image
        result = analyzer.analyze_image(IMAGE_PATH)

        # Extract predictions
        predictions = result[0]['predictions']['predictions']

        # Draw polygons
        analyzer.draw_polygons_on_image(IMAGE_PATH, predictions)

        # Calculate areas
        areas = analyzer.calculate_real_world_areas(result)

        if areas:
            print("\nAnalysis Summary:")
            print(f"Ulcer Area: {areas['ulcer_area_mm']:.2f} mm²")
            print(f"Reference Sticker Area: {areas['sticker_area_mm']:.2f} mm²")

    except FileNotFoundError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()