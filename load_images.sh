#!/bin/bash

# Archivo con la lista de imágenes
IMAGE_FILE="images.txt"

# Nombre del cluster KIND
KIND_CLUSTER="kind"

# Verificar si el archivo de imágenes existe
if [[ ! -f "$IMAGE_FILE" ]]; then
  echo "Error: El archivo $IMAGE_FILE no existe."
  exit 1
fi

# Leer cada línea del archivo y procesarla
while IFS= read -r IMAGE; do
  if [[ -n "$IMAGE" ]]; then
    echo "Descargando imagen: $IMAGE"
    docker pull "$IMAGE"

    echo "Guardando imagen: $IMAGE en archivo temporal"
    IMAGE_NAME=$(echo "$IMAGE" | tr '/:' '_')  # Convertir nombre de imagen en un nombre de archivo válido
    docker save -o "${IMAGE_NAME}.tar" "$IMAGE"

    echo "Cargando imagen en KIND: $IMAGE"
    kind load image-archive "${IMAGE_NAME}.tar" --name "$KIND_CLUSTER"

    echo "Eliminando archivo temporal: ${IMAGE_NAME}.tar"
    rm -f "${IMAGE_NAME}.tar"

    echo "✔ Imagen $IMAGE cargada en KIND correctamente."
  fi
done < "$IMAGE_FILE"

# Mostrar todas las imágenes en KIND
echo "----------------------------------"
echo "📦 Listado de imágenes en KIND:"
docker exec -it $(docker ps -qf "name=kind-control-plane") crictl images

echo "----------------------------------"
echo "🎉 Todas las imágenes han sido cargadas en KIND."

