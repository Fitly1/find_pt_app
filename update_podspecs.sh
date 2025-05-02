#!/usr/bin/env bash
# Updates each *.podspec inside ios/*_plugin/ so that the LICENSE entry
# uses an absolute path (Codemagic build container can’t handle relatives).

set -euo pipefail
echo "Updating podspec files with absolute path references…"

for podspec in ios/*_plugin/*.podspec; do
  if [[ -f "$podspec" ]]; then
    echo "Processing ${podspec}"
    # Replace  { :file => '../LICENSE' }
    #     with { :file => File.expand_path('../../LICENSE', __FILE__) }
    sed -i.bak \
      "s/{ :file => '..\/LICENSE' }/{ :file => File.expand_path('..\/..\/LICENSE', __FILE__) }/g" \
      "$podspec"

    rm "$podspec.bak"
  fi
done

echo "Podspec file update complete."
