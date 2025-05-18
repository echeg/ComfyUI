from huggingface_hub import snapshot_download
import os
import argparse
import sys

def download_models(target_dir=None):
    """
    Download models from HuggingFace hub to specified directory
    
    Args:
        target_dir (str, optional): Target directory for downloads. 
                                  If None, uses current working directory
    """
    # Check if Hugging Face token exists
    hf_token = os.environ.get("HUGGINGFACE_TOKEN")
    if not hf_token:
        print("Error: HUGGINGFACE_TOKEN environment variable is not set.")
        print("Please set your Hugging Face token and try again.")
        return False
    
    # Set repo ID
    repo_id = "OwlMaster/FLUX_LoRA_Train"
    
    # Use provided target dir or default to current working directory
    download_dir = target_dir if target_dir else os.getcwd()
    
    # Create target directory if it doesn't exist
    os.makedirs(download_dir, exist_ok=True)
    
    # Check if models are already downloaded
    # A simple check - look for a specific file or directory that would indicate complete download
    # For example, check if checkpoint file exists
    checkpoint_file = os.path.join(download_dir, "model.safetensors")  # Adjust filename as needed
    if os.path.exists(checkpoint_file):
        print(f"Models already downloaded in {download_dir}")
        print("Skipping download. Use --force to download again.")
        return True
    
    try:
        print(f"Downloading models to {download_dir}...")
        snapshot_download(
            repo_id=repo_id,
            local_dir=download_dir,
            use_auth_token=hf_token
        )
        print(f"\nDOWNLOAD COMPLETED to: {download_dir}")
        print("Check folder content for downloaded files")
        return True
        
    except Exception as e:
        print(f"Error occurred during download: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Download models from HuggingFace hub')
    parser.add_argument('--dir', type=str, help='Target directory for downloads', default=None)
    parser.add_argument('--force', action='store_true', help='Force download even if models exist')
    
    args = parser.parse_args()
    
    success = download_models(args.dir)
    if not success:
        sys.exit(1)