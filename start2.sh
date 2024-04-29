#!/bin/bash

if [ ! -d "DeFooocus" ]; then
  git clone https://github.com/ehristoforu/DeFooocus.git
fi

cd DeFooocus
git pull

if [ ! -L ~/.conda/envs/DeFooocus ]; then
    ln -s /tmp/DeFooocus ~/.conda/envs/
fi

eval "$(conda shell.bash hook)"

if [ ! -d /tmp/DeFooocus ]; then
    mkdir /tmp/DeFooocus
    conda env create -f environment.yaml
    conda activate DeFooocus
    pip install -r requirements_versions.txt
    pip install torch torchvision --force-reinstall --index-url https://download.pytorch.org/whl/cu117
    conda install glib -y
    rm -rf ~/.cache/pip
fi

# Setup the path for model checkpoints
current_folder=$(pwd)
model_folder=${current_folder}/models/checkpoints-real-folder
# Download and save checkpoint
wget  -O ${current_folder}/models/checkpoints/juggernautXL_juggernautxX.safetensors https://civitai.com/api/download/models/456194
wget  -O ${current_folder}/models/checkpoints/realisticVisionV60B1_v60B1VAE.safetensors https://civitai.com/api/download/models/245598

# Download and save LoRAs
# !wget  -O ${current_folder}/models/loras/Leather_armor.safetensors https://civitai.com/api/download/models/454069
# !wget  -O ${current_folder}/models/checkpoints/20ModelPosesAndPrompts_v20.safetensors https://civitai.com/api/download/models/397649
if [ ! -e config.txt ]; then
  json_data="{ \"path_checkpoints\": \"$model_folder\" }"
  echo "$json_data" > config.txt
  echo "JSON file created: config.txt"
else
  echo "Updating config.txt to use checkpoints-real-folder"
  jq --arg new_value "$model_folder" '.path_checkpoints = $new_value' config.txt > config_tmp.txt && mv config_tmp.txt config.txt
fi

# If the checkpoints folder exists, move it to the new checkpoints-real-folder
if [ ! -L models/checkpoints ]; then
    mv models/checkpoints models/checkpoints-real-folder
    ln -s models/checkpoints-real-folder models/checkpoints
fi

# Activate the DeFooocus environment
conda activate DeFooocus
cd ..


# Set the image theme
image_theme="dark"  # Allowed values: "dark", "light"

# Set the image preset
image_preset="default"  # Allowed values: "default", "realistic", "anime", "lcm", "sai", "turbo", "lighting"

# Set the advanced arguments
advanced_args="--share --attention-split --always-high-vram --disable-offload-from-vram --all-in-fp16"

# Construct the full argument string
if [ "$image_preset" != "default" ]; then
  args="$advanced_args --theme $image_theme --preset $image_preset"
else
  args="$advanced_args --theme $image_theme"
fi

# Run the Python script in the background
echo "Running DeFooocus/entry_with_update.py with the following arguments: $args"
python DeFooocus/entry_with_update.py $args &

# Wait for 120 seconds
echo "Waiting for 120 seconds..."
sleep 120

# Run cloudflared tunnel
cloudflared tunnel --url localhost:7865

# Check if the script was called with the "reset" argument
if [ $# -eq 0 ]; then
  sh cloudflare.sh
elif [ $1 = "reset" ]; then
  sh cloudflare.sh
fi
