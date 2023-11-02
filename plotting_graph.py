import plotly.express as px
import os
import pandas as pd
import json

# Get the project directory and the version folders within it
project_directory = "projects"
version_folders = next(os.walk(project_directory))[1]  # Gets all folders in the project directory
version_folders = sorted(version_folders)  # Sorts the version folders to maintain order

# Initialize an empty list to store the data
data = []

# Loop through each version folder to get the JSON data
for version in version_folders:
    # Define the JSON file path
    json_file_path = os.path.join(project_directory, version, "DATA_JSON", "total_data.json")

    # Check if the total_data.json file exists
    if os.path.isfile(json_file_path):
        # Read JSON data from the file
        with open(json_file_path) as f:
            json_data = json.load(f)

        # Loop through the JSON data to extract the required information
        for category, category_data in json_data.items():
            # Add a condition to skip the category with format like "v3.8.0"
            if category.startswith("v"):
                continue
            for module, module_data in category_data.items():
                if "Levels" in module_data:
                    levels_data = module_data["Levels"]
                    for level, count in levels_data.items():
                        file_name_category = f"{module} ({category})"
                        data.append([file_name_category, version, level, count])


# Create a DataFrame from the collected data
df = pd.DataFrame(data, columns=["File name (category)", "Version", "Level", "Count"])

# Sort the DataFrame by "File name (category)," "Version," and "Level"
df = df.sort_values(by=["File name (category)", "Version", "Level"])

# Create a directory to store CSV files for each level
output_dir = "output_levels"
os.makedirs(output_dir, exist_ok=True)

# Create a color map for "File name (category)"
unique_files = df["File name (category)"].unique()
color_scale = px.colors.qualitative.Set1
color_map = {file: color_scale[i % len(color_scale)] for i, file in enumerate(unique_files)}

# Create separate CSV files and scatter plots for each level
for level in sorted(df["Level"].unique()):
    level_df = df[df["Level"] == level]
    version_df_grouped = level_df.sort_values(by=["File name (category)", "Version"])

    # Save the CSV file (Optional)
    csv_file_path = os.path.join(output_dir, f"{level}_output_version_df_grouped.csv")
    version_df_grouped.to_csv(csv_file_path, index=False)

    # Load the data
    df_loading = pd.read_csv(csv_file_path)

    # Filter the data to include only those files with count changes
    filtered_df = df_loading.groupby('File name (category)').filter(lambda x: x['Count'].nunique() > 1)

    # Generate the plot
    fig = px.line(filtered_df, x="Version", y="Count", color="File name (category)",
                  title=f"Change in Code Competency Level {level} of Python Files across Different Versions",
                  color_discrete_map=color_map)

    # Change the y-axis to a log scale to better visualize the changes
    fig.update_layout(yaxis_type="log")

    # Show the graphs in a browser
    fig.show()
