#!/usr/bin/env bash
echo "Updating podspec files with absolute path references..."

<<<<<<< HEAD
# Loop over all podspec files in directories ending with _plugin inside the ios folder.
for podspec in ios/*_plugin/*.podspec; do
  if [ -f "$podspec" ]; then
    echo "Processing ${podspec}"
    # Update the license file reference.
    # This line replaces { :file => '../LICENSE' } with 
    # { :file => File.expand_path('../../LICENSE', __FILE__) }.
    sed -i.bak "s/{ :file => '..\/LICENSE' }/{ :file => File.expand_path('..\/..\/LICENSE', __FILE__) }/g" "$podspec"
    
    # (Add additional sed commands here if needed.)
    
    # Remove the backup file created by sed.
=======
# Loop through all podspec files in plugin override folders (folders ending with _plugin)
for podspec in ios/*_plugin/*.podspec; do
  if [ -f "$podspec" ]; then
    echo "Processing ${podspec}"
    # Replace relative LICENSE reference with an absolute path
    sed -i.bak "s/{ :file => '..\/LICENSE' }/{ :file => File.expand_path('..\/..\/LICENSE', __FILE__) }/g" "$podspec"
>>>>>>> android-release
    rm "$podspec.bak"
  fi
done

echo "Podspec file update complete."
