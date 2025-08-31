import os
import numpy as np
import matplotlib.pyplot as plt

def distance_from_origin(point):
    return np.sqrt(point[0]**2 + point[1]**2)

# Function to adjust a point to a specific distance from the origin
def adjust_point(point, target_distance):
    distance = distance_from_origin(point)
    if distance > target_distance:
        # Scale the point coordinates to have the desired distance while keeping the same angle
        scaling_factor = target_distance / distance
        point[0] *= scaling_factor
        point[1] *= scaling_factor
    return point

def read_coordinates(filename):
    coordinates = []
    
    with open(filename, 'r') as file:
        for line in file:
            # Clean up the line to extract the coordinates using string manipulation
            line = line.strip().replace("{{", "").replace("}}", "").replace(" ", "")
            if line:
                # Split the line into separate coordinate pairs
                pairs = line.split("},{")
                # Parse the pairs and convert to a 2D array
                points = [list(map(int, pair.split(','))) for pair in pairs]
                points[0]=adjust_point(points[0], 15)
                points[1]=adjust_point(points[1], 15)
                # Append as a NumPy array to the coordinates list
                coordinates.append(np.array(points))
                
    return np.array(coordinates)

# Function to rotate a point around the origin
def rotate_point(x, y, angle_rad):
    x_rot = x * np.cos(angle_rad) - y * np.sin(angle_rad)
    y_rot = x * np.sin(angle_rad) + y * np.cos(angle_rad)
    return x_rot, y_rot
# Function to rotate all coordinate pairs by a given angle in degrees
def rotate_coordinates(coordinates, angle):
    #angle_rad = np.deg2rad(angle_deg)
    rotated_coordinates = []
    for (x1, y1), (x2, y2) in coordinates:
        # Rotate both points of the line segment
        x1_rot, y1_rot = rotate_point(x1, y1, angle)
        x2_rot, y2_rot = rotate_point(x2, y2, angle)
        x1_rot=int(np.round(x1_rot+15.5))
        y1_rot=int(np.round(y1_rot+15.5))
        x2_rot=int(np.round(x2_rot+15.5))
        y2_rot=int(np.round(y2_rot+15.5))
        rotated_coordinates.append(((x1_rot, y1_rot), (x2_rot, y2_rot)))
    return rotated_coordinates

def dec2bin(decimal_num, width):
    if decimal_num >= 0:
        binary_str = bin(decimal_num)[2:].zfill(width)  # Convert positive decimal to binary and pad with zeros
    else:
        # Convert the absolute value to binary
        binary_str = bin(abs(decimal_num))[2:].zfill(width)
        # Take the 2's complement by flipping the bits and adding 1
        binary_str = ''.join('1' if bit == '0' else '0' for bit in binary_str)
        binary_str = bin(int(binary_str, 2) + 1)[2:].zfill(width)
    return binary_str

