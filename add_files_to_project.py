
import sys
from pbxproj import XcodeProject

# Get the project path and file paths from the command line arguments
project_path = sys.argv[1]
file_paths = sys.argv[2:]

# Load the project
project = XcodeProject.load(project_path)

# Add the files to the project
for file_path in file_paths:
    project.add_file(file_path)

# Save the project
project.save()
