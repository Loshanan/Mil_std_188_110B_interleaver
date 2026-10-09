# Description   : Algorithm to load in interleaver matrix

import matplotlib
matplotlib.use("TkAgg")     # to plot from terminal command
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

def gen_write_order(max_col):
    row = 0
    col = 0
    row_indices = [0 for i in range (40 * max_col)]
    col_indices = [0 for i in range (40 * max_col)]

    # writing index order
    for i in range(40 * max_col):
        # print("Row: ", row, "Col: ", col)
        row_indices[i] = row
        col_indices[i] = col
        if ((i+1) % 40 == 0):
            row = 0
            col = col + 1
        else:
            row = (row + 9) % 40

    return row_indices, col_indices

if __name__ == "__main__":
    max_col = 18        # short: 18, 36 ; long: 144, 288
    
    # gen write order
    row_indices, col_indices = gen_write_order(max_col)
    
    # prepare the matrix
    mat = np.zeros((40, max_col), dtype=int)
    count = 1
    for i in range(40 * max_col):
        mat[row_indices[i], col_indices[i]] = count
        count += 1
    
    print("Any cells not written?: ", {0 in mat})  
    # no zeros means no over written cells
    plt.figure(figsize=(30, 30))
    sns.heatmap(
        mat,
        annot=True,         # This is the key argument: displays the value inside the cell
        fmt="d",            # Formats the annotation as an integer
        cmap="Blues",       # Color map (e.g., 'viridis', 'coolwarm', 'Blues')
        cbar=True,          # Displays the color bar/legend
        linewidths=0.5,     # Adds lines between cells for clarity
        linecolor='black'
    )
    plt.title('Visualization of 2D to 1D Data Reordering')
    plt.xlabel('Original Column Index')
    plt.ylabel('Original Row Index')
    plt.show()
    