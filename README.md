# list-vms-gcp.sh

This script helps you retrieve detailed information about the VMs in one or more Google Cloud Platform (GCP) projects. The results are written to a CSV file, with one row per VM.

## What does the script do?

1. **Iterates over multiple GCP projects** (defined in the `project_ids` array).  
2. **Lists the instances** in each project using `gcloud compute instances list`.  
3. **Collects** the following details for each VM:
   - VM name (`machine_name`)
   - Machine type (`machine_type`)
   - Number of vCPUs (`vcpus`)
   - RAM in GB (`ram_gb`)
   - Internal and external IP
   - Zone
   - **All disks** attached to each VM (name, size, type, and OS if it’s a boot disk)
4. **Writes** everything into a single CSV file:  
   - Each VM results in one row in the CSV.  
   - If a VM has multiple disks, those values are concatenated in the same cell, separated by `;`.

## Requirements

- **bash** (assumed to be a Linux-like system with bash).  
- [**Google Cloud SDK**](https://cloud.google.com/sdk/docs/install) installed and authenticated.  
- [**bc**](https://www.gnu.org/software/bc/) (a command-line calculator) to convert from MB to GB.  
- [**jq**](https://stedolan.github.io/jq/) to parse JSON in the terminal.

Make sure to install these tools:
```bash
sudo apt-get update
sudo apt-get install -y bc jq
```
Or use the appropriate commands for your operating system.

## Usage

1. **Clone this repository** or copy the `list-vms-gcp.sh` file to your local environment.
2. **Edit the script**:
   - Update the `project_ids=(...)` variable with the GCP projects you want to process.
   - If desired, change the output file name (by default `all_projects.csv`).
3. **Give execution permissions** (if needed):
   ```bash
   chmod +x list-vms-gcp.sh
   ```
4. **Run** the script:
   ```bash
   ./list-vms-gcp.sh
   ```
5. When finished, a single CSV file (`all_projects.csv` by default) is generated, containing all VMs’ information.

## Example output

Below is a sample of the CSV content:

```csv
project_id,machine_name,machine_type,vcpus,ram_gb,internalip,externalip,zone,disk_name,sizeGb,disk_type,so
"xertica-support-host","instance-aye","e2-highcpu-4","4","8.00","10.0.0.3","None","us-central1-b","instance-aye;disk-instance-aye-1;disk-instance-aye-2","10;10;12","pd-balanced;pd-balanced;pd-balanced","debian-12-bookworm;disco de data;disco de data"
"xertica-support-host","instance-luis","e2-standard-8","8","32.00","192.168.0.4","None","us-central1-b","instance-luis-44","10","pd-balanced","debian-11-bullseye"
...
```

## Notes

- The **GCP account** used to run this script must have enough permissions on the projects to list instances and describe disks.
- For **regional disks**, the script detects the need to use `--region` instead of `--zone`.
- If you want each disk’s information to appear **on separate lines** within the same cell, you can perform a quick post-processing step with `sed` to replace the semicolons (`;`) with actual line breaks, for example:
  ```bash
  sed -i 's/;/\
  /g' all_projects.csv
  ```
  This will make each disk appear on its own line within the same cell (assuming “Wrap Text” is turned on in Google Sheets or Excel).

## Troubleshooting

- **No VMs are listed**: Ensure you are **authenticated** (`gcloud auth login`) and have permission to perform `compute.instances.list` in the projects.
- **Error when describing a disk**: Confirm that the disk still exists, and that your user or service account has `compute.disks.get` permissions.
- **File permissions**: If you encounter a permission error when running the script, use `chmod +x list-vms-gcp.sh`.

## License

This project is provided for demonstration purposes and does not have a specific license. You are free to adapt and modify it to suit your needs.