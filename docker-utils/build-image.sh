#!/bin/bash

this_dir="$(dirname "${BASH_SOURCE[0]}")"
dockerfile="3nweb_node22_trixie.Dockerfile"
npm_pack="spec-3nweb-server"

npm_registry="https://registry.npmjs.org/$npm_pack/latest"

latest_version=$(curl -s -L $npm_registry | jq .version -r)
if [ -z $latest_version ]
then
  echo "Failed to get latest version info for npm package $npm_pack, using curl and js"
  exit -1
fi

tag="$1"
if [ -z "$tag" ]
then
  tag="3nweb:$latest_version"
fi

if [ -n "$(docker images -q -f reference="$tag")" ]
then
  echo "Image $tag already exists:"
  docker images -f reference="$tag"
  exit -1
fi

echo "🏗️  Building $tag image with version $latest_version of $npm_pack"

(cd "$this_dir" || exit $?
  docker build --no-cache --tag $tag --file "$dockerfile" .  || exit $?
) || exit $?
