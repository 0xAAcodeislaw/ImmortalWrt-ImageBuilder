#!/usr/bin/env bash
set -Eeuo pipefail

# Resolve the newest published stable ImageBuilder tag, while allowing a
# specific version for reproducible builds and troubleshooting.
requested_version="${REQUESTED_VERSION:-latest}"
target="${IMAGEBUILDER_TARGET:-x86-64}"
repository="immortalwrt/imagebuilder"
tag_prefix="${target}-openwrt-"
tags_api="https://registry.hub.docker.com/v2/repositories/${repository}/tags?page_size=100&name=${tag_prefix}"

if [[ -z "$requested_version" || "$requested_version" == "latest" ]]; then
  echo "Resolving the newest stable ${target} ImmortalWrt ImageBuilder tag..."
  resolved_version="$({
    curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$tags_api" \
      | jq -r --arg prefix "$tag_prefix" '
          .results[].name
          | select(startswith($prefix))
          | sub("^" + $prefix; "")
          | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
        '
  } | sort -V | tail -n 1)"
else
  if [[ ! "$requested_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must be latest or a stable version such as 25.12.1; got '$requested_version'." >&2
    exit 1
  fi
  resolved_version="$requested_version"
fi

if [[ -z "$resolved_version" ]]; then
  echo "Error: no stable ${target} ImageBuilder version was found at ${tags_api}." >&2
  exit 1
fi

tag="${tag_prefix}${resolved_version}"
tag_api="https://registry.hub.docker.com/v2/repositories/${repository}/tags/${tag}"
if ! curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$tag_api" \
  | jq -e --arg expected "$tag" '.name == $expected' >/dev/null; then
  echo "Error: ImageBuilder tag '$tag' does not exist in $repository." >&2
  exit 1
fi

image="${repository}:${tag}"
echo "Using ImmortalWrt ImageBuilder: $image"
{
  echo "LUCI_VERSION=$resolved_version"
  echo "IMAGEBUILDER_IMAGE=$image"
} >> "$GITHUB_ENV"
