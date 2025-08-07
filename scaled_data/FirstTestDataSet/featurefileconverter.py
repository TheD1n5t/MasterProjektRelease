import csv

# Input and output file names
input_file = "testing_emg.csv"
output_file = "output.txt"

# Read the CSV file and limit to lines 7939 through 10585
data = []
with open(input_file, "r") as csv_file:
    reader = csv.reader(csv_file)
    for i, row in enumerate(reader):
        if 2112 < i:  # Process lines within the range
            data.extend(row)  # Add the row values to the data list

# Write the data to the output file with one value per line
with open(output_file, "w") as file:
    for value in data:
        file.write(f"{value}\n")

print(f"Lines 7939 through 10585 have been formatted and written to {output_file}.")
