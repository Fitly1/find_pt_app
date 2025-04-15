#!/usr/bin/env bash
echo "Updating podspec files with absolute path references..."

# Loop through all podspec files in plugin override folders (folders ending with _plugin)
for podspec in ios/*_plugin/*.podspec; do
  if [ -f "$podspec" ]; then
    echo "Processing ${podspec}"
    # Replace relative LICENSE reference with an absolute path
    sed -i.bak "s/{ :file => '..\/LICENSE' }/{ :file => File.expand_path('..\/..\/LICENSE', __FILE__) }/g" "$podspec"
    rm "$podspec.bak"
  fi
done

echo "Podspec file update complete."
