#!/bin/bash

# Instala bc (si no lo tienes instalado)
sudo apt install bc -y

# Definimos los proyectos
project_ids=("xertica-support-host" "xertica-support-service")

# Nombre del archivo CSV único
output_file="all_projects.csv"

# 1) Escribimos la cabecera UNA SOLA VEZ:
echo "project_id,machine_name,machine_type,vcpus,ram_gb,internalip,externalip,zone,disk_name,sizeGb,disk_type,so" > "$output_file"

# 2) Iteramos sobre los proyectos, siempre añadiendo al mismo archivo
for project_id in "${project_ids[@]}"
do
  echo "Procesando el proyecto: $project_id"

  # Obtenemos la lista de instancias en formato JSON
  instances=$(gcloud compute instances list --project "$project_id" --format=json)

  # Iteramos sobre las instancias
  for row in $(echo "${instances}" | jq -r '.[] | @base64'); do

    # Función auxiliar para decodificar cada instancia
    _jq() {
      echo "${row}" | base64 --decode | jq -r "${1}"
    }

    # Información de la instancia
    machine_name=$(_jq '.name')
    machine_type=$(_jq '.machineType' | awk -F/ '{print $NF}')
    zone=$(_jq '.zone' | awk -F/ '{print $NF}')
    region=$(echo "$zone" | awk -F- '{print $1"-"$2}')

    # Especificaciones (vCPUs y memoria)
    specs=$(gcloud compute machine-types describe "$machine_type" \
      --zone "$zone" --format="value(guestCpus,memoryMb)" --project "$project_id")
    vcpus=$(echo "$specs" | awk '{print $1}')
    memory_mb=$(echo "$specs" | awk '{print $2}')
    ram_gb=$(echo "scale=2; $memory_mb / 1024" | bc)

    # IPs
    internalip=$(
      echo "${row}" | base64 --decode \
      | jq -r '.networkInterfaces[0].networkIP'
    )
    externalip=$(
      echo "${row}" | base64 --decode \
      | jq -r '.networkInterfaces[0].accessConfigs[0].natIP // "None"'
    )

    # Obtenemos la información de los discos
    disks=$(gcloud compute instances describe "$machine_name" \
      --zone="$zone" --project="$project_id" --format=json \
      | jq -c '.disks[]'
    )

    disk_names=()
    disk_sizes=()
    disk_types=()
    disk_sos=()

    # Recorremos cada disco
    for disk_row in $(echo "${disks}" | jq -r '. | @base64'); do
      _jq_disk() {
        echo "${disk_row}" | base64 --decode | jq -r "${1}"
      }

      disk_source=$(_jq_disk '.source')
      disk_name=$(echo "$disk_source" | awk -F/ '{print $NF}')

      # Zonales vs regionales
      if echo "$disk_source" | grep -q "/zones/"; then
        zone_for_disk=$(echo "$disk_source" | sed -n 's#.*/zones/\([^/]*\)/disks/.*#\1#p')
        disk_info=$(gcloud compute disks describe "$disk_name" \
          --zone="$zone_for_disk" --project="$project_id" --format=json)
      else
        region_for_disk=$(echo "$disk_source" | sed -n 's#.*/regions/\([^/]*\)/disks/.*#\1#p')
        disk_info=$(gcloud compute disks describe "$disk_name" \
          --region="$region_for_disk" --project="$project_id" --format=json)
      fi

      # Tamaño y tipo
      sizeGb=$(echo "$disk_info" | jq -r '.sizeGb // empty')
      disk_type=$(echo "$disk_info" | jq -r '.type // empty' | awk -F/ '{print $NF}')

      # Disco de arranque vs. data
      if [ "$(_jq_disk '.boot')" == "true" ]; then
        vm_so=$(_jq_disk '.licenses[0]' \
          | awk -F/ '{if($0 == "disco de data") print $0; else print $NF}' \
          | tr -d '[]\\')
      else
        vm_so="disco de data"
      fi

      # Acumulamos la info en arrays
      disk_names+=("$disk_name")
      disk_sizes+=("$sizeGb")
      disk_types+=("$disk_type")
      disk_sos+=("$vm_so")
    done

    # Unificamos la información de todos los discos de esta VM
    joined_disk_names=$(IFS=';'; echo "${disk_names[*]}")
    joined_disk_sizes=$(IFS=';'; echo "${disk_sizes[*]}")
    joined_disk_types=$(IFS=';'; echo "${disk_types[*]}")
    joined_disk_sos=$(IFS=';'; echo "${disk_sos[*]}")

    # 3) Escribimos una sola línea CSV por VM al mismo archivo
    echo "\"$project_id\",\"$machine_name\",\"$machine_type\",\"$vcpus\",\"$ram_gb\",\"$internalip\",\"$externalip\",\"$zone\",\"$joined_disk_names\",\"$joined_disk_sizes\",\"$joined_disk_types\",\"$joined_disk_sos\"" \
      >> "$output_file"

  done  # Fin de instancias

done  # Fin de projects

echo "Archivo CSV generado: $output_file"