def compose_mem(angle):
    #print(np.rad2deg(angle))
    text_format = "Pair\n"
    pairs_per_line = 3
    coordinate_size = 5
    cnt = 1
    cnt2 = 0
    bram_cnt = 0
    bram_cnt_0 = 0
    bram_cnt_1 = 0
    bram_cnt_0_a = 0
    bram_cnt_a = 0
    bram_cnt_1_a = 0
    bram2write = 0
    binary_str = []
    binary_str_tmp = ""
    binary_str_0 = []
    binary_str_0_tmp = ""
    binary_str_1 = []
    binary_str_1_tmp = ""
    write_0 = 1
    write_1 = 0

    plt.figure(figsize=(10, 10))
    #print(coordinates)
    rotated_coordinates = rotate_coordinates(coordinates, angle)
    #print(rotated_coordinates)
    for (x_0, y_0), (x_1, y_1) in rotated_coordinates:
        cnt += 1
        cnt2 += 1
     
        # Convert decimal number to a binary string with a specified bit length
        #binary_str = ""
        #if angle == 0:
        #    x_0 = line[0][0]
        #    y_0 = line[0][1]
        #    x_1 = line[1][0]
        #    y_1 = line[1][1]
        #else:
        #x_0,y_0 = line[0][0],line[0][1]
        #x_1,y_1 = line[1][0],line[1][1]
        plt.plot([x_0,x_1], [y_0,y_1], marker='o', linestyle='-')
        #print([x_0,y_0], [x_1,y_1])
        if angle==0:
            print_line=str(line[0][0])+","+str(line[0][1])+"\t\t->"+str(x_0)+","+str(y_0)
            print(print_line)
        if x_0>31 or y_0>31 or x_1>31 or y_1>31:
            print(f"Error: {x_0} {y_0} {x_1} {y_1} {line[0][0]} {line[0][1]} {line[1][0]} {line[1][1]} {angle*180/np.pi}")
        if x_0<0 or y_0<0 or x_1<0 or y_1<0:
            print(f"Error: {x_0} {y_0} {x_1} {y_1} {line[0][0]} {line[0][1]} {line[1][0]} {line[1][1]} {angle*180/np.pi}")
        
        text_format += f"    {{{{{x_0}, {y_0}}}, {{{x_1}, {y_1}}}}},\n"

        bram_cnt += 1
        binary_str_tmp += str(f"{dec2bin(abs(y_0),coordinate_size)}")[::-1]
        binary_str_tmp += str(f"{dec2bin(abs(x_0),coordinate_size)}")[::-1] 
        binary_str_tmp += str(f"{dec2bin(abs(y_1),coordinate_size)}")[::-1] 
        binary_str_tmp += str(f"{dec2bin(abs(x_1),coordinate_size)}")[::-1]
        """ if cnt2%3==0:
            binary_str_tmp += "0000"
            binary_str.append(binary_str_tmp)
            binary_str_tmp = ""
            bram_cnt_a += 1 """
        if bram2write == 0:
            write_0 = 1
            write_1 = 0
        else:
            write_0 = 0
            write_1 = 1

        if write_0 == 1:
            bram_cnt_0 += 1
            binary_str_0_tmp += str(f"{dec2bin(abs(x_0),coordinate_size)}")[::-1]
            binary_str_0_tmp += str(f"{dec2bin(abs(y_0),coordinate_size)}")[::-1]
            binary_str_0_tmp += str(f"{dec2bin(abs(x_1),coordinate_size)}")[::-1]
            binary_str_0_tmp += str(f"{dec2bin(abs(y_1),coordinate_size)}")[::-1]
            if cnt2%pairs_per_line==0:
                binary_str_0_tmp += "0000"
                binary_str_0.append(binary_str_0_tmp)
                binary_str_0_tmp = ""
                bram_cnt_0_a += 1
                if write_0 != write_1:
                    bram2write = bram2write^1

        if write_1 == 1:
            bram_cnt_1 += 1
            binary_str_1_tmp += str(f"{dec2bin(abs(x_0),coordinate_size)}")[::-1] #str(f"{"""0 if x_0>0 else 1"""}{dec2bin(abs(x_0),6)}")[::-1] 
            binary_str_1_tmp += str(f"{dec2bin(abs(y_0),coordinate_size)}")[::-1] #str(f"{"""0 if y_0>0 else 1"""}{dec2bin(abs(y_0),6)}")[::-1] 
            binary_str_1_tmp += str(f"{dec2bin(abs(x_1),coordinate_size)}")[::-1] #str(f"{"""0 if x_1>0 else 1"""}{dec2bin(abs(x_1),6)}")[::-1] 
            binary_str_1_tmp += str(f"{dec2bin(abs(y_1),coordinate_size)}")[::-1] #str(f"{"""0 if y_1>0 else 1"""}{dec2bin(abs(y_1),6)}")[::-1]
            if cnt2%pairs_per_line==0:
                binary_str_1_tmp += "0000"
                binary_str_1.append(binary_str_1_tmp)
                binary_str_1_tmp = ""
                bram_cnt_1_a += 1
                if write_0 != write_1:
                    bram2write = bram2write^1

        if cnt2%pairs_per_line==0:
            binary_str_tmp += "0000"
            binary_str.append(binary_str_tmp)
            binary_str_tmp = ""
            bram_cnt_a += 1
        
        #if cnt2%3==0:
        #    bram2write = bram2write^1
        
        #print(f"line {cnt} {bram_cnt_0} {bram_cnt_0_a} {bram_cnt_1_a} {bram2write} {write_0} {write_1} {cnt2}")

    plt.xlim(0, 31)
    plt.ylim(0, 31)
    plt.grid(True)
    plt.title('256 Random 2D Coordinate Pairs')
    figure_file_name = f'output_extras/BRIEF_pattern_{int(n_sections)}_{int(np.rad2deg(angle))}.png'
    plt.savefig(figure_file_name)  # Save the image
    plt.close()
    #print(bram_cnt_1_a,bram_cnt_0_a)
    if (bram_cnt%pairs_per_line!=0):
        while bram_cnt%pairs_per_line!=0:
            binary_str_tmp += "00000000000000000000"
            bram_cnt += 1
        binary_str_tmp += "0000"
        binary_str.append(binary_str_tmp)
        binary_str_tmp = ""
        bram_cnt_a += 1
    if (bram_cnt_0%pairs_per_line!=0):
        while bram_cnt_0%pairs_per_line!=0:
            binary_str_0_tmp += "00000000000000000000"
            bram_cnt_0 += 1
        binary_str_0_tmp += "0000"
        binary_str_0.append(binary_str_0_tmp)
        binary_str_0_tmp = ""
        bram_cnt_0_a += 1
    if (bram_cnt_1%pairs_per_line!=0):
        while bram_cnt_1%pairs_per_line!=0:
            binary_str_1_tmp += "00000000000000000000"
            bram_cnt_1 += 1
        binary_str_1_tmp += "0000"
        binary_str_1.append(binary_str_1_tmp)
        binary_str_1_tmp = ""
        bram_cnt_1_a += 1

    #print(f"leveled {cnt} {bram_cnt_0} {bram_cnt_0_a} {bram_cnt_1_a} {bram2write} {cnt2}")

    for i in range(128-bram_cnt_a):
        for j in range(pairs_per_line):
            binary_str_tmp += "00000000000000000000"
        binary_str_tmp += "0000"
        binary_str.append(binary_str_tmp)
        binary_str_tmp = ""
        bram_cnt_a += 1
    for i in range(int(256/3/2)-bram_cnt_0_a+1):
        for j in range(pairs_per_line):
            binary_str_0_tmp += "00000000000000000000"
        binary_str_0_tmp += "0000"
        binary_str_0.append(binary_str_0_tmp)
        binary_str_0_tmp = ""
        bram_cnt_0_a += 1
    for i in range(int(256/3/2)-bram_cnt_1_a+1):
        for j in range(pairs_per_line):
            binary_str_1_tmp += "00000000000000000000"
        binary_str_1_tmp += "0000"
        binary_str_1.append(binary_str_1_tmp)
        binary_str_1_tmp = ""
        bram_cnt_1_a += 1

    #print(f"leveled {cnt} {bram_cnt_0} {bram_cnt_0_a} {bram_cnt_1_a} {bram2write} {cnt2}")

    return text_format, binary_str, binary_str_0, binary_str_1

