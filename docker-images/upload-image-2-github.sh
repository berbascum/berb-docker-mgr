# Create github personal token
# https://github.com/settings/tokens
# Permissions: write:packages read:packages delete:packages repo (for private repos)

# Login GHCR
GITHUB_TOKEN=""
USERNAME="berbascum"
#IMAGE_NAME="berb-build-env"
IMAGE_NAME="droidian-build-essential"
ARCH="arm64"
SUITE="next"

## Get images
#curl -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/users/${USERNAME}/packages?package_type=container

## Get images tags
#curl -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/users/${USERNAME}/packages/container/${IMAGE_NAME}/versions

#echo ${GITHUB_TOKEN} | docker login ghcr.io -u ${USERNAME} --password-stdin

docker tag ${IMAGE_NAME}:${SUITE}-${ARCH} ghcr.io/${USERNAME}/${IMAGE_NAME}:${SUITE}-${ARCH}

docker push ghcr.io/${USERNAME}/${IMAGE_NAME}:${SUITE}-${ARCH}

