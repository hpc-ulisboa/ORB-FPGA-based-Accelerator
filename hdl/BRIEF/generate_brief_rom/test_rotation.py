import numpy as np
import matplotlib.pyplot as plt

# Function to rotate a point around the origin
def rotate_point(x, y, angle_rad):
    x_rot = x * np.cos(angle_rad) - y * np.sin(angle_rad)
    y_rot = x * np.sin(angle_rad) + y * np.cos(angle_rad)
    return x_rot, y_rot

# Read coordinate pairs from a file
def read_coordinates(filename):
    coordinates = []
    with open(filename, 'r') as file:
        for line in file:
            # Parse the line for coordinate pairs
            # Example input line: {{8,-3},{9,5}}
            pairs = line.strip().replace('{', '').replace('}', '').split(',')
            x1, y1 = map(int, pairs[:2])
            x2, y2 = map(int, pairs[2:])
            coordinates.append(((x1, y1), (x2, y2)))
    return coordinates

# Function to rotate all coordinate pairs by a given angle in degrees
def rotate_coordinates(coordinates, angle):
    #angle_rad = np.deg2rad(angle_deg)
    rotated_coordinates = []
    for (x1, y1), (x2, y2) in coordinates:
        # Rotate both points of the line segment
        x1_rot, y1_rot = rotate_point(x1, y1, angle)
        x2_rot, y2_rot = rotate_point(x2, y2, angle)
        rotated_coordinates.append(((x1_rot, y1_rot), (x2_rot, y2_rot)))
    return rotated_coordinates

# Function to plot line segments
def plot_coordinates(coordinates, title, filename):
    plt.figure()
    for (x1, y1), (x2, y2) in coordinates:
        plt.plot([x1, x2], [y1, y2], marker='o')  # Plot each segment with markers
    plt.title(title)
    plt.xlabel('X')
    plt.ylabel('Y')
    plt.grid(True)
    plt.axis('equal')  # Ensure the aspect ratio is equal for accurate visualization
    plt.savefig(filename)
    plt.close()
    print(f"Saved figure: {filename}")

# Main function
def main():
    # File containing coordinate pairs
    input_file = 'BRIEF_pattern_1.txt'
    
    # Read the coordinate pairs from the file
    coordinates = read_coordinates(input_file)
    
    # Define the angle of rotation
    angle_deg = 45  # Change this to your desired rotation angle

    # Rotate the coordinates
    rotated_coordinates = rotate_coordinates(coordinates, np.deg2rad(angle_deg))

    # Plot and save the original coordinates
    plot_coordinates(coordinates, 'Original Line Segments', 'original_segments.png')
    
    # Plot and save the rotated coordinates
    plot_coordinates(rotated_coordinates, f'Rotated Line Segments by {angle_deg}°', 'rotated_segments.png')

if __name__ == '__main__':
    main()