# Example usage: assuming the text file is named "coordinates.txt"
coordinates = read_coordinates('BRIEF_pattern.txt')



if not os.path.exists("roms"): 
      
    # if the extras output directory is not present  
    # then create it. 
    os.makedirs("roms") 


if not os.path.exists("output_extras"): 
      
    # if the extras output directory is not present  
    # then create it. 
    os.makedirs("output_extras") 

# Create an image to plot the lines
plt.figure(figsize=(5, 5))
for line in coordinates:
    plt.plot(line[:, 0], line[:, 1], marker='o', linestyle='-')

plt.xlim(-17, 17)
plt.ylim(-17, 17)
plt.grid(True)
#plt.title('256 Random 2D Coordinate Pairs')
plt.savefig('output_extras/BRIEF_coordinate_pairs.pdf')  # Save the image


for n_sections_exp in range(2,6,1):
    # Generate 256 random 2D coordinate pairs
    num_pairs = 256
    #coordinates = np.zeros((num_pairs, 2, 2))  # 256 lines, each with 2 points (x, y), in [0, 26]
    n_sections = 2**n_sections_exp
    addr_size = np.ceil(np.log2(n_sections*86*4))
    bram_depth = n_sections*86*4
    step = 90/n_sections

    # Convert the coordinates to the required C++ format
    cpp_format = "const int brief_pattern[256][2][2] = {\n"
    text_format = ""
    vhd_format = "constant brief_pattern : position_origin_pattern_type := ("
    bit_length = 8  # 5 bits, for example
    for line in coordinates:
        # Format each coordinate pair correctly for C++
        cpp_format += f"    {{{{{int(line[0][1])}, {int(line[0][0])}}}, {{{int(line[1][1])}, {int(line[1][0])}}}}},\n"

    # 33.75, 56.25, 78.75
    binary_str = []
    binary_str_0 = []
    binary_str_1 = []
    """ for i in range(4):
        offset = np.deg2rad(i*90)
        print(offset)
        text_format_tmp, binary_str_tmp, binary_str_0_tmp, binary_str_1_tmp = compose_mem(np.deg2rad(11.25))
        text_format += text_format_tmp
        for line in binary_str_tmp:
            binary_str.append(line)
        for line in binary_str_0_tmp:
            binary_str_0.append(line)
        for line in binary_str_1_tmp:
            binary_str_1.append(line)
        text_format_tmp, binary_str_tmp, binary_str_0_tmp, binary_str_1_tmp = compose_mem(np.deg2rad(33.75))
        text_format += text_format_tmp
        for line in binary_str_tmp:
            binary_str.append(line)
        for line in binary_str_0_tmp:
            binary_str_0.append(line)
        for line in binary_str_1_tmp:
            binary_str_1.append(line)
        text_format_tmp, binary_str_tmp, binary_str_0_tmp, binary_str_1_tmp = compose_mem(np.deg2rad(56.25))
        text_format += text_format_tmp
        for line in binary_str_tmp:
            binary_str.append(line)
        for line in binary_str_0_tmp:
            binary_str_0.append(line)
        for line in binary_str_1_tmp:
            binary_str_1.append(line)
        text_format_tmp, binary_str_tmp, binary_str_0_tmp, binary_str_1_tmp = compose_mem(np.deg2rad(78.75))
        text_format += text_format_tmp
        for line in binary_str_tmp:
            binary_str.append(line)
        for line in binary_str_0_tmp:
            binary_str_0.append(line)
        for line in binary_str_1_tmp:
            binary_str_1.append(line) """

    for quad in range(0,4):
        for section in range(0,n_sections):
            angle = step/2+step*section
            if quad == 0:
                offset = 0
            elif quad == 1 or quad == 2:
                offset = 180
            else:
                offset = 360   

            conv_angle = offset+(angle)*((-1)**quad)
            print(quad,conv_angle,"º")#,section,conv_angle,"º",section)
            conv_angle = np.deg2rad(conv_angle)
            text_format_tmp, binary_str_tmp, binary_str_0_tmp, binary_str_1_tmp = compose_mem(conv_angle)
            text_format += text_format_tmp
            for line in binary_str_tmp:
                binary_str.append(line)
            for line in binary_str_0_tmp:
                binary_str_0.append(line)
            for line in binary_str_1_tmp:
                binary_str_1.append(line)

    cpp_format = cpp_format.rstrip(",\n")  # Remove the last comma and newline
    vhd_format = vhd_format.rstrip(",\n")  # Remove the last comma and newline
    cpp_format += "\n};"
    vhd_format += "\n);"

    # Write to a text file
    #cpp_filename = 'BRIEF_pattern.txt'
    #with open(cpp_filename, 'w') as file:
    #    file.write(cpp_format)
    #vhd_filename = 'BRIEF_pattern_vhd.txt'
    #with open(vhd_filename, 'w') as file:
    #    file.write(vhd_format)
    text_filename = f'output_extras/BRIEF_pattern_aux_{int(n_sections)}_sec.txt'
    with open(text_filename, 'w') as file:
        file.write(text_format)
    #bit_filename = 'BRIEF_pattern_bram0.data'
    #with open(bit_filename, 'w') as file:
    #    #bit_format_0.tofile(file)
    #    #file.write(bit_format_0.to01())
    #    for line in binary_str_0:
    #        line1 = line[:32]
    #        line2 = line[32:]
    #        file.write(line1[::-1])
    #        file.write("\n")
    #        file.write(line2[::-1])
    #        file.write("\n")
    bit_filename = f"roms/rams_sp_rom0_{int(n_sections)}_sec.v"
    with open(bit_filename, 'w') as file:
        #bit_format_0.tofile(file)
        #file.write(bit_format_0.to01())
        file.write(f"module rams_sp_rom0_{int(n_sections)}_sec (clk, enA, enB, addrA, addrB, doA, doB);\n")
        file.write("input clk;\n")
        file.write("input enA, enB;\n")
        file.write(f"input [{int(addr_size-1)}:0] addrA, addrB;\n")
        file.write("output [31:0] doA, doB;\n")
        file.write(f"(*rom_style = \"block\" *) reg [{int(n_sections*86*4)-1}:0] dataA, dataB;\n")
        file.write("always @(posedge clk)\n")
        file.write("begin\n")
        file.write("if (enA)\n")
        file.write("case(addrA)\n")
        index=0
        for line in binary_str_0:
            line1 = line[:32]
            line2 = line[32:]

            line_11 = str(f"{int(addr_size)}'b{dec2bin(int(index*2),int(addr_size))}: dataA <= 32'b")+line1[::-1]
            file.write(line_11)
            file.write(";\n")
            line_21 = str(f"{int(addr_size)}'b{dec2bin(int(index*2+1),int(addr_size))}: dataA <= 32'b")+line2[::-1]
            file.write(line_21)
            file.write(";\n")
            index=index+1
        file.write("endcase\n")
        file.write("if (enB)\n")
        file.write("case(addrB)\n")
        index=0
        for line in binary_str_0:
            line1 = line[:32]
            line2 = line[32:]

            line_11 = str(f"{int(addr_size)}'b{dec2bin(int(index*2),int(addr_size))}: dataB <= 32'b")+line1[::-1]
            file.write(line_11)
            file.write(";\n")
            line_21 = str(f"{int(addr_size)}'b{dec2bin(int(index*2+1),int(addr_size))}: dataB <= 32'b")+line2[::-1]
            file.write(line_21)
            file.write(";\n")
            index=index+1
        file.write("endcase\n")
        file.write("end\n")
        file.write("assign doA = dataA;\n")
        file.write("assign doB = dataB;\n")
        file.write("endmodule\n")
        
    #bit_filename = 'BRIEF_pattern_bram1.data'
    #with open(bit_filename, 'w') as file:
    #    # bit_format_1.tofile(file)
    #    #file.write(bit_format_1.to01())
    #    for line in binary_str_1:
    #        line1 = line[:32]
    #        line2 = line[32:]
    #        file.write(line1[::-1])
    #        file.write("\n")
    #        file.write(line2[::-1])
    #        file.write("\n")
    bit_filename = f"roms/rams_sp_rom1_{int(n_sections)}_sec.v"
    with open(bit_filename, 'w') as file:
        #bit_format_1.tofile(file)
        #file.write(bit_format_1.to01())
        file.write(f"module rams_sp_rom1_{int(n_sections)}_sec (clk, enA, enB, addrA, addrB, doA, doB);\n")
        file.write("input clk;\n")
        file.write("input enA, enB;\n")
        file.write(f"input [{int(addr_size-1)}:0] addrA, addrB;\n")
        file.write("output [31:0] doA, doB;\n")
        file.write(f"(*rom_style = \"block\" *) reg [{int(n_sections*86*4)-1}:0] dataA, dataB;\n")
        file.write("always @(posedge clk)\n")
        file.write("begin\n")
        file.write("if (enA)\n")
        file.write("case(addrA)\n")
        index=0
        for line in binary_str_1:
            line1 = line[:32]
            line2 = line[32:]

            line_11 = str(f"{int(addr_size)}'b{dec2bin(int(index*2),int(addr_size))}: dataA <= 32'b")+line1[::-1]
            file.write(line_11)
            file.write(";\n")
            line_21 = str(f"{int(addr_size)}'b{dec2bin(int(index*2+1),int(addr_size))}: dataA <= 32'b")+line2[::-1]
            file.write(line_21)
            file.write(";\n")
            index=index+1
        file.write("endcase\n")
        file.write("if (enB)\n")
        file.write("case(addrB)\n")
        index=0
        for line in binary_str_1:
            line1 = line[:32]
            line2 = line[32:]

            line_11 = str(f"{int(addr_size)}'b{dec2bin(int(index*2),int(addr_size))}: dataB <= 32'b")+line1[::-1]
            file.write(line_11)
            file.write(";\n")
            line_21 = str(f"{int(addr_size)}'b{dec2bin(int(index*2+1),int(addr_size))}: dataB <= 32'b")+line2[::-1]
            file.write(line_21)
            file.write(";\n")
            index=index+1
        file.write("endcase\n")
        file.write("end\n")
        file.write("assign doA = dataA;\n")
        file.write("assign doB = dataB;\n")
        file.write("endmodule\n")
    """ bit_filename = 'BRIEF_pattern_bram.data'
    with open(bit_filename, 'w') as file:
        # bit_format_1.tofile(file)
        #file.write(bit_format_1.to01())
        for line in binary_str:
            line1 = line[:32]
            line2 = line[32:]
            file.write(line1[::-1])
            file.write("\n")
            file.write(line2[::-1])
            file.write("\n") """

    #print(f"Image saved as 'random_2d_coordinate_pairs.png'")
    #print(f"C++ vector initialization saved as '{cpp_filename}'")
