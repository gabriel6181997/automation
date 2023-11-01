repo="psf/requests"
work_dir="projects"
tags_per_page=100
token="${GITHUB_TOKEN:-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}"  # Use environment variable as default

# Create projects directory if it doesn't exist
mkdir -p "$work_dir"

# Function to get tags from GitHub
get_project_tags() {
    local repo=$1
    local token=$2
    local tags=()
    local page=1  # Initialize page within the function

    while :; do
        # Use token if provided
        local response
        if [ -n "$token" ]; then
            response=$(curl -s -H "Authorization: token $token" "https://api.github.com/repos/$repo/tags?per_page=$tags_per_page&page=$page")
            # echo "API Response with token: $response"  # Debug message
        else
            response=$(curl -s "https://api.github.com/repos/$repo/tags?per_page=$tags_per_page&page=$page")
            echo "API Response without token: $response"  # Debug message
        fi

        # Check for rate limit exceeded
        if echo "$response" | grep -q "API rate limit exceeded"; then
            echo "Error: GitHub API rate limit exceeded."
            exit 1
        fi
        # echo "response: $response"
        # Get tags starting with 'v'
        local current_tags=$(echo "$response" | grep -Eo '"name": "v[^"]+"' | awk -F':' '{print $2}' | tr -d ' ",')

        if [ -z "$current_tags" ]; then
            break
        fi

        # Append current tags to the tags array
        tags=("${tags[@]}" $current_tags)

        ((page++))
    done

    echo "${tags[@]}"
}

# Function to clone and setup
clone_and_setup() {
    echo "tag in clone_and_setup: $tag"
    local repo=$1
    local tag=$2
    local work_dir=$3

    local clone_path="$work_dir/$tag"

    # Clone and checkout
    if ! git clone "https://github.com/$repo.git" "$clone_path"; then
        echo "Error: Failed to clone $repo at tag $tag"
        return 1
    fi

    # Verify if the clone was successful by checking the existence of the .git directory
    if [[ ! -d "$clone_path/.git" ]]; then
        echo "Error: Git clone seems to have failed. No .git directory found in $clone_path."
        return 1
    fi

    if ! (cd "$clone_path" && git checkout "$tag"); then
        echo "Error: Failed to checkout tag $tag in $repo"
        return 1
    fi
}

# Check for pycerfl.py
if [[ ! -f "pycerfl.py" ]]; then
    echo "Error: pycerfl.py not found."
    exit 1
fi

# Get tags and print them for debugging
tags=($(get_project_tags "$repo" "$token"))

for tag in "${tags[@]:0:2}"; do
    clone_and_setup "$repo" "$tag" "$work_dir"
done

# Function to get version directories
get_version_directories() {
    local base_dir=$1
    find "$base_dir" -maxdepth 1 -type d | cut -d'/' -f2-
}

# Print version directories
version_dirs=$(get_version_directories "$work_dir")
echo "$version_dirs"

# Function to move generated files and folders to a specified directory
move_generated_files() {
    local target_dir=$1

    # List of generated files and folders
    items=("__pycache__" "DATA_CSV" "DATA_JSON" "data.csv" "data.json")

    # Move each item to the target directory
    for item in "${items[@]}"; do
        if [ -e "$item" ]; then
            mv "$item" "$target_dir/"
        else
            echo "Warning: $item not found."
        fi
    done
}

base_dir="./projects"

# Loop through all subdirectories inside the projects directory
for name_path in "$base_dir"/*; do
    # If it's a directory
    if [ -d "$name_path" ]; then
        python3 pycerfl.py directory "$name_path"

        # Move the generated files and folders to the name_path directory
        move_generated_files "$name_path"
    fi
done
